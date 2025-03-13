resource "google_sql_database_instance" "postgres_primary" {
  provider            = google.asia-south2
  name                = "postgres-primary"
  region              = "asia-south2"  # Primary in asia-south2
  database_version    = "POSTGRES_16"  # Latest version as of 2023
  deletion_protection = false          # Set to true in production

  settings {
    tier              = "db-g1-small"  # Standard tier for ENTERPRISE edition
    availability_type = "ZONAL"        # Zonal HA (single zone, no regional failover)
    disk_size         = 10             # 10GB disk; adjust as needed
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "0.0.0.0/0"  # Restrict to VPC in production
      }
    }
    backup_configuration {
      enabled            = true  # Enabled for replication and recovery
      binary_log_enabled = true  # Required for read replicas
    }
  }
}

# Cloud SQL PostgreSQL Read Replica in asia-south1
resource "google_sql_database_instance" "postgres_replica" {
  provider             = google.asia-south1
  name                 = "postgres-replica"
  region               = "asia-south1"                                      # Replica in asia-south1
  database_version     = "POSTGRES_16"                                      # Must match primary
  deletion_protection  = false                                              # Set to true in production
  master_instance_name = google_sql_database_instance.postgres_primary.name # Links to primary

  settings {
    tier              = "db-g1-small"  # Match primary or adjust
    availability_type = "ZONAL"        # Replicas are zonal by default
    disk_size         = 10             # Match primary or adjust
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "0.0.0.0/0"  # Restrict to VPC in production
      }
    }
  }

  depends_on = [google_sql_database_instance.postgres_primary]
}