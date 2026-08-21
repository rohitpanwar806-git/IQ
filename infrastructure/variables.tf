variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be a valid Google Cloud project ID format."
  }
}

variable "region" {
  type        = string
  description = "Google Cloud region for resources"
  default     = "us-central1"
  
  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1", "asia-southeast1"], var.region)
    error_message = "Please specify a valid Google Cloud region."
  }
}

variable "firestore_region" {
  type        = string
  description = "Firestore database region (must be multi-region: us-central, europe-west, asia-southeast)"
  default     = "us-central"
  
  validation {
    condition     = contains(["us-central", "europe-west", "asia-southeast", "eur3", "nam5"], var.firestore_region)
    error_message = "Firestore region must be a valid multi-region location."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "notification_channels" {
  type        = list(string)
  description = "Google Cloud Monitoring notification channel IDs for alerts"
  default     = []
}
