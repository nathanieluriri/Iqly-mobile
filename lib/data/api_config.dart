/// Where the app finds the iQLY API, and the public OAuth client ids.
///
/// `--dart-define=IQLY_API_URL=https://api.iqly.net` and
/// `--dart-define=IQLY_WEB_URL=https://iqly.net` point a build at
/// production; `--dart-define=IQLY_LIVE_AUTH=false` keeps the demo sign-in
/// for preview films.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'IQLY_API_URL',
    defaultValue: 'https://staging.api.iqly.net',
  );

  static const liveAuth = bool.fromEnvironment(
    'IQLY_LIVE_AUTH',
    defaultValue: true,
  );

  /// The web app, where a password reset link lands.
  static const webUrl = String.fromEnvironment(
    'IQLY_WEB_URL',
    defaultValue: 'https://staging.iqly.net',
  );

  /// Better Auth serves contributors under /auth/web.
  static const authPath = '/auth/web';

  /// Android asks Google for an ID token issued to the web client; iOS gets
  /// one for its own client. The API accepts both.
  static const googleWebClientId =
      '724865297296-pjv4fpqllacbo0cp1t6rcmigjao7d26j.apps.googleusercontent.com';
  static const googleIosClientId =
      '724865297296-ccsujpput3002mq4br7c7t17mqt61s5m.apps.googleusercontent.com';
}
