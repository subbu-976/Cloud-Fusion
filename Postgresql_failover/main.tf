# Cloud SQL PostgreSQL Primary Instance in asia-south2
resource "google_sql_database_instance" "postgres_primary" {
  provider            = google.asia-south2
  name                = "postgres-primary"
  region              = "asia-south2"
  database_version    = "POSTGRES_16" # Latest PostgreSQL version as of 2023
  deletion_protection = false         # Set to true in production

  settings {
    tier              = "db-custom-2-4096" # 2 vCPUs, 4GB RAM (customize as needed)
    availability_type = "REGIONAL"         # Enables multi-regional HA with failover
    disk_size         = 20                 # 20GB disk (adjust as needed)
    disk_type         = "PD_SSD"           # SSD for better performance

    # IP configuration for external access (optional)
    ip_configuration {
      ipv4_enabled    = true
      private_network = null # Set to VPC network ID if using private IP
      authorized_networks {
        name  = "all"       # For testing; restrict in production
        value = "0.0.0.0/0" # Allow all IPs (insecure; use specific CIDR in prod)
      }
    }

    # Backup configuration (recommended for HA)
    backup_configuration {
      enabled            = true
      binary_log_enabled = true   # Required for replication
      location           = "asia" # Multi-region backup location
    }

    # Maintenance window (optional)
    maintenance_window {
      day  = 7 # Sunday
      hour = 3 # 3 AM UTC
    }
  }
}

# Cloud SQL PostgreSQL Read Replica in asia-south1
resource "google_sql_database_instance" "postgres_replica" {
  provider             = google.asia-south1
  name                 = "postgres-replica"
  region               = "asia-south1"
  database_version     = "POSTGRES_16"                                      # Must match primary
  deletion_protection  = false                                              # Set to true in production
  master_instance_name = google_sql_database_instance.postgres_primary.name # Links to primary

  settings {
    tier              = "db-custom-2-4096" # Match or adjust based on primary
    availability_type = "ZONAL"            # Replicas are zonal by default
    disk_size         = 20                 # Match primary or adjust
    disk_type         = "PD_SSD"

    # IP configuration (optional, must match primary if private)
    ip_configuration {
      ipv4_enabled    = true
      private_network = null # Set to VPC network ID if using private IP
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0" # Allow all IPs (insecure; restrict in prod)
      }
    }
  }

  depends_on = [google_sql_database_instance.postgres_primary]
}