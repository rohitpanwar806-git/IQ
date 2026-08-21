# GitHub Secrets Setup Guide

This guide helps you configure GitHub Secrets for automated deployment to Google Play Store and App Store.

## Google Play Store Setup

### 1. Create a Google Play Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Go to **Service Accounts** (APIs & Services > Credentials > Service Accounts)
4. Click **Create Service Account**
5. Name it: `github-actions-deploy`
6. Grant role: **Editor** (or create custom role with Play Console permissions)
7. Create a JSON key and download it

### 2. Add the Secret to GitHub

1. Go to your GitHub repository
2. **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Name: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
5. Value: Paste the entire JSON file content
6. Click **Add secret**

### 3. Link Service Account to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. **Settings** > **API access**
3. Click **Link Service Account**
4. Select your Google Cloud Project
5. Grant the service account **Admin** permission

---

## App Store Setup

### 1. Create App-Specific Password (Apple ID)

1. Go to [Apple ID Account](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Go to **Security** > **App-Specific Passwords**
4. Generate a new password for "GitHub Actions"
5. Save it somewhere safe (you'll only see it once)

### 2. Get Your Apple Team ID

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **Account** > **Membership**
3. Copy your **Team ID** (e.g., `ABCD1EF2GH`)

### 3. Export iOS Signing Certificates

#### Get Distribution Certificate:
```bash
# Open Keychain Access on your Mac
# Certificates > Certificate Assistant > Request a Certificate from a Certificate Authority
# Or go to App Store Connect > Certificates, Identifiers & Profiles
# Create a new "iOS Distribution Certificate"
# Download and double-click to install
```

#### Export as .p12 file:
```bash
# In Keychain Access
# Right-click "iOS Distribution" certificate > Export
# Save as: ios_distribution.p12
# Set password when prompted
# Base64 encode the file:
base64 -i ios_distribution.p12 | pbcopy
```

### 4. Export Provisioning Profile

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **Certificates, Identifiers & Profiles** > **Provisioning Profiles**
3. Create or select your **App Store Distribution** provisioning profile
4. Download the `.mobileprovision` file
5. Base64 encode it:

```bash
base64 -i *.mobileprovision | pbcopy
```

### 5. Add Secrets to GitHub

1. Go to your GitHub repository
2. **Settings** > **Secrets and variables** > **Actions**
3. Add these secrets:

| Secret Name | Value |
|---|---|
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | The app-specific password (from step 1) |
| `APPLE_TEAM_ID` | Your Team ID (from step 2) |
| `IOS_BUILD_CERTIFICATE_BASE64` | Base64 encoded .p12 file |
| `IOS_P12_PASSWORD` | Password you set when exporting .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 encoded .mobileprovision file |
| `IOS_KEYCHAIN_PASSWORD` | Any password you choose for the build keychain |

### Optional: Slack Notifications

If you want build status notifications in Slack:

1. Create a Slack Webhook: https://api.slack.com/messaging/webhooks
2. Add to GitHub Secrets:
   - Name: `SLACK_WEBHOOK`
   - Value: Your Slack webhook URL

---

## Workflow Triggers

The GitHub Actions workflow runs automatically when:
- Code is pushed to `main` or `release/**` branches
- Changes are made to `lib/`, `pubspec.yaml`, `android/`, `ios/`, or the workflow file itself

You can also trigger manually via **Actions** tab > **Run workflow**.

---

## Deployment Tracks

### Android (Google Play)
- **internal**: Internal testing (deployed automatically on push to main)
- **alpha**: Alpha testing
- **beta**: Beta testing
- **production**: Public release

Change the track in the workflow file:
```yaml
track: internal  # Change to alpha, beta, or production
```

### iOS (App Store)
- **TestFlight**: Automatic on push to main (internal reviewers)
- **App Store**: Manual approval via App Store Connect

---

## Troubleshooting

### Android Build Fails
```bash
# Local testing:
flutter clean
flutter pub get
flutter build appbundle --release
```

### iOS Build Fails
```bash
# Local testing:
flutter clean
flutter pub get
cd ios
pod repo update
pod install
cd ..
flutter build ipa --release
```

### Certificate/Provisioning Issues
- Ensure certificates are not expired (App Store Connect)
- Re-export and update GitHub secrets if certificates change
- Use "Automatic signing" in Xcode if you're still having issues

### Upload Fails
- Verify app bundle/IPA was built successfully
- Check secret names match exactly
- Ensure service account has correct permissions

---

## Security Best Practices

1. **Keep secrets private**: Never commit `.p12` files or JSON keys
2. **Rotate credentials**: Regenerate app-specific passwords periodically
3. **Limit permissions**: Grant only necessary permissions to service accounts
4. **Use GitHub branch protection**: Require approval before merging to `main`
5. **Audit logs**: Check App Store Connect and Google Play Console for deployment history

---

## Next Steps

1. Set up all secrets in GitHub
2. Test the workflow with a manual trigger
3. Monitor the **Actions** tab for build status
4. Once successful, builds will auto-deploy to internal testing
5. Promote to production via App Store Connect / Google Play Console

