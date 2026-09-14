import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single place that picks staging vs production hosts.
///
/// - Local / `APP_ENV=dev` → current staging stack
/// - Release / Vercel `APP_ENV=production` → URLs from dart-define / env
///
/// Do not scatter `kDebugMode` URL checks. Read from here.
class AppEnv {
  AppEnv._();

  static const stagingSupabaseUrl = 'https://fwujdruuvspdoqflttrl.supabase.co';
  static const stagingExpressServerUrl = 'https://express-ten-xi.vercel.app';
  static const stagingWalletClientUrl = 'https://wallet.slickbills.com';
  static const stagingAppBaseUrl = 'https://app.slickbills.com';

  static const _appEnvDefine =
      String.fromEnvironment('APP_ENV', defaultValue: '');
  static const _supabaseUrlDefine =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const _expressUrlDefine =
      String.fromEnvironment('EXPRESS_SERVER_URL', defaultValue: '');
  static const _walletClientUrlDefine =
      String.fromEnvironment('WALLET_CLIENT_URL', defaultValue: '');
  static const _appBaseUrlDefine =
      String.fromEnvironment('APP_BASE_URL', defaultValue: '');
  static const _web3AuthNetworkDefine =
      String.fromEnvironment('WEB3AUTH_NETWORK', defaultValue: '');

  static String _fromDotenv(String key) {
    if (!kDebugMode) return '';
    return dotenv.env[key]?.trim() ?? '';
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _stripSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  /// `dev` | `production`
  static String get name {
    final raw = _firstNonEmpty([
      _appEnvDefine,
      _fromDotenv('APP_ENV'),
    ]).toLowerCase();
    if (raw == 'prod' || raw == 'production') return 'production';
    if (raw == 'dev' || raw == 'development' || raw == 'staging') {
      return 'dev';
    }
    // Unset → staging. Production is opt-in via APP_ENV so release phone
    // builds and local web builds do not silently hit live euros.
    return 'dev';
  }

  static bool get isProduction => name == 'production';
  static bool get isDev => !isProduction;

  static String get supabaseUrl {
    final override = _firstNonEmpty([
      _supabaseUrlDefine,
      _fromDotenv('SUPABASE_URL'),
    ]);
    if (override.isNotEmpty) return _stripSlash(override);
    if (isDev) return stagingSupabaseUrl;
    throw StateError(
      'SUPABASE_URL is required when APP_ENV=production. '
      'Set it as a dart-define / Vercel env var. Do not fall back to staging.',
    );
  }

  static String get expressServerUrl {
    final override = _firstNonEmpty([
      _expressUrlDefine,
      _fromDotenv('EXPRESS_SERVER_URL'),
    ]);
    if (override.isNotEmpty) return _stripSlash(override);
    if (isDev) return stagingExpressServerUrl;
    throw StateError(
      'EXPRESS_SERVER_URL is required when APP_ENV=production.',
    );
  }

  static String get walletClientUrl {
    final override = _firstNonEmpty([
      _walletClientUrlDefine,
      _fromDotenv('WALLET_CLIENT_URL'),
    ]);
    if (override.isNotEmpty) return _stripSlash(override);
    if (isDev) return stagingWalletClientUrl;
    throw StateError(
      'WALLET_CLIENT_URL is required when APP_ENV=production. '
      'Until DNS cutover use https://slickbills-wallet-client-prod.vercel.app',
    );
  }

  static String get appBaseUrl {
    final override = _firstNonEmpty([
      _appBaseUrlDefine,
      _fromDotenv('APP_BASE_URL'),
    ]);
    if (override.isNotEmpty) return _stripSlash(override);
    return stagingAppBaseUrl;
  }

  static String get walletClientOrigin => Uri.parse(walletClientUrl).origin;
  static String get appHost => Uri.parse(appBaseUrl).host;

  /// `sapphire_devnet` | `sapphire_mainnet`
  static String get web3AuthNetwork {
    final raw = _firstNonEmpty([
      _web3AuthNetworkDefine,
      _fromDotenv('WEB3AUTH_NETWORK'),
    ]).toLowerCase();
    if (raw == 'sapphire_mainnet' || raw == 'mainnet') {
      return 'sapphire_mainnet';
    }
    if (raw == 'sapphire_devnet' || raw == 'devnet') {
      return 'sapphire_devnet';
    }
    return isProduction ? 'sapphire_mainnet' : 'sapphire_devnet';
  }

  static String billUrl(String token) => '$appBaseUrl/bill/$token';
  static String merchantCheckInUrl(String token) => '$appBaseUrl/m/$token';

  static void logSelection() {
    debugPrint(
      '[AppEnv] name=$name supabase=$supabaseUrl express=$expressServerUrl '
      'wallet=$walletClientUrl app=$appBaseUrl web3auth=$web3AuthNetwork',
    );
  }
}
