# # Outputs
# output "active_cluster_endpoint" {
#   description = "Endpoint for the active GKE cluster in asia-south2"
#   value       = google_container_cluster.active_cluster.endpoint
# }

# output "active_cluster_ca_certificate" {
#   description = "Base64-encoded CA certificate for the active GKE cluster"
#   value       = google_container_cluster.active_cluster.master_auth[0].cluster_ca_certificate
#   sensitive   = true
# }

# output "active_service_load_balancer_ip" {
#   description = "External IP address of the LoadBalancer service for the active cluster"
#   value       = kubernetes_service.hello_world_service_active.status[0].load_balancer[0].ingress[0].ip
#   depends_on  = [kubernetes_service.hello_world_service_active]
# }

# output "passive_cluster_endpoint" {
#   description = "Endpoint for the passive GKE cluster in asia-south1"
#   value       = google_container_cluster.passive_cluster.endpoint
# }

# output "passive_cluster_ca_certificate" {
#   description = "Base64-encoded CA certificate for the passive GKE cluster"
#   value       = google_container_cluster.passive_cluster.master_auth[0].cluster_ca_certificate
#   sensitive   = true
# }

# output "postgres_primary_public_ip" {
#   description = "Public IP address of the primary PostgreSQL instance in asia-south2"
#   value       = google_sql_database_instance.postgres_primary.ip_address[0].ip_address
# }

# output "postgres_replica_public_ip" {
#   description = "Public IP address of the replica PostgreSQL instance in asia-south1"
#   value       = google_sql_database_instance.postgres_replica.ip_address[0].ip_address
# }

# output "global_load_balancer_ip" {
#   description = "Global IP address for the GKE load balancer"
#   value       = google_compute_global_address.global_ip.address
# }