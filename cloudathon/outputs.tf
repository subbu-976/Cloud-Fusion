


# Outputs

output "global_load_balancer_ip" {
  description = "Global IP address for the GKE load balancer"
  value       = google_compute_global_address.global_ip.address
}

output "active_node_ip" {
  description = "External IP address of an active cluster node"
  value       = data.google_compute_instance.active_instance.network_interface[0].access_config[0].nat_ip
}

output "passive_node_ip" {
  description = "External IP address of a passive cluster node"
  value       = data.google_compute_instance.passive_instance.network_interface[0].access_config[0].nat_ip
}

# Database outputs

output "primary_instance_connection_name" {
  value       = google_sql_database_instance.postgres_primary.connection_name
  description = "Connection name of the primary PostgreSQL instance"
}

output "primary_instance_ip" {
  value       = google_sql_database_instance.postgres_primary.ip_address[0].ip_address
  description = "Public IP address of the primary PostgreSQL instance"
}

output "replica_instance_connection_name" {
  value       = google_sql_database_instance.postgres_replica.connection_name
  description = "Connection name of the replica PostgreSQL instance"
}

output "replica_instance_ip" {
  value       = google_sql_database_instance.postgres_replica.ip_address[0].ip_address
  description = "Public IP address of the replica PostgreSQL instance"
}

output "database_name" {
  value       = google_sql_database.test_db.name
  description = "Name of the database"
}


## Cloud Function code outputs

# Cloud Function outputs for asia-south2
output "function_name_asia_south2" {
  description = "The name of the deployed Cloud Function in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.name
}

output "function_url_asia_south2" {
  description = "The URL of the deployed Cloud Function in asia-south2"
  value       = "${google_cloudfunctions2_function.db_failover_asia_south2.service_config[0].uri}/trigger-failover"
}

# output "function_location_asia_south2" {
#   description = "The location where the Cloud Function is deployed in asia-south2"
#   value       = google_cloudfunctions2_function.db_failover_asia_south2.location
# }

output "service_account_email_asia_south2" {
  description = "The service account email associated with the Cloud Function in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.service_config[0].service_account_email
}

# output "function_project_asia_south2" {
#   description = "The project ID where the Cloud Function is deployed in asia-south2"
#   value       = google_cloudfunctions2_function.db_failover_asia_south2.project
# }

# Cloud Function outputs for asia-south1
output "function_name_asia_south1" {
  description = "The name of the deployed Cloud Function in asia-south1"
  value       = google_cloudfunctions2_function.db_failover_asia_south1.name
}

output "function_url_asia_south1" {
  description = "The URL of the deployed Cloud Function in asia-south1"
  value       = "${google_cloudfunctions2_function.db_failover_asia_south1.service_config[0].uri}/trigger-failover"
}

# output "function_location_asia_south1" {
#   description = "The location where the Cloud Function is deployed in asia-south1"
#   value       = google_cloudfunctions2_function.db_failover_asia_south1.location
# }

# output "service_account_email_asia_south1" {
#   description = "The service account email associated with the Cloud Function in asia-south1"
#   value       = google_cloudfunctions2_function.db_failover_asia_south1.service_config[0].service_account_email
# }

# output "function_project_asia_south1" {
#   description = "The project ID where the Cloud Function is deployed in asia-south1"
#   value       = google_cloudfunctions2_function.db_failover_asia_south1.project
# }

