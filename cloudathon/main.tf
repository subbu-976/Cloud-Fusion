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
  deletion_protection      = false
}

resource "google_container_node_pool" "active_nodes" {
  provider   = google.asia-south2
  name       = "active-node-pool"
  cluster    = google_container_cluster.active_cluster.name
  location   = "asia-south2-a"
  node_count = 1
  node_config {
    machine_type    = "e2-small"
    disk_size_gb    = 10
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible     = true
  }
  depends_on = [google_container_cluster.active_cluster]
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
  deletion_protection      = false
}

resource "google_container_node_pool" "passive_nodes" {
  provider   = google.asia-south1
  name       = "passive-node-pool"
  cluster    = google_container_cluster.passive_cluster.name
  location   = "asia-south1-a"
  node_count = 1
  node_config {
    machine_type    = "e2-small"
    disk_size_gb    = 10
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible     = true
  }
  depends_on = [google_container_cluster.passive_cluster]
}

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
        value = "0.0.0.0/0" # Restrict to VPC in production
      }
    }
    backup_configuration {
      enabled = false
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
        value = "0.0.0.0/0" # Restrict to VPC in production
      }
    }
  }
  depends_on = [google_sql_database_instance.postgres_primary]
}

# Database and User
resource "google_sql_database" "app_db" {
  provider   = google.asia-south2
  name       = "app-database"
  instance   = google_sql_database_instance.postgres_primary.name
  depends_on = [google_sql_database_instance.postgres_primary]
}

resource "google_sql_user" "app_user" {
  provider   = google.asia-south2
  name       = "app-user"
  instance   = google_sql_database_instance.postgres_primary.name
  password   = "your-secure-password" # Replace with a secure password
  depends_on = [google_sql_database_instance.postgres_primary]
}

# Service Account for Cloud SQL Auth Proxy
resource "google_service_account" "cloud_sql_proxy_sa" {
  provider     = google.asia-south2
  account_id   = "cloud-sql-proxy-sa"
  display_name = "Cloud SQL Proxy Service Account"
}

resource "google_project_iam_member" "cloud_sql_client" {
  provider = google.asia-south2
  project  = "cloudathon-453114" # Replace with your project ID
  role     = "roles/cloudsql.client"
  member   = "serviceAccount:${google_service_account.cloud_sql_proxy_sa.email}"
}

resource "google_service_account_key" "cloud_sql_proxy_key" {
  service_account_id = google_service_account.cloud_sql_proxy_sa.name
}

# Kubernetes Secret for Service Account Key (Active Cluster)
resource "kubernetes_secret" "cloud_sql_proxy_credentials_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "cloud-sql-proxy-credentials"
  }
  data = {
    "credentials.json" = base64decode(google_service_account_key.cloud_sql_proxy_key.private_key)
  }
  depends_on = [google_container_cluster.active_cluster]
}

# Kubernetes Secret for Service Account Key (Passive Cluster)
resource "kubernetes_secret" "cloud_sql_proxy_credentials_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "cloud-sql-proxy-credentials"
  }
  data = {
    "credentials.json" = base64decode(google_service_account_key.cloud_sql_proxy_key.private_key)
  }
  depends_on = [google_container_cluster.passive_cluster]
}

# Kubernetes Secret for Database Credentials (Active Cluster)
resource "kubernetes_secret" "db_credentials_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "db-credentials"
  }
  data = {
    "username" = "app-user"
    "password" = "your-secure-password" # Replace with the same password as above
    "database" = "app-database"
  }
  depends_on = [google_container_cluster.active_cluster]
}

# Kubernetes Secret for Database Credentials (Passive Cluster)
resource "kubernetes_secret" "db_credentials_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "db-credentials"
  }
  data = {
    "username" = "app-user"
    "password" = "your-secure-password" # Replace with the same password as above
    "database" = "app-database"
  }
  depends_on = [google_container_cluster.passive_cluster]
}

# Flask App ConfigMap for Both Clusters (Shared Config)
resource "kubernetes_config_map" "flask_app_config_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "flask-app-config"
  }
  data = {
    "app.py" = <<EOF
from flask import Flask
import psycopg2
import os

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host="127.0.0.1",  # Cloud SQL Proxy runs on localhost
        port="5432",
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME")
    )
    return conn

@app.route('/')
def hello():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, message TEXT);")
    cur.execute("INSERT INTO messages (message) VALUES ('Hello from DB!') ON CONFLICT DO NOTHING;")
    cur.execute("SELECT message FROM messages ORDER BY id DESC LIMIT 1;")
    message = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return f"Message from DB: {message}"

@app.route('/healthz')
def healthz():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
  }
  depends_on = [google_container_cluster.active_cluster]
}

