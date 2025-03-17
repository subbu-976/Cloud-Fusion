# cloudathon/main.tf

data "google_client_config" "default" {}

# -----------------------------------------------
# GKE Clusters and Load Balancer Resources
# -----------------------------------------------

# Active GKE Cluster in asia-south2
resource "google_container_cluster" "active_cluster" {
  provider                 = google.asia-south2
  name                     = var.active_cluster_name
  location                 = var.active_cluster_location
  remove_default_node_pool = true
  initial_node_count       = var.node_count
  network                  = "default"
  subnetwork               = "default"
  deletion_protection      = false
}

resource "google_container_node_pool" "active_nodes" {
  provider   = google.asia-south2
  name       = "active-node-pool"
  cluster    = google_container_cluster.active_cluster.name
  location   = var.active_cluster_location
  node_count = var.node_count
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible  = true
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
  depends_on = [google_container_cluster.active_cluster]
}

# Passive GKE Cluster in asia-south1
resource "google_container_cluster" "passive_cluster" {
  provider                 = google.asia-south1
  name                     = var.passive_cluster_name
  location                 = var.passive_cluster_location
  remove_default_node_pool = true
  initial_node_count       = var.node_count
  network                  = "default"
  subnetwork               = "default"
  deletion_protection      = false
}

resource "google_container_node_pool" "passive_nodes" {
  provider   = google.asia-south1
  name       = "passive-node-pool"
  cluster    = google_container_cluster.passive_cluster.name
  location   = var.passive_cluster_location
  node_count = var.node_count
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible  = true
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
  depends_on = [google_container_cluster.passive_cluster]
}

# ConfigMap for Hello World HTML (Active Cluster)
resource "kubernetes_config_map" "hello_world_config_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world-config"
  }
  data = {
    "index.html" = <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello World</title>
</head>
<body>
  <h1>Hello World! (Active - asia-south2)</h1>
</body>
</html>
EOF
  }
  depends_on = [google_container_cluster.active_cluster, google_container_node_pool.active_nodes]
}

# ConfigMap for Hello World HTML (Passive Cluster)
resource "kubernetes_config_map" "hello_world_config_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world-config"
  }
  data = {
    "index.html" = <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello World</title>
</head>
<body>
  <h1>Hello World! (Passive - asia-south1)</h1>
</body>
</html>
EOF
  }
  depends_on = [google_container_cluster.passive_cluster, google_container_node_pool.passive_nodes]
}

# Hello World Deployment on Active Cluster
resource "kubernetes_deployment" "hello_world_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "hello-world"
      }
    }
    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
          resources {
            requests = {
              cpu                 = var.cpu_request
              memory              = var.memory_request
              "ephemeral-storage" = var.ephemeral_storage_request
            }
            limits = {
              cpu                 = var.cpu_limit
              memory              = var.memory_limit
              "ephemeral-storage" = var.ephemeral_storage_limit
            }
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.hello_world_config_active.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_cluster.active_cluster,
    google_container_node_pool.active_nodes,
    kubernetes_config_map.hello_world_config_active
  ]
  timeouts {
    create = "10m"
  }
}

# Hello World Service on Active Cluster
resource "kubernetes_service" "hello_world_service_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world-service"
  }
  spec {
    selector = {
      app = "hello-world"
    }
    port {
      port        = 80
      target_port = 80
      node_port   = 30080
    }
    type = "NodePort"
  }
  depends_on = [
    google_container_cluster.active_cluster,
    google_container_node_pool.active_nodes,
    kubernetes_deployment.hello_world_active
  ]
}

# Hello World Deployment on Passive Cluster
resource "kubernetes_deployment" "hello_world_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "hello-world"
      }
    }
    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
          resources {
            requests = {
              cpu                 = var.cpu_request
              memory              = var.memory_request
              "ephemeral-storage" = var.ephemeral_storage_request
            }
            limits = {
              cpu                 = var.cpu_limit
              memory              = var.memory_limit
              "ephemeral-storage" = var.ephemeral_storage_limit
            }
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.hello_world_config_passive.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_cluster.passive_cluster,
    google_container_node_pool.passive_nodes,
    kubernetes_config_map.hello_world_config_passive
  ]
  timeouts {
    create = "10m"
  }
}

# Hello World Service on Passive Cluster
resource "kubernetes_service" "hello_world_service_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world-service"
  }
  spec {
    selector = {
      app = "hello-world"
    }
    port {
      port        = 80
      target_port = 80
      node_port   = 30080
    }
    type = "NodePort"
  }
  depends_on = [
    google_container_cluster.passive_cluster,
    google_container_node_pool.passive_nodes,
    kubernetes_deployment.hello_world_passive
  ]
}

# Global Load Balancer for GKE Failover
resource "google_compute_global_address" "global_ip" {
  provider = google.asia-south2
  name     = "gke-global-ip"
}

resource "google_compute_health_check" "gke_health_check" {
  provider = google.asia-south2
  name     = "gke-health-check"
  log_config {
    enable = true
  }
  http_health_check {
    port         = 30080
    request_path = "/"
  }
  timeout_sec         = var.health_check_timeout_sec
  check_interval_sec  = var.health_check_interval_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold
}

