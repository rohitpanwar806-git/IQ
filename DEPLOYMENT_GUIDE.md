# Complete Deployment & Infrastructure Guide

This guide covers everything you need to set up automated deployments and Google Cloud infrastructure.

## 📋 Overview

You have 2 major deployment workflows:

1. **App Store Deployment** (`github-actions-build.yml`) - Automated mobile app builds & releases
2. **Infrastructure Management** (`infrastructure-terraform.yml`) - Automated Google Cloud setup & updates

---

## Part 1: GitHub Actions Setup for App Stores

See [GITHUB_SECRETS_SETUP.md](GITHUB_SECRETS_SETUP.md) for complete details.

**Quick Summary - Required Secrets:**

### Android / Google Play Store
```
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = <JSON key from Google Cloud>
```

### iOS / App Store
```
APPLE_ID = your.apple.email@icloud.com
APPLE_ID_PASSWORD = <app-specific password>
APPLE_TEAM_ID = ABCD1EF2GH
IOS_BUILD_CERTIFICATE_BASE64 = <base64 encoded .p12 file>
IOS_P12_PASSWORD = <password for .p12 file>
IOS_PROVISIONING_PROFILE_BASE64 = <base64 encoded .mobileprovision>
IOS_KEYCHAIN_PASSWORD = <any password for build keychain>
```

### Optional
```
SLACK_WEBHOOK = https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

---

## Part 2: Google Cloud Infrastructure with Terraform

### Step 1: Create Google Cloud Project

```bash
# Go to https://console.cloud.google.com
# Create a new project
# Enable billing (required for Google Cloud services)
# Copy your PROJECT_ID
```

### Step 2: Create Service Account for Terraform

```bash
# Create a service account
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployer"

# Grant it Editor role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create and download JSON key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Base64 encode the key for GitHub Secrets
base64 -i terraform-key.json | pbcopy  # macOS
# or
base64 terraform-key.json | xclip -selection clipboard  # Linux
```

### Step 3: Add GitHub Secrets for Infrastructure

1. Go to your GitHub repository
2. **Settings** > **Secrets and variables** > **Actions**
3. Add these repository secrets:

| Secret Name | Value |
|---|---|
| `GCP_PROJECT_ID` | Your Google Cloud Project ID |
| `GOOGLE_CLOUD_CREDENTIALS` | Base64 encoded JSON key from Step 2 |

### Step 4: Set Up Infrastructure Configuration

```bash
# Copy example configuration
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars

# Edit with your values
# - project_id: Your GCP Project ID
# - region: us-central1 (or your preferred region)
# - firestore_region: us-central (or your preferred multi-region)
```

### Step 5: Deploy Infrastructure

**Option A: Automatic (Push to main)**
```bash
# Just commit and push infrastructure files to main
git add infrastructure/
git commit -m "feat: deploy cloud infrastructure"
git push origin main
# Watch GitHub Actions automatically deploy
```

**Option B: Manual Trigger**
1. Go to GitHub repo > **Actions**
2. Select "Infrastructure - Terraform Plan & Apply"
3. Click **Run workflow**
4. Choose action: `plan`, `apply`, or `destroy`

### Step 6: Verify Deployment

```bash
# After workflow completes, check what was created
terraform output

# Example output:
# cloud_run_url = "https://iq-games-leaderboard-api-xxxx.run.app"
# firestore_database_id = "..."
# storage_bucket_name = "your-project-id-iq-games-assets"
```

---

## Infrastructure Components Created

### 1. Firestore Database
- **Collections**: users, scores, leaderboards, gameSettings, analytics
- **Indexes**: Automatically created for leaderboard queries
- **Security Rules**: Configured in `infrastructure/firestore.rules`
- **Cost**: Free tier covers most indie games

### 2. Cloud Storage Buckets
- **game-assets**: For game images, sounds, data files
- **backups**: For Firestore backups and logs

### 3. Cloud Run Service (Optional)
- **Leaderboard API**: REST endpoint for getting/posting scores
- **Auto-scaling**: 0 to 100 instances based on demand
- **Cost**: Only charged when handling requests

### 4. Monitoring & Logging
- **Cloud Logging**: All app logs automatically captured
- **Alert Policy**: Triggers notification if error rate > 5%
- **Notification Channels**: Configure where alerts are sent

---

## Firebase Configuration in Flutter App

After infrastructure is deployed, configure your Flutter app:

```dart
// lib/config/firebase_options.dart

