/// Exceptions for the management API client (CLI / MCP).
///
/// Pure Dart — no Flutter imports, so it can run under `dart run`.
library;

/// Base class for all management-client failures.
class ManagementException implements Exception {
  ManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The API responded with a non-2xx status.
class ApiException extends ManagementException {
  ApiException(this.statusCode, final String message, {this.body}) : super(message);

  final int statusCode;
  final Map<String, dynamic>? body;

  bool get isAuth => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServer => statusCode >= 500;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

/// No/invalid credentials configured locally.
class AuthConfigException extends ManagementException {
  AuthConfigException(super.message);
}

/// Local project config missing or invalid.
class ConfigException extends ManagementException {
  ConfigException(super.message);
}

/// A (key, locale) could not be resolved to a translation id.
class ResolveException extends ManagementException {
  ResolveException(super.message);
}