resource "kubernetes_config_map" "flask_app_config_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "flask-app-config"
  }
  data = {
    "app.py" = <<EOF
from flask import Flask
import psycopg2
import os

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host="127.0.0.1",  # Cloud SQL Proxy runs on localhost
        port="5432",
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME")
    )
    return conn

@app.route('/')
def hello():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, message TEXT);")
    cur.execute("INSERT INTO messages (message) VALUES ('Hello from DB!') ON CONFLICT DO NOTHING;")
    cur.execute("SELECT message FROM messages ORDER BY id DESC LIMIT 1;")
    message = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return f"Message from DB: {message}"

@app.route('/healthz')
def healthz():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
  }
  depends_on = [google_container_cluster.passive_cluster]
}

# Flask App Deployment on Active Cluster with Cloud SQL Proxy
resource "kubernetes_deployment" "flask_app_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "flask-app"
    labels = {
      app = "flask-app"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "flask-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "flask-app"
        }
      }
      spec {
        container {
          image = "python:3.9-slim"
          name  = "flask-app"
          command = ["python", "/app/app.py"]
          port {
            container_port = 5000
          }
          volume_mount {
            name       = "flask-app-config"
            mount_path = "/app"
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_active.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_active.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_active.metadata[0].name
                key  = "database"
              }
            }
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        container {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
          args = [
            "--structured-logs",
            "--port=5432",
            "${google_sql_database_instance.postgres_primary.project}:${google_sql_database_instance.postgres_primary.region}:${google_sql_database_instance.postgres_primary.name}=tcp:5432",
            "--credentials-file=/secrets/credentials.json"
          ]
          volume_mount {
            name       = "cloud-sql-proxy-credentials"
            mount_path = "/secrets/"
            read_only  = true
          }
          security_context {
            run_as_non_root = true
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        volume {
          name = "flask-app-config"
          config_map {
            name = kubernetes_config_map.flask_app_config_active.metadata[0].name
          }
        }
        volume {
          name = "cloud-sql-proxy-credentials"
          secret {
            secret_name = kubernetes_secret.cloud_sql_proxy_credentials_active.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes,
    kubernetes_config_map.flask_app_config_active,
    kubernetes_secret.cloud_sql_proxy_credentials_active,
    kubernetes_secret.db_credentials_active
  ]
  timeouts {
    create = "10m"
  }
}

resource "kubernetes_service" "flask_app_service_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "flask-app-service"
  }
  spec {
    selector = {
      app = "flask-app"
    }
    port {
      port        = 80
      target_port = "5000"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_deployment.flask_app_active]
}

# Flask App Deployment on Passive Cluster with Cloud SQL Proxy
resource "kubernetes_deployment" "flask_app_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "flask-app"
    labels = {
      app = "flask-app"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "flask-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "flask-app"
        }
      }
      spec {
        container {
          image = "python:3.9-slim"
          name  = "flask-app"
          command = ["python", "/app/app.py"]
          port {
            container_port = 5000
          }
          volume_mount {
            name       = "flask-app-config"
            mount_path = "/app"
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_passive.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_passive.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db_credentials_passive.metadata[0].name
                key  = "database"
              }
            }
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        container {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
          args = [
            "--structured-logs",
            "--port=5432",
            "${google_sql_database_instance.postgres_primary.project}:${google_sql_database_instance.postgres_primary.region}:${google_sql_database_instance.postgres_primary.name}=tcp:5432",
            "--credentials-file=/secrets/credentials.json"
          ]
          volume_mount {
            name       = "cloud-sql-proxy-credentials"
            mount_path = "/secrets/"
            read_only  = true
          }
          security_context {
            run_as_non_root = true
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
        volume {
          name = "flask-app-config"
          config_map {
            name = kubernetes_config_map.flask_app_config_passive.metadata[0].name
          }
        }
        volume {
          name = "cloud-sql-proxy-credentials"
          secret {
            secret_name = kubernetes_secret.cloud_sql_proxy_credentials_passive.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes,
    kubernetes_config_map.flask_app_config_passive,
    kubernetes_secret.cloud_sql_proxy_credentials_passive,
    kubernetes_secret.db_credentials_passive
  ]
  timeouts {
    create = "10m"
  }
}

resource "kubernetes_service" "flask_app_service_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "flask-app-service"
  }
  spec {
    selector = {
      app = "flask-app"
    }
    port {
      port        = 80
      target_port = "5000"
    }
    type = "NodePort"
  }
  depends_on = [kubernetes_deployment.flask_app_passive]
}

# Global Load Balancer for GKE Failover
resource "google_compute_global_address" "global_ip" {
  provider = google.asia-south2
  name     = "gke-global-ip"
}

resource "google_compute_health_check" "gke_health_check" {
  provider = google.asia-south2
  name     = "gke-health-check"
  http_health_check {
    port         = 80
    request_path = "/healthz"
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
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes,
    google_compute_health_check.gke_health_check
  ]
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