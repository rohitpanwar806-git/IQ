/// Central configuration for the IQ Games app.
///
/// These values come from the deployed AWS infrastructure (Terraform outputs).
/// Only public, non-secret identifiers live here — never put AWS access keys
/// in the app. All data access goes through the API Gateway endpoint below.
class AppConfig {
  AppConfig._();

  /// AWS region the backend is deployed in.
  static const String region = 'ap-south-1';

  /// API Gateway base URL (includes the "dev" stage).
  static const String apiBaseUrl =
      'https://onll8tjd6h.execute-api.ap-south-1.amazonaws.com/dev';

  /// Cognito identifiers (used later for real authentication).
  static const String cognitoUserPoolId = 'ap-south-1_Y0g7ExwDs';
  static const String cognitoClientId = '7c9s4754ffpjmqs3n5dird2m74';

  /// Available game identifiers (must match the leaderboard partition keys).
  static const String memoryGameId = 'memory_game';
  static const String mathGameId = 'math_challenge';
}
