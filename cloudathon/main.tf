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
    machine_type = "e2-medium"
    disk_size_gb = 20
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible  = true
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  depends_on = [google_container_cluster.active_cluster]
}

resource "google_compute_instance_group_named_port" "active_named_port" {
  provider   = google.asia-south2
  group      = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 80
  zone       = "asia-south2-a"
  depends_on = [google_container_node_pool.active_nodes]
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
    machine_type = "e2-medium"
    disk_size_gb = 20
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible  = true
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  depends_on = [google_container_cluster.passive_cluster]
}
resource "google_compute_instance_group_named_port" "passive_named_port" {
  provider   = google.asia-south1
  group      = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 80
  zone       = "asia-south1-a"
  depends_on = [google_container_node_pool.passive_nodes]
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

# ConfigMap for Hello World HTML
resource "kubernetes_config_map" "hello_world_config_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world-config"
  }
  data = {
    "index.html" = <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello World</title>
</head>
<body>
  <h1>Hello World!</h1>
</body>
</html>
EOF
  }
  depends_on = [google_container_cluster.active_cluster, google_container_node_pool.active_nodes]
}

resource "kubernetes_config_map" "hello_world_config_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world-config"
  }
  data = {
    "index.html" = <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Hello World</title>
</head>
<body>
  <h1>Hello World!</h1>
</body>
</html>
EOF
  }
  depends_on = [google_container_cluster.passive_cluster, google_container_node_pool.passive_nodes]
}

# Hello World Deployment on Active Cluster
resource "kubernetes_deployment" "hello_world_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "hello-world"
      }
    }
    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
          resources {
            requests = {
              cpu               = "100m"
              memory            = "128Mi"
              ephemeral-storage = "100Mi"
            }
            limits = {
              cpu               = "200m"
              memory            = "256Mi"
              ephemeral-storage = "200Mi"
            }
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.hello_world_config_active.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_cluster.active_cluster,
    google_container_node_pool.active_nodes,
    kubernetes_config_map.hello_world_config_active
  ]
  timeouts {
    create = "10m"
  }
}

resource "kubernetes_service" "hello_world_service_active" {
  provider = kubernetes.asia-south2
  metadata {
    name = "hello-world-service"
  }
  spec {
    selector = {
      app = "hello-world"
    }
    port {
      port        = 80
      target_port = 80
      node_port   = 30080 # Arbitrary port between 30000-32767
    }
    type = "NodePort" # Changed from ClusterIP
  }
  depends_on = [
    google_container_cluster.active_cluster,
    google_container_node_pool.active_nodes,
    kubernetes_deployment.hello_world_active
  ]
}

# Hello World Deployment on Passive Cluster
resource "kubernetes_deployment" "hello_world_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "hello-world"
      }
    }
    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
          resources {
            requests = {
              cpu               = "100m"
              memory            = "128Mi"
              ephemeral-storage = "100Mi"
            }
            limits = {
              cpu               = "200m"
              memory            = "256Mi"
              ephemeral-storage = "200Mi"
            }
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.hello_world_config_passive.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    google_container_cluster.passive_cluster,
    google_container_node_pool.passive_nodes,
    kubernetes_config_map.hello_world_config_passive
  ]
  timeouts {
    create = "10m"
  }
}

resource "kubernetes_service" "hello_world_service_passive" {
  provider = kubernetes.asia-south1
  metadata {
    name = "hello-world-service"
  }
  spec {
    selector = {
      app = "hello-world"
    }
    port {
      port        = 80
      target_port = 80
      node_port   = 30080 # Use the same port for consistency
    }
    type = "NodePort" # Changed from ClusterIP
  }
  depends_on = [
    google_container_cluster.passive_cluster,
    google_container_node_pool.passive_nodes,
    kubernetes_deployment.hello_world_passive
  ]
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
    request_path = "/"
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
  port_name   = "http" # This matches the named port set above
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
    google_compute_health_check.gke_health_check,
    google_compute_instance_group_named_port.active_named_port,
    google_compute_instance_group_named_port.passive_named_port
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