import 'package:firebase_core/firebase_core.dart';

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// Run: flutterfire configure
// This auto-generates the correct configuration for your project
```

**Important**: Run this locally to link your Flutter app to your Google Cloud project:
```bash
flutterfire configure
```

---

## Firestore Security Rules

Security rules are in `infrastructure/firestore.rules` and define who can read/write data.

**For Development** (Test Mode):
```
// Anyone can read/write (don't use in production!)
allow read, write: if true;
```

**For Production** (Current Rules):
```
// Users can only read/write their own data
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// Leaderboards are public read-only
match /leaderboards/{gameId} {
  allow read: if true;
  allow write: if false;  // Server-side computation only
}
```

**To Update Rules**:
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Deploy rules
firebase deploy --only firestore:rules
```

---

## Deployment Workflow

### App Development → Production

```
1. Code changes → Push to GitHub
   ↓
2. GitHub Actions triggers workflows:
   - Terraform Plan (if infrastructure files changed)
   - App Build (if app files changed)
   ↓
3. Terraform updates Google Cloud resources (if needed)
   ↓
4. App builds APK and IPA
   ↓
5. App deploys to:
   - Google Play Store (Internal Testing)
   - App Store TestFlight (Automatic)
   ↓
6. Manual promotion to production via store consoles
```

### Manual Deployment Commands

```bash
# Local development
flutter run

# Build for testing
flutter build apk --release
flutter build ipa --release

# Terraform plan (review changes)
cd infrastructure
terraform plan

# Terraform apply (make changes)
terraform apply

# View infrastructure outputs
terraform output
```

---

## Troubleshooting

### "Google Cloud Credentials not found" in GitHub Actions
1. Verify `GOOGLE_CLOUD_CREDENTIALS` secret is set
2. Ensure service account has Editor role
3. Check JSON key is properly base64 encoded

### Firestore queries are slow
1. Create indexes: Go to Firestore Console > Indexes
2. Or let Firestore suggest indexes when you query

### Cloud Run deployment fails
1. Check Cloud Build logs: `gcloud builds log`
2. Ensure service account has Storage permissions
3. Verify Docker image exists

### Firebase configuration issues in app
1. Run `flutterfire configure` to regenerate config files
2. Check `android/app/google-services.json` exists
3. Check `ios/Runner/GoogleService-Info.plist` exists

### Firestore security rules deny access
1. During development, use test mode (allow all)
2. In production, update rules in `infrastructure/firestore.rules`
3. Deploy with `firebase deploy --only firestore:rules`

---

## Cost Optimization

### Free Tier Benefits
- **Firestore**: 50K reads, 20K writes, 20K deletes/month
- **Cloud Run**: 2M requests, 360K GB-seconds/month
- **Cloud Storage**: 5 GB/month
- **Cloud Logging**: 50 GB/month

### Typical Monthly Costs (1000 DAU)
- Firestore: $1-5
- Cloud Run: $0-2
- Cloud Storage: $0-1
- **Total**: ~$1-8/month

### Cost Reduction Tips
1. Use Firestore test mode (free for development)
2. Disable Cloud Run if not needed
3. Archive old game data periodically
4. Use Cloud Storage lifecycle policies to delete old files

---

## Next Steps

- [ ] Create Google Cloud Project
- [ ] Create Terraform service account
- [ ] Add GitHub Secrets (GCP_PROJECT_ID, GOOGLE_CLOUD_CREDENTIALS)
- [ ] Configure terraform.tfvars with your project ID
- [ ] Deploy infrastructure via GitHub Actions
- [ ] Run `flutterfire configure` in Flutter app
- [ ] Configure app store deployment secrets (see GITHUB_SECRETS_SETUP.md)
- [ ] Test app build and deployment
- [ ] Promote to production after testing

