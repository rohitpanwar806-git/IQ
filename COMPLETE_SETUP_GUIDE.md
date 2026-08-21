# IQ Games - Complete Setup & Deployment Guide

A comprehensive guide for setting up, building, and deploying the IQ Mind Games mobile app to Google Play Store and App Store, with automated CI/CD using GitHub Actions and infrastructure managed by Terraform.

## 📊 Project Overview

```
IQ Mind Games
├── Frontend: Flutter (iOS + Android)
├── Backend: Google Cloud Firestore (Real-time Database)
├── Authentication: Firebase Auth
├── Analytics: Firebase Analytics + Google Cloud Logging
├── Deployment: GitHub Actions (CI/CD)
└── Infrastructure: Terraform (IaC)
```

---

## 🚀 Quick Start (5-10 minutes)

### 1. Local Development Setup
```bash
# Install Flutter
flutter pub get

# Run app locally
flutter run -d iPhone  # or Android emulator

# Make code changes and hot reload
# Press 'R' in terminal to reload
```

### 2. Push to GitHub
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

### 3. Automated Workflows Start!
- GitHub Actions builds your app
- Terraform deploys your infrastructure
- Your leaderboards go live

---

## 📋 Complete Setup Checklist

### Phase 1: Project Preparation (You do this once)

- [ ] **Create GitHub Repository**
  - [ ] Enable GitHub Actions
  - [ ] Create main and develop branches
  - [ ] Enable branch protection on main

