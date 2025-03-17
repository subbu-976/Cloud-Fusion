# variables.tf

# Project and General Configurations
variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "cloudathon-453114"
}

# GKE Cluster Configurations
variable "active_cluster_name" {
  description = "Name of the active GKE cluster in asia-south2"
  type        = string
  default     = "active-gke-cluster"
}

variable "passive_cluster_name" {
  description = "Name of the passive GKE cluster in asia-south1"
  type        = string
  default     = "passive-gke-cluster"
}

variable "active_cluster_location" {
  description = "Zone for the active GKE cluster"
  type        = string
  default     = "asia-south2-a"
}

variable "passive_cluster_location" {
  description = "Zone for the passive GKE cluster"
  type        = string
  default     = "asia-south1-a"
}

variable "node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 20
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

# Kubernetes Deployment Configurations
variable "replicas" {
  description = "Number of replicas for Kubernetes deployments"
  type        = number
  default     = 1
}

variable "cpu_request" {
  description = "CPU request for Kubernetes containers"
  type        = string
  default     = "100m"
}

variable "cpu_limit" {
  description = "CPU limit for Kubernetes containers"
  type        = string
  default     = "200m"
}

variable "memory_request" {
  description = "Memory request for Kubernetes containers"
  type        = string
  default     = "128Mi"
}

variable "memory_limit" {
  description = "Memory limit for Kubernetes containers"
  type        = string
  default     = "256Mi"
}

variable "ephemeral_storage_request" {
  description = "Ephemeral storage request for Kubernetes containers"
  type        = string
  default     = "100Mi"
}

variable "ephemeral_storage_limit" {
  description = "Ephemeral storage limit for Kubernetes containers"
  type        = string
  default     = "200Mi"
}

# Load Balancer Configurations
variable "health_check_timeout_sec" {
  description = "Timeout in seconds for health checks"
  type        = number
  default     = 1
}

variable "health_check_interval_sec" {
  description = "Interval in seconds between health checks"
  type        = number
  default     = 2
}

variable "healthy_threshold" {
  description = "Number of successful checks to consider healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of failed checks to consider unhealthy"
  type        = number
  default     = 2
}

variable "backend_timeout_sec" {
  description = "Timeout in seconds for backend service"
  type        = number
  default     = 30
}

variable "capacity_scaler" {
  description = "Capacity scaler for backend service"
  type        = number
  default     = 1.0
}

variable "max_utilization" {
  description = "Maximum utilization for backend service"
  type        = number
  default     = 0.8
}

# Database Configurations
variable "primary_db_name" {
  description = "Name of the primary PostgreSQL database instance"
  type        = string
  default     = "postgres-primary"
}

variable "replica_db_name" {
  description = "Name of the replica PostgreSQL database instance"
  type        = string
  default     = "postgres-replica"
}

variable "primary_db_region" {
  description = "Region for the primary PostgreSQL instance"
  type        = string
  default     = "asia-south2"
}

variable "replica_db_region" {
  description = "Region for the replica PostgreSQL instance"
  type        = string
  default     = "asia-south1"
}

variable "database_version" {
  description = "PostgreSQL database version"
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "Machine tier for the PostgreSQL instance"
  type        = string
  default     = "db-g1-small"
}

variable "db_disk_size" {
  description = "Disk size for the PostgreSQL instance in GB"
  type        = number
  default     = 10
}

variable "authorized_network_range" {
  description = "Authorized network range for database access"
  type        = string
  default     = "203.0.113.0/24"
}

variable "test_db_name" {
  description = "Name of the test database on the primary instance"
  type        = string
  default     = "test_db"
}

# Cloud Function Configurations
variable "source_bucket_name" {
  description = "Name of the GCS bucket for Cloud Function source code"
  type        = string
  default     = "cloudathon-453114-source"
}

variable "source_bucket_location" {
  description = "Location of the GCS bucket for Cloud Function source code"
  type        = string
  default     = "ASIA-SOUTH2"
}

variable "function_memory" {
  description = "Memory allocation for Cloud Functions"
  type        = string
  default     = "512M"
}

variable "function_timeout" {
  description = "Timeout in seconds for Cloud Functions"
  type        = number
  default     = 600
}

variable "service_account_email" {
  description = "Service account email for Cloud Functions"
  type        = string
  default     = "vdc-serviceaccount-cloudathon@cloudathon-453114.iam.gserviceaccount.com"
}