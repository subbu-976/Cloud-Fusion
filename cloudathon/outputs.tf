# # cloudathon/outputs.tf

# output "active_cluster_endpoint" {
#   value       = google_container_cluster.active_cluster.endpoint
#   description = "Endpoint for the active GKE cluster in asia-south2"
# }

# output "passive_cluster_endpoint" {
#   value       = google_container_cluster.passive_cluster.endpoint
#   description = "Endpoint for the passive GKE cluster in asia-south1"
# }

# output "postgres_primary_ip" {
#   value       = google_sql_database_instance.postgres_primary.ip_address[0].ip_address
#   description = "IP address of the PostgreSQL primary instance in asia-south2"
# }

# output "postgres_replica_ip" {
#   value       = google_sql_database_instance.postgres_replica.ip_address[0].ip_address
#   description = "IP address of the PostgreSQL replica instance in asia-south1"
# }

# output "load_balancer_ip" {
#   value       = google_compute_global_address.global_ip.address
#   description = "Global load balancer IP for GKE clusters"
# }