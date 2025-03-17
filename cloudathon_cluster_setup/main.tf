# cloudathon/main.tf

data "google_client_config" "default" {}

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
  autoscaling {
    min_node_count = 1
    max_node_count = 3
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
    machine_type = "e2-medium"
    disk_size_gb = 20
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible  = true
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  depends_on = [google_container_cluster.passive_cluster]
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
  <h1>Hello World! (Active - asia-south2)</h1>
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
  <h1>Hello World! (Passive - asia-south1)</h1>
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
              "ephemeral-storage" = "100Mi"
            }
            limits = {
              cpu               = "200m"
              memory            = "256Mi"
              "ephemeral-storage" = "200Mi"
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
      node_port   = 30080
    }
    type = "NodePort"
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
              "ephemeral-storage" = "100Mi"
            }
            limits = {
              cpu               = "200m"
              memory            = "256Mi"
              "ephemeral-storage" = "200Mi"
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
      node_port   = 30080
    }
    type = "NodePort"
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
    port         = 30080
    request_path = "/"
  }
  timeout_sec         = 1   # Faster timeout
  check_interval_sec  = 2   # Check more frequently
  healthy_threshold   = 2
  unhealthy_threshold = 2   # Fail after 2 failed checks (~4 seconds)
}


resource "google_compute_backend_service" "gke_backend" {
  provider    = google.asia-south2
  name        = "gke-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group           = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 0.8
  }

  backend {
    group           = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 0.8
  }

  health_checks = [google_compute_health_check.gke_health_check.id]
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes,
    google_compute_health_check.gke_health_check
  ]
}

resource "google_compute_instance_group_named_port" "active_named_port" {
  provider   = google.asia-south2
  group      = google_container_node_pool.active_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 30080
  zone       = "asia-south2-a"
  depends_on = [google_container_node_pool.active_nodes]
}

resource "google_compute_instance_group_named_port" "passive_named_port" {
  provider   = google.asia-south1
  group      = google_container_node_pool.passive_nodes.managed_instance_group_urls[0]
  name       = "http"
  port       = 30080
  zone       = "asia-south1-a"
  depends_on = [google_container_node_pool.passive_nodes]
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

# Firewall Rule for NodePort Traffic
resource "google_compute_firewall" "allow_nodeport_traffic" {
  provider = google.asia-south2
  name     = "allow-nodeport-traffic"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"] # GKE NodePort range
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

# Dedicated Firewall Rule for Health Check Traffic
resource "google_compute_firewall" "allow_health_checks" {
  provider = google.asia-south2
  name     = "allow-health-checks"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["30080"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  priority = 900

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

# Additional Firewall Rule for Direct Access on Port 80 (Optional)
resource "google_compute_firewall" "allow_direct_access_port_80" {
  provider = google.asia-south2
  name     = "allow-direct-access-port-80"
  network  = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"] # Adjust to your IP for security
  target_tags = [
    "gke-active-gke-cluster-232e0592-node",
    "gke-passive-gke-cluster-7319025a-node"
  ]

  depends_on = [
    google_container_cluster.active_cluster,
    google_container_cluster.passive_cluster
  ]
}

# Null resource to ensure instance groups are ready
resource "null_resource" "wait_for_instance_groups" {
  depends_on = [
    google_container_node_pool.active_nodes,
    google_container_node_pool.passive_nodes
  ]

  provisioner "local-exec" {
    command = "powershell -Command \"Start-Sleep -Seconds 30\""
  }
}

# Data sources to fetch instance group details
data "google_compute_instance_group" "active_instance_group" {
  provider = google.asia-south2
  name     = element([for url in google_container_node_pool.active_nodes.managed_instance_group_urls : element(split("/", url), length(split("/", url)) - 1)], 0)
  zone     = "asia-south2-a"
  depends_on = [null_resource.wait_for_instance_groups]
}

data "google_compute_instance_group" "passive_instance_group" {
  provider = google.asia-south1
  name     = element([for url in google_container_node_pool.passive_nodes.managed_instance_group_urls : element(split("/", url), length(split("/", url)) - 1)], 0)
  zone     = "asia-south1-a"
  depends_on = [null_resource.wait_for_instance_groups]
}

# Fetch instance details for active node
data "google_compute_instance" "active_instance" {
  provider = google.asia-south2
  name     = element(split("/", tolist(data.google_compute_instance_group.active_instance_group.instances)[0]), 10)
  zone     = "asia-south2-a"
  depends_on = [data.google_compute_instance_group.active_instance_group]
}

# Fetch instance details for passive node
data "google_compute_instance" "passive_instance" {
  provider = google.asia-south1
  name     = element(split("/", tolist(data.google_compute_instance_group.passive_instance_group.instances)[0]), 10)
  zone     = "asia-south1-a"
  depends_on = [data.google_compute_instance_group.passive_instance_group]
}

# Outputs
output "global_load_balancer_ip" {
  description = "Global IP address for the GKE load balancer"
  value       = google_compute_global_address.global_ip.address
}

output "active_node_ip" {
  description = "External IP address of an active cluster node"
  value       = data.google_compute_instance.active_instance.network_interface[0].access_config[0].nat_ip
}

output "passive_node_ip" {
  description = "External IP address of a passive cluster node"
  value       = data.google_compute_instance.passive_instance.network_interface[0].access_config[0].nat_ip
}