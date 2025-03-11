# cloudathon/main.tf

# Active GKE Cluster in asia-south2
resource "google_container_cluster" "active_cluster" {
  provider                 = google.asia-south2
  name                     = "active-gke-cluster"
  location                 = "asia-south2-a"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = "default"
  subnetwork               = "default"
}

resource "google_container_node_pool" "active_nodes" {
  provider   = google.asia-south2
  name       = "active-node-pool"
  cluster    = google_container_cluster.active_cluster.name
  location   = "asia-south2-a"
  node_count = 2
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Passive GKE Cluster in asia-south1
resource "google_container_cluster" "passive_cluster" {
  provider                 = google.asia-south1
  name                     = "passive-gke-cluster"
  location                 = "asia-south1-a"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = "default"
  subnetwork               = "default"
}

resource "google_container_node_pool" "passive_nodes" {
  provider   = google.asia-south1
  name       = "passive-node-pool"
  cluster    = google_container_cluster.passive_cluster.name
  location   = "asia-south1-a"
  node_count = 1
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Cloud SQL PostgreSQL Primary Instance in asia-south2
resource "google_sql_database_instance" "postgres_primary" {
  provider         = google.asia-south2
  name             = "postgres-primary"
  region           = "asia-south2"
  database_version = "POSTGRES_15"

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "REGIONAL"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "0.0.0.0/0" # Restrict to VPC in production
      }
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true # Required for replication
    }
  }
}

# Cloud SQL PostgreSQL Read Replica in asia-south1
resource "google_sql_database_instance" "postgres_replica" {
  provider             = google.asia-south1
  name                 = "postgres-replica"
  region               = "asia-south1"
  database_version     = "POSTGRES_15"
  master_instance_name = google_sql_database_instance.postgres_primary.name

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "REGIONAL"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-clusters"
        value = "0.0.0.0/0" # Restrict to VPC in production
      }
    }
  }

  depends_on = [google_sql_database_instance.postgres_primary]
}

# Database and User
resource "google_sql_database" "app_db" {
  provider = google.asia-south2
  name     = "app-database"
  instance = google_sql_database_instance.postgres_primary.name
}

resource "google_sql_user" "app_user" {
  provider = google.asia-south2
  name     = "app-user"
  instance = google_sql_database_instance.postgres_primary.name
  password = "your-secure-password" # Replace with a secure password
}

# Global Load Balancer for GKE Failover
resource "google_compute_global_address" "global_ip" {
  provider = google.asia-south2
  name     = "gke-global-ip"
}

resource "google_compute_health_check" "gke_health_check" {
  provider = google.asia-south2
  name     = "gke-health-check"
  tcp_health_check {
    port = 80
  }
  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}

resource "google_compute_backend_service" "gke_backend" {
  provider    = google.asia-south2
  name        = "gke-backend-service"
  protocol    = "HTTP"
  timeout_sec = 30
  backend {
    group = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
  }
  backend {
    group = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
  }
  health_checks = [google_compute_health_check.gke_health_check.id]
}

resource "google_compute_url_map" "gke_url_map" {
  provider        = google.asia-south2
  name            = "gke-url-map"
  default_service = google_compute_backend_service.gke_backend.id
}

resource "google_compute_target_http_proxy" "gke_proxy" {
  provider = google.asia-south2
  name     = "gke-http-proxy"
  url_map  = google_compute_url_map.gke_url_map.id
}

resource "google_compute_global_forwarding_rule" "gke_forwarding_rule" {
  provider   = google.asia-south2
  name       = "gke-forwarding-rule"
  target     = google_compute_target_http_proxy.gke_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.global_ip.address
}