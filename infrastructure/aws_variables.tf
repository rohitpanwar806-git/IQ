variable "aws_region" {
  type        = string
  description = "AWS region for resources"
  default     = "ap-south-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "Please specify a valid AWS region (e.g., ap-south-1, us-east-1)."
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

variable "lambda_timeout" {
  type        = number
  description = "Lambda function timeout in seconds"
  default     = 30
}

variable "lambda_memory" {
  type        = number
  description = "Lambda function memory in MB"
  default     = 256
}