resource "google_compute_backend_service" "gke_backend" {
  provider    = google.asia-south2
  name        = "gke-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = var.backend_timeout_sec

  backend {
    group           = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
    balancing_mode  = "UTILIZATION"
    capacity_scaler = var.capacity_scaler
    max_utilization = var.max_utilization
  }

  backend {
    group           = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
    balancing_mode  = "UTILIZATION"
    capacity_scaler = var.capacity_scaler
    max_utilization = var.max_utilization
  }

  health_checks = [google_compute_health_check.gke_health_check.id]
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes,
    google_compute_health_check.gke_health_check
  ]
}

resource "google_compute_instance_group_named_port" "active_named_port" {
  provider   = google.asia-south2
  group      = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 30080
  zone       = var.active_cluster_location
  depends_on = [google_container_node_pool.active_nodes]
}

resource "google_compute_instance_group_named_port" "passive_named_port" {
  provider   = google.asia-south1
  group      = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 30080
  zone       = var.passive_cluster_location
  depends_on = [google_container_node_pool.passive_nodes]
}

resource "google_compute_url_map" "gke_url_map" {
  provider        = google.asia-south2
  name            = "gke-url-map"
  default_service = google_compute_backend_service.gke_backend.id
  depends_on      = [google_compute_backend_service.gke_backend]
}

resource "google_compute_target_http_proxy" "gke_proxy" {
  provider   = google.asia-south2
  name       = "gke-http-proxy"
  url_map    = google_compute_url_map.gke_url_map.id
  depends_on = [google_compute_url_map.gke_url_map]
}

resource "google_compute_global_forwarding_rule" "gke_forwarding_rule" {
  provider   = google.asia-south2
  name       = "gke-forwarding-rule"
  target     = google_compute_target_http_proxy.gke_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.global_ip.address
  depends_on = [
    google_compute_target_http_proxy.gke_proxy,
    google_compute_global_address.global_ip
  ]
}

# Firewall Rules for Load Balancer and NodePort Traffic
resource "google_compute_firewall" "allow_nodeport_traffic" {
  provider = google.asia-south2
  name     = "allow-nodeport-traffic"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"] # GKE NodePort range
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

resource "google_compute_firewall" "allow_health_checks" {
  provider = google.asia-south2
  name     = "allow-health-checks"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["30080"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  priority = 900

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

resource "google_compute_firewall" "allow_direct_access_port_80" {
  provider = google.asia-south2
  name     = "allow-direct-access-port-80"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

# Null Resource to Ensure Instance Groups are Ready
resource "null_resource" "wait_for_instance_groups" {
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes
  ]

  provisioner "local-exec" {
    command = "powershell -Command \"Start-Sleep -Seconds 30\""
  }
}

# Data Sources to Fetch Instance Group Details
data "google_compute_instance_group" "active_instance_group" {
  provider   = google.asia-south2
  name       = element([for url in google_container_node_pool.active_nodes.managed_instance_group_urls : element(split("/", url), length(split("/", url)) - 1)], 0)
  zone       = var.active_cluster_location
  depends_on = [null_resource.wait_for_instance_groups]
}

data "google_compute_instance_group" "passive_instance_group" {
  provider   = google.asia-south1
  name       = element([for url in google_container_node_pool.passive_nodes.managed_instance_group_urls : element(split("/", url), length(split("/", url)) - 1)], 0)
  zone       = var.passive_cluster_location
  depends_on = [null_resource.wait_for_instance_groups]
}

# Fetch Instance Details for Active and Passive Nodes
data "google_compute_instance" "active_instance" {
  provider   = google.asia-south2
  name       = element(split("/", tolist(data.google_compute_instance_group.active_instance_group.instances)[0]), 10)
  zone       = var.active_cluster_location
  depends_on = [data.google_compute_instance_group.active_instance_group]
}

data "google_compute_instance" "passive_instance" {
  provider   = google.asia-south1
  name       = element(split("/", tolist(data.google_compute_instance_group.passive_instance_group.instances)[0]), 10)
  zone       = var.passive_cluster_location
  depends_on = [data.google_compute_instance_group.passive_instance_group]
}

# -----------------------------------------------
# Database Creation Resources
# -----------------------------------------------

# Secrets for Database Username and Password
resource "google_secret_manager_secret" "db_username_secret" {
  secret_id = "dbusername"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_username_version" {
  secret      = google_secret_manager_secret.db_username_secret.id
  secret_data = "postgres" # Hardcoded as per requirement
}

data "google_secret_manager_secret_version" "db_username" {
  secret  = google_secret_manager_secret.db_username_secret.id
  version = google_secret_manager_secret_version.db_username_version.version
}

resource "google_secret_manager_secret" "db_password_secret" {
  secret_id = "dbpassword"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = "primarydbpassword" # Hardcoded as per requirement
}

data "google_secret_manager_secret_version" "db_password" {
  secret  = google_secret_manager_secret.db_password_secret.id
  version = google_secret_manager_secret_version.db_password_version.version
}

# Primary PostgreSQL Database Instance in asia-south2
resource "google_sql_database_instance" "postgres_primary" {
  provider            = google.asia-south2
  name                = var.primary_db_name
  region              = var.primary_db_region
  database_version    = var.database_version
  deletion_protection = false

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_size         = var.db_disk_size

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = var.authorized_network_range
      }
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      location                       = var.primary_db_region
      point_in_time_recovery_enabled = true
    }
  }
}

