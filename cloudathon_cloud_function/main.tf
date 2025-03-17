# Create a local ZIP file for inline code
data "archive_file" "function_source" {
  type        = "zip"
  output_path = "${path.module}/db-failover-source.zip"

  source {
    content  = <<EOF
from flask import Flask, jsonify, request  # Added 'request' import
import os
import logging
import time
from googleapiclient import discovery
from googleapiclient.errors import HttpError

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
GCP_PROJECT = os.getenv("GCP_PROJECT")
PRIMARY_INSTANCE = os.getenv("PRIMARY_INSTANCE")
REPLICA_INSTANCE = os.getenv("REPLICA_INSTANCE")

# Validate environment variables
if not all([GCP_PROJECT, PRIMARY_INSTANCE, REPLICA_INSTANCE]):
    raise ValueError("Missing required environment variables: GCP_PROJECT, PRIMARY_INSTANCE, REPLICA_INSTANCE")

# Initialize Flask app
app = Flask(__name__)

# Initialize Cloud SQL Admin API client
sqladmin = discovery.build("sqladmin", "v1", cache_discovery=False)

def wait_for_operation(operation_id):
    """Wait for an operation to complete with retries."""
    while True:
        try:
            operation = sqladmin.operations().get(
                project=GCP_PROJECT,
                operation=operation_id
            ).execute()
            if operation["status"] in ["DONE", "FAILED"]:
                if "error" in operation:
                    raise Exception(f"Operation {operation_id} failed: {operation['error']}")
                logger.info(f"Operation {operation_id} completed successfully")
                break
            logger.info(f"Waiting for operation {operation_id} to complete...")
            time.sleep(30)  # Increased delay to prevent API rate limit issues
        except Exception as e:
            logger.error(f"Error while waiting for operation {operation_id}: {str(e)}")
            time.sleep(10)  # Small delay before retrying

def check_instance_role(instance_name):
    """Check if the given Cloud SQL instance is already a standalone primary."""
    try:
        instance = sqladmin.instances().get(
            project=GCP_PROJECT, instance=instance_name
        ).execute()
        if "masterInstanceName" not in instance:
            logger.info(f"{instance_name} is already a standalone primary.")
            return "PRIMARY"
        else:
            logger.info(f"{instance_name} is a replica of {instance['masterInstanceName']}.")
            return "REPLICA"
    except HttpError as e:
        logger.error(f"Error checking role for {instance_name}: {str(e)}")
        return None

def promote_replica_to_primary():
    """Promote the replica instance to primary, if it's still a replica."""
    try:
        role = check_instance_role(REPLICA_INSTANCE)
        if role == "PRIMARY":
            logger.info(f"{REPLICA_INSTANCE} is already primary. Skipping promotion.")
            return {"message": f"{REPLICA_INSTANCE} is already primary. Skipping promotion."}

        logger.info(f"Initiating promotion of {REPLICA_INSTANCE} to primary.")
        operation = sqladmin.instances().promoteReplica(
            project=GCP_PROJECT,
            instance=REPLICA_INSTANCE
        ).execute()
        logger.info(f"Promotion operation started: {operation['name']}")
        wait_for_operation(operation["name"])
        
        logger.info("Waiting an extra 60 seconds for promotion to stabilize...")
        time.sleep(60)

        logger.info(f"Promotion completed: {REPLICA_INSTANCE} is now the primary instance.")
        return {"operation": operation}
    except Exception as e:
        logger.error(f"Error during promotion: {str(e)}")
        return {"error": str(e)}

def reconfigure_old_primary_as_replica(new_primary_instance):
    """Reconfigure the old primary instance as a replica of the new primary."""
    try:
        # Step 1: Check if instance exists
        try:
            sqladmin.instances().get(project=GCP_PROJECT, instance=PRIMARY_INSTANCE).execute()
            logger.info(f"{PRIMARY_INSTANCE} exists, proceeding to delete.")
        except HttpError as e:
            if e.resp.status == 404:
                logger.info(f"{PRIMARY_INSTANCE} already deleted, skipping delete step.")
            else:
                raise

        # Step 2: Delete the old primary instance with retries
        max_retries = 5
        for attempt in range(max_retries):
            try:
                logger.info(f"Deleting {PRIMARY_INSTANCE} (attempt {attempt + 1}/{max_retries})")
                delete_operation = sqladmin.instances().delete(
                    project=GCP_PROJECT,
                    instance=PRIMARY_INSTANCE
                ).execute()
                wait_for_operation(delete_operation["name"])
                break
            except HttpError as e:
                if e.resp.status == 409:
                    logger.warning(f"Operation in progress on {PRIMARY_INSTANCE}, retrying in 30 seconds...")
                    time.sleep(30)
                elif e.resp.status == 404:
                    logger.info(f"{PRIMARY_INSTANCE} already deleted, proceeding.")
                    break
                else:
                    raise
            if attempt == max_retries - 1:
                raise Exception(f"Failed to delete {PRIMARY_INSTANCE} after {max_retries} attempts.")

        # Step 3: Recreate the primary instance as a replica
        logger.info(f"Creating {PRIMARY_INSTANCE} as a replica of {new_primary_instance}.")
        instance_body = {
            "name": PRIMARY_INSTANCE,
            "region": "asia-south2",
            "databaseVersion": "POSTGRES_15",
            "masterInstanceName": new_primary_instance,
            "settings": {
                "tier": "db-g1-small",
                "availabilityType": "ZONAL",
                "ipConfiguration": {
                    "ipv4Enabled": True,
                    "authorizedNetworks": [{"name": "all", "value": "0.0.0.0/0"}]
                }
            }
        }
        create_operation = sqladmin.instances().insert(
            project=GCP_PROJECT,
            body=instance_body
        ).execute()
        wait_for_operation(create_operation["name"])

        logger.info(f"Replica creation completed: {PRIMARY_INSTANCE} is now a replica of {new_primary_instance}.")
        return {"operation": create_operation}
    except Exception as e:
        logger.error(f"Error during reconfiguration: {str(e)}")
        return {"error": str(e)}

@app.route("/trigger-failover", methods=["POST"])
def trigger_failover(request):  # Added 'request' parameter to fix TypeError
    """Trigger the full failover: promote replica and reconfigure old primary."""
    try:
        # Step 1: Promote the replica to primary (if needed)
        promotion_result = promote_replica_to_primary()
        if "error" in promotion_result:
            return jsonify({"status": "error", "message": promotion_result["error"]}), 500

        # Step 2: Reconfigure the old primary as a replica of the new primary
        reconfiguration_result = reconfigure_old_primary_as_replica(REPLICA_INSTANCE)
        if "error" in reconfiguration_result:
            return jsonify({"status": "error", "message": reconfiguration_result["error"]}), 500

        return jsonify({
            "status": "success",
            "message": f"Failover completed: {REPLICA_INSTANCE} is now primary, {PRIMARY_INSTANCE} is a replica.",
            "promotion_operation": promotion_result,
            "reconfiguration_operation": reconfiguration_result
        }), 200
    except Exception as e:
        logger.error(f"Failover failed: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))  # Use dynamic PORT for Cloud Run
    app.run(host="0.0.0.0", port=port)
EOF
    filename = "main.py"
  }

  source {
    content  = <<EOF
# requirements.txt
google-api-python-client==2.111.0
google-auth==2.26.1
functions-framework==3.5.0
EOF
    filename = "requirements.txt"
  }
}

# Upload the ZIP to a GCS bucket
resource "google_storage_bucket" "source_bucket" {
  project                     = "cloudathon-453114"
  name                        = "cloudathon-453114-source"
  location                    = "ASIA-SOUTH2" # Bucket can be in one region; both functions can access it
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "source_object" {
  name   = "db-failover-source.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.function_source.output_path
}

# Cloud Function in asia-south2
resource "google_cloudfunctions2_function" "db_failover_asia_south2" {
  project  = "cloudathon-453114"
  name     = "db-failover-asia-south2"
  location = "asia-south2"

  build_config {
    runtime     = "python312"
    entry_point = "trigger_failover"
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_object.name
      }
    }
  }

  service_config {
    available_memory      = "512M"
    timeout_seconds       = 600
    ingress_settings      = "ALLOW_ALL"
    service_account_email = "vdc-serviceaccount-cloudathon@cloudathon-453114.iam.gserviceaccount.com"

    environment_variables = {
      GCP_PROJECT      = "cloudathon-453114"
      PRIMARY_INSTANCE = "postgres-primary"
      REPLICA_INSTANCE = "postgres-replica"
    }

    all_traffic_on_latest_revision = true
  }
}

