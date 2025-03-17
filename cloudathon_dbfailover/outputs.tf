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

output "username" {
  value       = google_sql_user.postgres_user.name
  description = "Username for the database"
}

output "password" {
  value       = google_sql_user.postgres_user.password
  description = "Password for the database"
  sensitive   = true
}