# Cloud SQL PostgreSQL Read Replica in asia-south1
resource "google_sql_database_instance" "postgres_replica" {
  provider             = google.asia-south1
  name                 = var.replica_db_name
  region               = var.replica_db_region
  database_version     = var.database_version
  deletion_protection  = false
  master_instance_name = google_sql_database_instance.postgres_primary.name

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_size         = var.db_disk_size

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = var.authorized_network_range
      }
    }
  }

  depends_on = [google_sql_database_instance.postgres_primary]
}

# Database on the Primary Instance
resource "google_sql_database" "test_db" {
  provider = google.asia-south2
  name     = var.test_db_name
  instance = google_sql_database_instance.postgres_primary.name
}

# User for the Primary Instance
resource "google_sql_user" "postgres_user" {
  provider = google.asia-south2
  name     = data.google_secret_manager_secret_version.db_username.secret_data
  instance = google_sql_database_instance.postgres_primary.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
  depends_on = [
    google_sql_database_instance.postgres_primary,
    data.google_secret_manager_secret_version.db_username,
    data.google_secret_manager_secret_version.db_password
  ]
}

# -----------------------------------------------
# Cloud Function Creation Resources
# -----------------------------------------------

# Create a Local ZIP File for Inline Code
data "archive_file" "function_source" {
  type        = "zip"
  output_path = "${path.module}/db-failover-source.zip"

  source {
    content  = <<EOF
from flask import Flask, jsonify, request
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
            time.sleep(30)
        except Exception as e:
            logger.error(f"Error while waiting for operation {operation_id}: {str(e)}")
            time.sleep(10)

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
        try:
            sqladmin.instances().get(project=GCP_PROJECT, instance=PRIMARY_INSTANCE).execute()
            logger.info(f"{PRIMARY_INSTANCE} exists, proceeding to delete.")
        except HttpError as e:
            if e.resp.status == 404:
                logger.info(f"{PRIMARY_INSTANCE} already deleted, skipping delete step.")
            else:
                raise

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
def trigger_failover(request):
    try:
        promotion_result = promote_replica_to_primary()
        if "error" in promotion_result:
            return jsonify({"status": "error", "message": promotion_result["error"]}), 500

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
    port = int(os.getenv("PORT", 8080))
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

# Upload the ZIP to a GCS Bucket
resource "google_storage_bucket" "source_bucket" {
  project                     = var.project_id
  name                        = var.source_bucket_name
  location                    = var.source_bucket_location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "source_object" {
  name   = "db-failover-source.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.function_source.output_path
}

# Cloud Function in asia-south2
resource "google_cloudfunctions2_function" "db_failover_asia_south2" {
  project  = var.project_id
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
    available_memory      = var.function_memory
    timeout_seconds       = var.function_timeout
    ingress_settings      = "ALLOW_ALL"
    service_account_email = var.service_account_email

    environment_variables = {
      GCP_PROJECT      = var.project_id
      PRIMARY_INSTANCE = var.primary_db_name
      REPLICA_INSTANCE = var.replica_db_name
    }

    all_traffic_on_latest_revision = true
  }
}

# Cloud Function in asia-south1
resource "google_cloudfunctions2_function" "db_failover_asia_south1" {
  project  = var.project_id
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
    available_memory      = var.function_memory
    timeout_seconds       = var.function_timeout
    ingress_settings      = "ALLOW_ALL"
    service_account_email = var.service_account_email

    environment_variables = {
      GCP_PROJECT      = var.project_id
      PRIMARY_INSTANCE = var.replica_db_name
      REPLICA_INSTANCE = var.primary_db_name
    }

    all_traffic_on_latest_revision = true
  }
}

# Allow Unauthenticated Invocations for asia-south2 Function
resource "google_cloudfunctions2_function_iam_member" "public_access_asia_south2" {
  project        = var.project_id
  location       = google_cloudfunctions2_function.db_failover_asia_south2.location
  cloud_function = google_cloudfunctions2_function.db_failover_asia_south2.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
  depends_on     = [google_cloudfunctions2_function.db_failover_asia_south2]
}

# Allow Unauthenticated Invocations for asia-south1 Function
resource "google_cloudfunctions2_function_iam_member" "public_access_asia_south1" {
  project        = var.project_id
  location       = google_cloudfunctions2_function.db_failover_asia_south1.location
  cloud_function = google_cloudfunctions2_function.db_failover_asia_south1.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
  depends_on     = [google_cloudfunctions2_function.db_failover_asia_south1]
}