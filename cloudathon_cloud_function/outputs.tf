# Cloud Function outputs for asia-south2
output "function_name_asia_south2" {
  description = "The name of the deployed Cloud Function in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.name
}

output "function_url_asia_south2" {
  description = "The URL of the deployed Cloud Function in asia-south2"
  value       = "${google_cloudfunctions2_function.db_failover_asia_south2.service_config[0].uri}/trigger-failover"
}

output "function_location_asia_south2" {
  description = "The location where the Cloud Function is deployed in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.location
}

output "service_account_email_asia_south2" {
  description = "The service account email associated with the Cloud Function in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.service_config[0].service_account_email
}

output "function_project_asia_south2" {
  description = "The project ID where the Cloud Function is deployed in asia-south2"
  value       = google_cloudfunctions2_function.db_failover_asia_south2.project
}

# Cloud Function outputs for asia-south1
output "function_name_asia_south1" {
  description = "The name of the deployed Cloud Function in asia-south1"
  value       = google_cloudfunctions2_function.db_failover_asia_south1.name
}

output "function_url_asia_south1" {
  description = "The URL of the deployed Cloud Function in asia-south1"
  value       = "${google_cloudfunctions2_function.db_failover_asia_south1.service_config[0].uri}/trigger-failover"
}

output "function_location_asia_south1" {
  description = "The location where the Cloud Function is deployed in asia-south1"
  value       = google_cloudfunctions2_function.db_failover_asia_south1.location
}

output "service_account_email_asia_south1" {
  description = "The service account email associated with the Cloud Function in asia-south1"
  value       = google_cloudfunctions2_function.db_failover_asia_south1.service_config[0].service_account_email
}

output "function_project_asia_south1" {
  description = "The project ID where the Cloud Function is deployed in asia-south1"
  value       = google_cloudfunctions2_function.db_failover_asia_south1.project
}