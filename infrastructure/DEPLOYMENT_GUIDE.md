# Google Cloud Infrastructure Setup Guide

This guide walks you through deploying IQ Games backend infrastructure to Google Cloud using Terraform.

## Prerequisites

1. **Google Cloud Project** - Create one at https://console.cloud.google.com
2. **Terraform CLI** - Install from https://www.terraform.io/downloads
3. **Google Cloud SDK** - Install from https://cloud.google.com/sdk/docs/install
4. **Billing enabled** - Your Google Cloud project must have billing enabled

## Step-by-Step Setup

### 1. Install and Configure gcloud CLI

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Authenticate with Google Cloud
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable billing (if not already enabled)
gcloud billing projects link YOUR_PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### 2. Initialize Terraform

```bash
# Navigate to infrastructure directory
cd infrastructure

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - project_id: Your Google Cloud Project ID
# - region: Preferred region (default: us-central1)
# - firestore_region: Multi-region location (default: us-central)
# - environment: dev, staging, or prod
```

### 3. Initialize Terraform Backend (Optional)

For team collaboration, use remote state storage:

```bash
# Create a GCS bucket for Terraform state
gsutil mb gs://YOUR_PROJECT_ID-terraform-state

# Uncomment the backend block in main.tf
# Update bucket name to match your bucket

# Re-initialize Terraform
terraform init
```

### 4. Plan and Review Changes

```bash
# Initialize Terraform (downloads providers)
terraform init

# Plan the infrastructure
terraform plan -out=tfplan

# Review the output - it shows what will be created
```

### 5. Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply tfplan

# Wait for deployment to complete (5-10 minutes)
```

### 6. Verify Deployment

```bash
# Check outputs
terraform output

# Verify Firestore is created
gcloud firestore databases describe --database='(default)'

# Verify Cloud Run service
gcloud run services list --region=us-central1

# Verify Storage buckets
gsutil ls
```

### 7. Deploy Firestore Security Rules

```bash
# Deploy firestore.rules to your Firestore database
firebase deploy --only firestore:rules

# Or using gcloud
gcloud firestore databases update default \
  --type=firestore-native
```

## Infrastructure Components

### Firestore Database
- **Type**: Firestore Native (not Datastore)
- **Location**: Multi-region (default: us-central)
- **Indexes**: Automatically created for common queries

**Collections**:
- `users/{uid}` - User profiles
- `users/{uid}/scores/{gameId}` - User game scores
- `leaderboards/{gameId}/entries/{entryId}` - Global leaderboards
- `gameSettings/{gameId}` - Game configuration
- `analytics/{userId}` - User analytics

### Cloud Storage Buckets
- **game-assets**: Game images, sounds, data
- **backups**: Automated backups and logs

### Cloud Run Service
- **leaderboard-api**: Optional REST API for leaderboards
- **Autoscaling**: 0 to 100 instances
- **Costs**: Only charged when actively serving requests

### Monitoring
- **Cloud Logging**: Automatic logs from Cloud Run
- **Alert Policy**: Triggers when error rate > 5%
- **Notification Channels**: Configure where to send alerts

## Cost Estimation

### Free Tier (Monthly)
- **Firestore**: 50,000 reads, 20,000 writes, 20,000 deletes
- **Cloud Run**: 2 million requests, 360,000 GB-seconds
- **Cloud Storage**: 5 GB storage
- **Monitoring**: First 5 alert policies free

### Typical Small Game Costs
For a game with ~1,000 daily active users:
- **Firestore**: $1-5/month (well under free tier)
- **Cloud Run**: $0-2/month (optional)
- **Storage**: $0-1/month
- **Total**: ~$1-8/month

## Maintenance

### Update Security Rules

```bash
# Edit firestore.rules
nano firestore.rules

# Deploy updated rules
firebase deploy --only firestore:rules

# Or verify changes locally first:
firebase emulators:start --only firestore
```

### Add Monitoring Alert

```bash
# Get your notification channel ID
gcloud alpha monitoring channels list

# Update terraform.tfvars
notification_channels = ["projects/YOUR_PROJECT_ID/notificationChannels/YOUR_CHANNEL_ID"]

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan
```

### Backup Data

```bash
# Export Firestore collection
gcloud firestore export gs://YOUR_BACKUP_BUCKET/backup-$(date +%Y%m%d)

# Restore from backup
gcloud firestore import gs://YOUR_BACKUP_BUCKET/backup-YYYYMMDD
```

### Scale Resources

```bash
# Edit main.tf to change:
# - Cloud Run: maxScale, minScale
# - Storage: retention policies

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan
```

## Troubleshooting

### "Permission denied" errors

```bash
# Ensure your user has proper roles
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Grant Owner role to your email
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member=user:YOUR_EMAIL \
  --role=roles/owner
```

### "API not enabled" errors

```bash
# Terraform should enable required APIs automatically
# If not, manually enable them:
gcloud services enable firestore.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable logging.googleapis.com
```

### Firestore queries are slow

1. Check if indexes are created (usually automatic)
2. View Firestore Console for "Recommended Indexes"
3. Create missing indexes via Terraform or Console

### Cloud Run service won't deploy

1. Check Cloud Build logs: `gcloud builds log --limit=50`
2. Ensure Docker image exists: `gcloud container images list`
3. Check service account permissions: `gcloud projects get-iam-policy`

## Destroy Infrastructure (Careful!)

```bash
# Backup data first
gcloud firestore export gs://YOUR_BACKUP_BUCKET/final-backup

# Destroy all resources
terraform destroy

# Confirm destruction
# WARNING: This deletes Firestore, Storage, Cloud Run, etc.
```

## Next Steps

1. ✅ Deploy infrastructure with Terraform
2. ✅ Deploy Firestore security rules
3. ✅ Test Firestore connection from Flutter app
4. ✅ Deploy Cloud Run API (optional)
5. ✅ Configure monitoring and alerts
6. ✅ Set up automated backups
7. ✅ Test disaster recovery (restore from backup)

## Documentation

- [Google Cloud Terraform Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Terraform Best Practices](https://cloud.google.com/docs/terraform/best-practices)

