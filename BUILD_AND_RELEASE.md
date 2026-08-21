# Build & Release Guide — IQ Mind Games

This guide takes the Flutter app from your machine to the Google Play Store.
Follow it top to bottom the first time.

---

## 1. Install Flutter (one-time)

Flutter is **not** installed yet. Install it, then confirm:

```powershell
# After installing the Flutter SDK and adding it to PATH:
flutter --version
flutter doctor
```

Fix anything `flutter doctor` flags (Android SDK, licenses):

```powershell
flutter doctor --android-licenses
```

---

## 2. Generate the platform folders (one-time)

The repo currently contains only the Dart code in `lib/`. Generate the
`android/`, `ios/`, and `web/` folders **without touching `lib/`**:

```powershell
flutter create --org com.iqgames .
flutter pub get
```

> `flutter create .` is safe to run in an existing project — it adds the
> missing platform folders and never overwrites your `lib/` code.

---

## 3. Run the app locally

```powershell
# List available devices/emulators
flutter devices

# Run on a connected Android device or emulator
flutter run
```

The app should open to **IQ Mind Games**, let you play **Memory Match**, and
show the live **Leaderboard** (reads from your AWS API).

> Score submission requires the backend POST route to be deployed — see
> `infrastructure/BACKEND_STATE_MIGRATION.md`.

---

## 4. Create a release signing key (one-time)

Google Play requires a signed App Bundle. Generate an upload keystore:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep this `.jks` file and its passwords **safe and private** — never commit them.

Create `android/key.properties` (this file is git-ignored — do not commit it):

```properties
storePassword=<password you chose>
keyPassword=<password you chose>
keyAlias=upload
storeFile=C:\\Users\\<you>\\upload-keystore.jks
```

Then wire signing into `android/app/build.gradle` (add above `android {`):

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

And inside `android { ... }` replace the `buildTypes` release block:

```gradle
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
```

Also confirm `minSdkVersion 21` (or higher) in `android/app/build.gradle`.

---

## 5. Build the release App Bundle

```powershell
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 6. Upload to Google Play

1. Go to the [Google Play Console](https://play.google.com/console) (your $25
   developer account).
2. **Create app** → fill name (IQ Mind Games), language, "Game", "Free".
3. Complete the required sections (they gate the release):
   - **Store listing**: short/full description, app icon (512×512), feature
     graphic (1024×500), at least 2 phone screenshots.
   - **Content rating** questionnaire.
   - **Data safety** form (declare that scores + display name are collected).
   - **Privacy policy** URL (required — you can host a simple page for free).
4. **Production → Create new release** → upload the `.aab` → roll out.

First review typically takes a few days.

---

## Free alternatives while you wait

- **Direct APK**: `flutter build apk --release` → share the `.apk` file directly.
- **Flutter Web**: `flutter build web` → host free on GitHub Pages / Firebase
  Hosting / Netlify.
- **Amazon Appstore**: free developer account, another distribution channel.

---

## iOS / App Store (later)

Requires a **macOS machine** + **Apple Developer Program ($99/year)**:

```bash
flutter build ipa --release
```

Then upload the `.ipa` via Xcode or Transporter to App Store Connect.
