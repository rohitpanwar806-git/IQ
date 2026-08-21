# IQ Mind Games

A free, lightweight mobile game featuring multiple IQ challenges with cloud-based leaderboards and score tracking. Available on Google Play Store and Apple App Store.

## Quick Start

### 1. Prerequisites
Before starting, ensure you have:
- **Flutter SDK** 3.x and **Dart** 3.x installed
- **Android Studio** with Android SDK 21+ for Android builds
- **Xcode** 13+ (macOS only) for iOS builds
- A **Google Cloud Project** with Firestore enabled
- A **Firebase Project** linked to your Google Cloud Project
- A **Google Play Developer Account** ($25 one-time)
- An **Apple Developer Program Membership** ($99/year, for App Store publishing)

### 2. Project Setup

```bash
# Clone or create project
mkdir iq_games
cd iq_games

# Initialize Flutter project (if starting fresh)
# flutter create --template=app iq_games

# Install dependencies
flutter pub get

# Set up Firebase for your platforms (creates config files)
flutterfire configure

# Verify everything is ready
flutter doctor
```

### 3. Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Enable **Firestore Database** (Start in test mode for development)
4. Enable **Firebase Authentication** (Anonymous + Email/Password)
5. Run `flutterfire configure` to link your Flutter app

### 4. Firestore Security Rules

For development (test mode):
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null || true;
    }
  }
}
```

For production (before publishing), restrict access:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /scores/{uid}/games/{gameId} {
      allow read: if true;
      allow write: if request.auth.uid == uid;
    }
    match /leaderboards/{gameId} {
      allow read: if true;
    }
  }
}
```

### 5. Development

#### Run on simulator/emulator:
```bash
# iOS simulator
flutter run -d iPhone

# Android emulator
flutter run -d emulator-5554

# List available devices
flutter devices
```

#### Make code changes:
- Modify files in `lib/`
- Hot reload: Press `R` in terminal
- Full restart: Press `Shift+R` in terminal

### 6. Game Development

Each game is a separate screen in `lib/screens/games/`. To add a new game:

1. Create `lib/screens/games/[game_name]_screen.dart`
2. Extend `StatefulWidget` or use `GetX/Riverpod` for state
3. Handle game logic, timer, scoring
4. Submit scores to Firestore when game ends
5. Add game to `GameSelectionScreen`

Example game score structure:
```dart
{
  'userId': 'user123',
  'gameId': 'memory_game',
  'score': 1200,
  'difficulty': 'hard',
  'duration': 120, // seconds
  'timestamp': Timestamp.now(),
}
```

### 7. Building for Release

#### Android (Google Play Store):
```bash
flutter build appbundle --release
# Upload to Google Play Console via Play Console UI
```

#### iOS (App Store):
```bash
flutter build ipa --release
# Upload via Xcode Organizer or Transporter app
```

### 8. Publishing Checklist

#### Before submitting:

**For Google Play:**
- [ ] App icon (512x512 PNG)
- [ ] 4-6 screenshots (1080x1920 for phones)
- [ ] App description and privacy policy URL
- [ ] Minimum Android API 21
- [ ] Content rating questionnaire completed

**For App Store:**
- [ ] App icon (1024x1024 PNG)
- [ ] 2-5 screenshots per device size
- [ ] Privacy policy URL
- [ ] Category and content rating
- [ ] Demo video (optional)

### 9. Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart

# Check code quality
flutter analyze
```

## Project Structure

See [AGENTS.md](AGENTS.md) for detailed architecture and conventions.

## Common Issues

### Android build fails
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### iOS build fails
```bash
flutter clean
flutter pub get
cd ios
pod repo update
pod install
cd ..
flutter build ios --release
```

### Firestore not syncing
- Check Firebase Console for errors
- Ensure `google-services.json` and `GoogleService-Info.plist` are properly configured
- Verify Firestore security rules allow read/write for your authenticated users

## Documentation

- [Flutter Docs](https://flutter.dev/docs)
- [Firebase Docs](https://firebase.google.com/docs)
- [Google Cloud Docs](https://cloud.google.com/docs)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)

## Next Steps

1. **Set up Firebase**: Follow section 3 above
2. **Create first game**: Build a simple memory or puzzle game screen
3. **Connect to Firestore**: Implement score submission and leaderboard retrieval
4. **Test on device**: Run on actual Android/iOS device before publishing
5. **Prepare store listings**: Create screenshots, descriptions, and privacy policy
6. **Submit for review**: Upload to Google Play and App Store

## License

MIT (customize as needed)

---

**Questions?** Refer to [AGENTS.md](AGENTS.md) for architecture details and development conventions.
