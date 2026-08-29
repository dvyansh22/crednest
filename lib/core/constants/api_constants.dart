class ApiConstants {
  /// Base URL of your backend.
  /// 
  /// --- LOCAL HOST CONSIDERATIONS ---
  /// * Android Emulator: Use 'http://10.0.2.2:8000' (redirects to host machine's localhost:8000)
  /// * iOS Simulator: Use 'http://localhost:8000' or 'http://127.0.0.1:8000'
  /// * Physical Devices: Use your machine's local IP address (e.g. 'http://192.168.1.XX:8000') 
  ///   and make sure your phone and server are on the same Wi-Fi network.
  /// 
  /// --- PRODUCTION CONSIDERATIONS ---
  /// * Replace with your production server URL (e.g. 'https://api.crednest.com')
  // For local development with Setu/ngrok, replace this with your ngrok/localtunnel URL!
  // Example: static const String baseUrl = "https://crednest-aa.loca.lt";
  static const String baseUrl = "https://sharp-hats-swim.loca.lt";

  static const String login = "/auth/login";
  static const String signup = "/auth/signup";
  static const String forgotPassword = "/auth/forgot-password";
  static const String logout = "/auth/logout";
  static const String refreshToken = "/auth/refresh";
  static const String currentUser = "/auth/me";
}
