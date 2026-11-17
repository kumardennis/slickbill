class AuthCallbackUri {
  AuthCallbackUri._();

  static bool passwordRecoveryPending = false;

  static Map<String, String> params(Uri uri) {
    final merged = Map<String, String>.from(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      merged.addAll(Uri.splitQueryString(uri.fragment));
    }
    return merged;
  }

  static String typeOf(Uri uri) => (params(uri)['type'] ?? '').toLowerCase();

  static bool isPasswordRecovery(Uri uri) => typeOf(uri) == 'recovery';

  static bool isEmailConfirmation(Uri uri) {
    if (uri.queryParameters['verified'] == '1') {
      return true;
    }
    final type = typeOf(uri);
    return type == 'signup' || type == 'email' || type == 'email_change';
  }

  static bool isAuthFlowRoute(String route) {
    return route == '/sign-in' ||
        route.startsWith('/sign-in') ||
        route == '/sign-up' ||
        route == '/forgot-password' ||
        route == '/reset-password';
  }
}
