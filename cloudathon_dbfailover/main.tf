# Cloud SQL PostgreSQL Primary Instance in asia-south2
resource "google_sql_database_instance" "postgres_primary" {
  provider            = google.asia-south2
  name                = "postgres-primary"
  region              = "asia-south2"
  database_version    = "POSTGRES_15"
  deletion_protection = false

  settings {
    tier              = "db-g1-small"
    availability_type = "ZONAL"
    disk_size         = 10

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "203.0.113.0/24" # Replace with your specific IP range
      }
    }

    # ✅ Enable Automatic Backups
    backup_configuration {
      enabled                        = true  # Turn on backups
      start_time                     = "03:00" # Backup window (UTC)
      location                        = "asia-south2" # Backup location
      point_in_time_recovery_enabled = true  # Enable PITR
      # binary_log_enabled             = true  # Required for PITR
    }
  }
}

# Cloud SQL PostgreSQL Read Replica in asia-south1 
resource "google_sql_database_instance" "postgres_replica" {
  provider             = google.asia-south1
  name                 = "postgres-replica"
  region               = "asia-south1"
  database_version     = "POSTGRES_15"
  deletion_protection  = false
  master_instance_name = google_sql_database_instance.postgres_primary.name

  settings {
    tier              = "db-g1-small"
    availability_type = "ZONAL"
    disk_size         = 10

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "203.0.113.0/24" # Replace with your specific IP range
      }
    }
  }

  depends_on = [google_sql_database_instance.postgres_primary]
}

# Database on the primary instance
resource "google_sql_database" "test_db" {
  provider = google.asia-south2
  name     = "test_db"
  instance = google_sql_database_instance.postgres_primary.name
}

# User for the primary instance
resource "google_sql_user" "postgres_user" {
  provider = google.asia-south2
  name     = "postgres"
  instance = google_sql_database_instance.postgres_primary.name
  password = "primarydbpassword"
}
