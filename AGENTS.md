# AI Agent Instructions

This file helps AI coding agents understand and contribute effectively to this project.

## Project Overview

**IQ Mind Games** - A free, lightweight mobile game featuring multiple IQ challenges (memory, logic, puzzles, pattern recognition) with cloud-based leaderboards and score tracking. Targets both Google Play Store and Apple App Store.

**Tech Stack:**
- Frontend: Flutter (Dart) - Cross-platform iOS & Android
- Backend: Google Cloud Firestore (real-time database)
- Authentication: Firebase Authentication
- Deployment: Google Cloud Run (optional API layer), Firebase Hosting
- Analytics: Firebase Analytics
- Push Notifications: Firebase Cloud Messaging

## Getting Started

### Prerequisites
- Flutter 3.x or later
- Dart 3.x
- Android Studio + Android SDK (for Android builds)
- Xcode 13+ (for iOS builds on macOS)
- Google Cloud Project with Firestore enabled
- Firebase Project (linked to Google Cloud)
- Google Play Developer account ($25 one-time)
- Apple Developer Program membership ($99/year)

### Environment Setup
```bash
# Install Flutter
flutter pub get

# Set up Firebase locally (creates google-services.json for Android, GoogleService-Info.plist for iOS)
flutterfire configure

# Verify setup
flutter doctor
```

### Build & Test Commands
```bash
# Install dependencies
flutter pub get

# Run development (iOS simulator)
flutter run -d iPhone

# Run development (Android emulator)
flutter run -d emulator-5554

# Run tests
flutter test

# Build APK for Android
flutter build apk --release

# Build App Bundle for Google Play Store
flutter build appbundle --release

# Build iOS app for App Store
flutter build ipa --release
```

## Project Structure

```
iq_games/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   ├── firebase_options.dart    # Firebase config
│   │   └── routes.dart              # Route definitions
│   ├── models/
│   │   ├── user.dart
│   │   ├── game_score.dart
│   │   └── leaderboard_entry.dart
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── home_screen.dart
│   │   ├── game_selection_screen.dart
│   │   ├── games/
│   │   │   ├── memory_game_screen.dart
│   │   │   ├── logic_puzzle_screen.dart
│   │   │   ├── pattern_recognition_screen.dart
│   │   │   └── math_challenge_screen.dart
│   │   ├── leaderboard_screen.dart
│   │   └── user_profile_screen.dart
│   ├── services/
│   │   ├── firebase_service.dart    # Firebase/Firestore operations
│   │   ├── auth_service.dart        # Authentication
│   │   └── analytics_service.dart   # Firebase Analytics
│   ├── providers/
│   │   ├── auth_provider.dart       # State management (GetX or Riverpod)
│   │   ├── game_provider.dart
│   │   └── leaderboard_provider.dart
│   ├── widgets/
│   │   ├── game_card.dart
│   │   ├── leaderboard_list.dart
│   │   └── custom_button.dart
│   └── utils/
│       ├── constants.dart
│       ├── themes.dart
│       └── helpers.dart
├── android/
│   └── app/build.gradle             # Android build config
├── ios/
│   └── Podfile                      # iOS dependencies
├── pubspec.yaml                     # Flutter dependencies
├── pubspec.lock
└── README.md
```

## Key Conventions

- **Naming**: PascalCase for classes/widgets, camelCase for functions/variables, snake_case for files
- **Code Style**: Follow Dart/Flutter best practices, use `dart format` and `flutter analyze`
- **State Management**: Use GetX or Riverpod for reactive state (avoid Provider patterns for games)
- **Game Architecture**: Each game is a separate screen with its own logic, scoring, and submission to Firestore
- **Firestore Structure**:
  - `users/{uid}` - User profile data
  - `scores/{uid}/games/{gameId}` - Individual game scores
  - `leaderboards/{gameId}` - Global leaderboard per game
- **Testing**: Unit tests for logic, widget tests for UI components, integration tests for end-to-end flows
- **Git/PR**: Feature branches (`feature/game-name`), commit messages describe the feature/fix

## Common Development Tasks

- **Add a new game**: Create `screens/games/[game_name]_screen.dart`, add model in `models/`, connect to Firestore scoring
- **Deploy to Google Play**: Run `flutter build appbundle --release`, upload to Play Console
- **Deploy to App Store**: Run `flutter build ipa --release`, upload via Xcode/Transporter
- **Debug Firestore issues**: Use Firebase Console to inspect collections, test security rules
- **Test on devices**: Use `flutter run -d <device_id>` for iOS/Android devices
- **Monitor analytics**: Check Firebase Analytics dashboard for user behavior and game metrics

## Documentation References

Link to key docs (don't duplicate them here):
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Setup Guide](https://firebase.google.com/docs/flutter/setup)
- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

## Pitfalls & Gotchas

- **Android build failures**: Clean build cache with `flutter clean` before rebuilding, ensure Android SDK is up-to-date
- **iOS build issues**: Use `flutter clean && flutter pub get` and update pods with `cd ios && pod repo update`
- **Firestore security rules**: Rules are restrictive by default—enable read/write for unauthenticated testing, then lock down for production
- **Firebase configuration**: Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are added to project via `flutterfire configure`
- **Game performance**: Profile with Flutter DevTools to avoid jank in animations; use `RepaintBoundary` to isolate expensive widgets
- **Apple app review**: Games with leaderboards need clear privacy policies; avoid overly aggressive ads or IAP prompts
- **Google Play store rejection**: Ensure minimum Android API level 21+, include proper app icons/screenshots, follow content policies

## Technology-Specific Notes

### Flutter & Dart
- Use `GetX` or `Riverpod` for state management; avoid nested callbacks with `.then()` chains
- Prefer `async/await` over `.then()` for asynchronous operations
- Use `const` constructors for immutable widgets to reduce rebuild overhead
- Platform-specific code goes in `android/` and `ios/` directories; use `dart:io` conditionals sparingly

### Firestore Backend
- Structure data hierarchically (`users/{uid}/scores/{gameId}`) for efficient querying
- Use `.where()` filters cautiously; index frequently queried fields
- Real-time listeners (`.snapshots()`) should be disposed to prevent memory leaks
- Batch writes for bulk operations to avoid hitting rate limits

### Game Development
- Each game screen should handle its own state (timer, score calculation, UI updates)
- Score submission should include timestamp, game metadata, and user ID
- Leaderboard queries should use pagination to avoid fetching thousands of records
- Use `CustomPaint` for complex game rendering; avoid rebuilding entire game state every frame

### Deployment
- Test both APK and IPA locally before uploading to stores
- Google Play requires API level 21 minimum; App Store requires iOS 11+
- Use Firebase Cloud Messaging for push notifications post-launch
- Monitor crash reports via Firebase Crashlytics post-release

---

**Last updated**: 2026-08-21
**Status**: Template — customize with your project details
