/// IMPORTANT:
/// Set this to the address where your backend (see /backend folder) is running.
///
/// - Android emulator talking to a backend on your dev machine: http://10.0.2.2:4000/api
/// - Real phone on the same Wi-Fi as your dev machine:          http://<your-pc-lan-ip>:4000/api
/// - Deployed backend (Render/Railway/VPS etc.):                https://your-domain.com/api
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api',
  );
}
