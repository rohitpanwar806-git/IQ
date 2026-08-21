terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "iq-games"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Local variables
locals {
  app_name = "iq-games"
  env      = var.environment
  labels = {
    app         = local.app_name
    environment = local.env
    managed_by  = "terraform"
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "firestore.googleapis.com",
    "identitytoolkit.googleapis.com",
    "firebase.googleapis.com",
    "storage.googleapis.com",
    "run.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Firestore Database
resource "google_firestore_database" "main" {
  provider = google-beta
  project  = var.project_id
  name     = "default"
  location_id = var.firestore_region
  type     = "FIRESTORE_NATIVE"
  
  depends_on = [google_project_service.required_apis]
}

# Firestore Database Indexes
resource "google_firestore_index" "leaderboard_index" {
  provider = google-beta
  project  = var.project_id
  database = google_firestore_database.main.name
  collection = "leaderboards"
  
  fields {
    field_path = "gameId"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "score"
    order      = "DESCENDING"
  }
  
  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "user_scores_index" {
  provider = google-beta
  project  = var.project_id
  database = google_firestore_database.main.name
  collection = "scores"
  
  fields {
    field_path = "userId"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }
}

# Cloud Storage Bucket for game assets
resource "google_storage_bucket" "game_assets" {
  project  = var.project_id
  name     = "${var.project_id}-${local.app_name}-assets"
  location = var.region

  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  labels = local.labels
}

# Cloud Storage Bucket for backups
resource "google_storage_bucket" "backups" {
  project  = var.project_id
  name     = "${var.project_id}-${local.app_name}-backups"
  location = var.region

  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }

  labels = local.labels
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run" {
  account_id   = "${local.app_name}-cloud-run"
  display_name = "IQ Games Cloud Run Service Account"
  project      = var.project_id
}

# Grant Firestore permissions to Cloud Run service account
resource "google_project_iam_member" "cloud_run_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Storage permissions to Cloud Run service account
resource "google_project_iam_member" "cloud_run_storage" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Logging permissions to Cloud Run service account
resource "google_project_iam_member" "cloud_run_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Cloud Run Service for Leaderboard API (optional)
resource "google_cloud_run_service" "leaderboard_api" {
  name     = "${local.app_name}-leaderboard-api"
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.cloud_run.email
      
      containers {
        image = "gcr.io/cloudrun/hello"  # Replace with your API image
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }
        
        env {
          name  = "FIRESTORE_COLLECTION"
          value = "leaderboards"
        }
        
        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
      
      timeout_seconds = 300
    }
    
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
        "autoscaling.knative.dev/minScale" = "0"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.required_apis,
    google_firestore_database.main
  ]
}

# Make Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "public" {
  service  = google_cloud_run_service.leaderboard_api.name
  location = google_cloud_run_service.leaderboard_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
  project  = var.project_id
}

# Cloud Logging Sink for app logs
resource "google_logging_project_sink" "app_logs" {
  name        = "${local.app_name}-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.backups.name}"
  filter      = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_service.leaderboard_api.name}\""
  
  depends_on = [google_storage_bucket.backups]
}

# Grant logging service account access to storage bucket
resource "google_storage_bucket_iam_member" "logging_sink" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${data.google_logging_project_sink_service_account.logging.email}"
  
  depends_on = [google_logging_project_sink.app_logs]
}

data "google_logging_project_sink_service_account" "logging" {
  project_id = var.project_id
}

# Cloud Monitoring Alert for high error rates
resource "google_monitoring_alert_policy" "cloud_run_errors" {
  display_name = "${local.app_name} - Cloud Run Error Rate"
  combiner     = "OR"
  project      = var.project_id

  conditions {
    display_name = "Error rate > 5%"
    
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND resource.labels.service_name = \"${google_cloud_run_service.leaderboard_api.name}\" AND metric.response_code_class = \"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05
      
      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = var.notification_channels
}

# Output values
output "firestore_database_id" {
  value       = google_firestore_database.main.uid
  description = "Firestore Database ID"
}

output "firestore_location" {
  value       = google_firestore_database.main.location_id
  description = "Firestore Database Location"
}

output "cloud_run_url" {
  value       = google_cloud_run_service.leaderboard_api.status[0].url
  description = "Cloud Run Service URL"
}

output "storage_bucket_name" {
  value       = google_storage_bucket.game_assets.name
  description = "Game Assets Storage Bucket"
}

output "storage_backup_bucket_name" {
  value       = google_storage_bucket.backups.name
  description = "Backup Storage Bucket"
}

output "service_account_email" {
  value       = google_service_account.cloud_run.email
  description = "Cloud Run Service Account Email"
}
