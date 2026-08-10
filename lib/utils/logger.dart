class Logger {
  static void log(String message) {
    print('[LOG] $message');
  }

  static void logRequest(
      String url, Map<String, String> headers, dynamic body) {
    print('[REQUEST] URL: $url');
    print('[REQUEST] Headers: $headers');
    print('[REQUEST] Body: $body');
  }

  static void logResponse(int statusCode, dynamic body) {
    print('[RESPONSE] Status Code: $statusCode');
    print('[RESPONSE] Body: $body');
  }
}
