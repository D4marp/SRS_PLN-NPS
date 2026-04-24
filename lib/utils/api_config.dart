// API configuration for Go backend
// Update baseUrl to match your server deployment
class ApiConfig {
  // Android emulator → 10.0.2.2:8080, iOS simulator/macOS → localhost:8080
  static const String baseUrl = 'http://localhost:8080';

  static String? _token;
  static String? get token => _token;
  static void setToken(String? token) => _token = token;
}
