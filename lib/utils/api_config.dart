// API configuration for Go backend
// Update baseUrl to match your server deployment
class ApiConfig {
  static const String baseUrl = 'http://10.7.41.116:8080';

  static String? _token;
  static String? get token => _token;
  static void setToken(String? token) => _token = token;
}