# Cloud Function in asia-south1
resource "google_cloudfunctions2_function" "db_failover_asia_south1" {
  project  = "cloudathon-453114"
  name     = "db-failover-asia-south1"
  location = "asia-south1"

  build_config {
    runtime     = "python312"
    entry_point = "trigger_failover"
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_object.name
      }
    }
  }

  service_config {
    available_memory      = "512M"
    timeout_seconds       = 600
    ingress_settings      = "ALLOW_ALL"
    service_account_email = "vdc-serviceaccount-cloudathon@cloudathon-453114.iam.gserviceaccount.com"

    environment_variables = {
      GCP_PROJECT      = "cloudathon-453114"
      PRIMARY_INSTANCE = "postgres-replica"
      REPLICA_INSTANCE = "postgres-primary"
    }

    all_traffic_on_latest_revision = true
  }
}

# Allow unauthenticated invocations for asia-south2 function
resource "google_cloudfunctions2_function_iam_member" "public_access_asia_south2" {
  project        = "cloudathon-453114"
  location       = google_cloudfunctions2_function.db_failover_asia_south2.location
  cloud_function = google_cloudfunctions2_function.db_failover_asia_south2.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
  depends_on     = [google_cloudfunctions2_function.db_failover_asia_south2]
}

# Allow unauthenticated invocations for asia-south1 function
resource "google_cloudfunctions2_function_iam_member" "public_access_asia_south1" {
  project        = "cloudathon-453114"
  location       = google_cloudfunctions2_function.db_failover_asia_south1.location
  cloud_function = google_cloudfunctions2_function.db_failover_asia_south1.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
  depends_on     = [google_cloudfunctions2_function.db_failover_asia_south1]
}