- [ ] **Create Google Cloud Project**
  - Go to [console.cloud.google.com](https://console.cloud.google.com)
  - [ ] Create new project
  - [ ] Enable billing
  - [ ] Copy Project ID

- [ ] **Set Up Terraform**
  - [ ] Create service account for Terraform
  - [ ] Generate JSON key and base64 encode it
  - [ ] Add GitHub Secrets:
    - `GCP_PROJECT_ID` = Your Google Cloud Project ID
    - `GOOGLE_CLOUD_CREDENTIALS` = Base64 encoded JSON key

- [ ] **Deploy Infrastructure**
  - [ ] Edit `infrastructure/terraform.tfvars` with your project ID
  - [ ] Push to main branch
  - [ ] Watch GitHub Actions deploy Firestore, Cloud Run, Storage

### Phase 2: App Store Setup (Required for publishing)

- [ ] **Google Play Store**
  - Create [Google Play Developer Account](https://play.google.com/console) ($25)
  - [ ] Create service account for Play Store
  - [ ] Generate JSON key and add to GitHub Secrets:
    - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

- [ ] **App Store (iOS)**
  - [ ] Create [Apple Developer Account](https://developer.apple.com) ($99/year)
  - [ ] Export iOS Distribution Certificate
  - [ ] Export App Store Provisioning Profile
  - [ ] Generate app-specific password
  - [ ] Add to GitHub Secrets:
    - `APPLE_ID`
    - `APPLE_ID_PASSWORD`
    - `APPLE_TEAM_ID`
    - `IOS_BUILD_CERTIFICATE_BASE64`
    - `IOS_P12_PASSWORD`
    - `IOS_PROVISIONING_PROFILE_BASE64`
    - `IOS_KEYCHAIN_PASSWORD`

### Phase 3: Firebase Configuration

- [ ] **Link Flutter App to Firebase**
  ```bash
  flutterfire configure
  ```
  This creates:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`

- [ ] **Enable Firebase Services**
  - [ ] Firestore Database
  - [ ] Firebase Authentication
  - [ ] Firebase Analytics
  - [ ] Cloud Messaging (for push notifications)

### Phase 4: First Deployment

- [ ] **Test Infrastructure**
  ```bash
  cd infrastructure
  terraform plan
  terraform apply
  ```

- [ ] **Test App Build Locally**
  ```bash
  flutter build apk --release  # Android
  flutter build ipa --release  # iOS
  ```

- [ ] **Push to GitHub main**
  ```bash
  git add .
  git commit -m "Ready for CI/CD"
  git push origin main
  ```

- [ ] **Watch GitHub Actions**
  - Go to repo > Actions tab
  - See build-android and build-ios workflows
  - Apps deploy to:
    - Google Play Store (Internal Testing)
    - App Store TestFlight

- [ ] **Promote to Production**
  - Go to Google Play Console > Internal Testing
  - Review and promote to production
  - Go to App Store Connect > TestFlight
  - Submit for App Review

---

## 📁 Project Structure

```
iq_games/
│
├── lib/                          # Flutter app source code
│   ├── services/
│   │   └── firebase_service.dart # Firebase integration
│   ├── screens/                  # Game screens
│   ├── models/                   # Data models
│   ├── providers/                # State management (Riverpod/GetX)
│   └── main.dart                 # App entry point
│
├── infrastructure/               # Google Cloud infrastructure
│   ├── main.tf                   # Terraform config (Firestore, Cloud Run, Storage)
│   ├── variables.tf              # Variable definitions
│   ├── terraform.tfvars          # Your project configuration
│   ├── firestore.rules           # Firestore security rules
│   └── DEPLOYMENT_GUIDE.md       # Detailed infrastructure guide
│
├── deploy/                       # GitHub Actions workflows
│   ├── github-actions-build.yml  # App build & deployment
│   ├── infrastructure-terraform.yml # Infrastructure deployment
│   ├── GITHUB_SECRETS_SETUP.md   # Guide for setting up GitHub Secrets
│   └── github-actions-readme.md  # GitHub Actions reference
│
├── pubspec.yaml                  # Flutter dependencies
├── README.md                      # Project README
├── DEPLOYMENT_GUIDE.md           # Complete deployment guide (this file)
└── AGENTS.md                     # AI agent instructions
```

---

## 🔐 GitHub Secrets Quick Reference

### App Store Deployment Secrets
```
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
APPLE_ID
APPLE_ID_PASSWORD
APPLE_TEAM_ID
IOS_BUILD_CERTIFICATE_BASE64
IOS_P12_PASSWORD
IOS_PROVISIONING_PROFILE_BASE64
IOS_KEYCHAIN_PASSWORD
SLACK_WEBHOOK (optional)
```

### Infrastructure Secrets
```
GCP_PROJECT_ID
GOOGLE_CLOUD_CREDENTIALS
```

---

## 🔄 Development Workflow

### Daily Development
```bash
# Start local dev
flutter run -d iPhone

# Make changes
# (Code in lib/, change UI, update game logic)

# Hot reload
# Press 'R' in terminal

# Commit and push
git add .
git commit -m "feat: add memory game"
git push origin feature/memory-game
```

### Code Review & Merge
```bash
# Create Pull Request on GitHub
# (Actions run: terraform plan, app build verification)

# Wait for approvals
# Merge to main

# Watch Actions deploy:
# ✓ Terraform apply (if infrastructure changed)
# ✓ Build Android APK & App Bundle
# ✓ Build iOS IPA
# ✓ Deploy to Google Play Internal Testing
# ✓ Deploy to App Store TestFlight
```

### Promoting to Production
```bash
# Go to Google Play Console
# → Internal Testing → Promote to Production

# Go to App Store Connect
# → TestFlight → Submit for App Review
# → Wait for approval → Release
```

---

## 📊 What Gets Automatically Deployed

### When you push to main:

1. **Terraform Workflow** (if infrastructure files changed)
   - ✅ Creates/updates Firestore database
   - ✅ Creates/updates Cloud Run API
   - ✅ Creates/updates Storage buckets
   - ✅ Deploys Firestore indexes
   - ✅ Configures monitoring & alerts

2. **App Build Workflow** (if app files changed)
   - ✅ Builds Android APK & App Bundle
   - ✅ Builds iOS IPA with code signing
   - ✅ Tests app (if tests exist)
   - ✅ Uploads APK to artifacts
   - ✅ Deploys App Bundle to Google Play (internal)
   - ✅ Deploys IPA to App Store Connect (TestFlight)

3. **Post-Deployment**
   - ✅ Artifacts available for download
   - ✅ Slack notification (if configured)
   - ✅ Build status in GitHub commit

---

## 🔧 Common Tasks

### Add a New Game
```dart
// 1. Create screen
lib/screens/games/puzzle_game_screen.dart

// 2. Use Firebase to save score
final firebaseService = FirebaseService();
await firebaseService.submitGameScore(
  userId: userId,
  gameId: 'puzzle_game',
  score: 1500,
  duration: 120,
  difficulty: 'hard',
);

// 3. Push to main → Auto-deploys
```

### Update Firestore Rules
```
// 1. Edit infrastructure/firestore.rules
match /leaderboards/{gameId} {
  allow read: if true;
  allow write: if false;
}

// 2. Deploy
firebase deploy --only firestore:rules
// Or just push to main → Terraform auto-updates
```

### Scale Cloud Run
```
# Edit infrastructure/main.tf
maxScale = 200  # Increase from 100

# Apply
terraform apply
```

### Check App Analytics
```
# Real-time: Firebase Console > Analytics
# Historical: Google Cloud Logging > Logs

# Queries via SDK:
FirebaseAnalytics.instance.logEvent(
  name: 'game_completed',
  parameters: {'score': 1500},
);
```

### Monitor Errors & Performance
```
# Cloud Run logs
gcloud run services describe iq-games-leaderboard-api

# Firestore performance
Firebase Console > Firestore > Performance

# Alerts
Google Cloud Console > Monitoring > Alert Policies
```

---

## 💰 Cost Breakdown

### Free Tier (Monthly)
- Firestore: 50K reads, 20K writes, 20K deletes ✅
- Cloud Run: 2M requests, 360K GB-seconds ✅
- Cloud Storage: 5 GB ✅
- Cloud Logging: 50 GB ✅
- **Cost: $0/month** (for most indie games)

### Typical Game (1,000 DAU)
- Firestore: $1-5/month (well under free tier)
- Cloud Run: $0-2/month (if enabled)
- Cloud Storage: $0-1/month
- App Store & Play Store: 30% of revenue
- **Total: ~$1-8/month**

### Cost Optimization
- Use Firestore test mode (free) during development
- Disable Cloud Run if not needed
- Archive old data periodically
- Use Storage lifecycle policies

---

## 🆘 Troubleshooting

### GitHub Actions Build Fails
```bash
# Check workflow logs
GitHub > Actions > Failed workflow

# Common fixes:
1. flutter clean && flutter pub get
2. Verify secrets are set correctly
3. Check Flutter version in workflow matches your local

# To debug locally:
flutter build apk --release
flutter build ipa --release
```

### Firestore Errors in App
```
"Permission denied" → Check firestore.rules
"Collection not found" → Create collection in Firestore Console
"Document not found" → Check document path
"Quota exceeded" → You hit free tier limit (unlikely)
```

### Terraform Deployment Fails
```bash
# Re-initialize
cd infrastructure
terraform init

# Debug plan
terraform plan -destroy -lock=false

# Check credentials
gcloud auth login
gcloud auth list
```

### App Won't Launch
```bash
# Check Firebase config
flutter clean
flutterfire configure  # Regenerate config files

# Check dependencies
flutter pub get
flutter pub outdated

# Check logs
flutter run -v  # Verbose output
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| [README.md](README.md) | Project overview and quick start |
| [AGENTS.md](AGENTS.md) | Project conventions and architecture |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | This file - complete setup guide |
| [deploy/GITHUB_SECRETS_SETUP.md](deploy/GITHUB_SECRETS_SETUP.md) | GitHub Secrets configuration |
| [infrastructure/DEPLOYMENT_GUIDE.md](infrastructure/DEPLOYMENT_GUIDE.md) | Terraform/GCP infrastructure details |

---

## 🎯 Next Steps

1. **Complete Phase 1-4** from checklist above
2. **Make first code change** and push to main
3. **Watch GitHub Actions** deploy your changes
4. **Test in TestFlight/Internal Testing**
5. **Promote to production** when ready
6. **Monitor analytics** in Firebase Console

---

## 📞 Need Help?

### Issues
- Check GitHub Actions logs: Repo > Actions > Failed workflow
- Check Cloud Build logs: `gcloud builds log --limit=50`
- Check Firestore errors: Firebase Console > Firestore
- Check Cloud Run logs: `gcloud run services describe SERVICE_NAME --log`

### Quick Fixes
```bash
# Clear everything and start fresh
flutter clean
flutter pub get
flutterfire configure
cd infrastructure && terraform init
```

### Resources
- [Flutter Docs](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest)

---

**Last Updated**: 2026-08-21
**Status**: Production Ready ✅

