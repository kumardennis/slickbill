import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CoinbaseService {
  // ✅ Change this to your local server URL during development
  // For production, use your deployed Vercel URL
  static String get baseUrl {
    return 'https://express-denniskumar299-2803-dennis-projects-be7d97f3.vercel.app';
  }

  // For production:
  // static const String baseUrl = 'https://your-app.vercel.app';

  /// Create or get a CDP account
  static Future<Map<String, dynamic>> createOrGetAccount({
    required String accountName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cdp/create-or-get-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': accountName,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create account: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating account: $e');
    }
  }

  static Future<Map<String, dynamic>> getAccount({
    required String accountName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cdp/get-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': accountName,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create account: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating account: $e');
    }
  }

  /// Request testnet faucet (get free EURC on Base Sepolia)
  static Future<Map<String, dynamic>> requestTestnetFaucet({
    required String accountName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cdp/request-testnet-faucet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': accountName,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to request faucet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error requesting faucet: $e');
    }
  }

  /// Get account balances
  static Future<Map<String, dynamic>> getBalances({
    required String accountName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cdp/get-balances'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': accountName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to get balances: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting balances: $e');
    }
  }

  /// Transfer EURC to another address
  static Future<Map<String, dynamic>> transferEURC({
    required String fromAccountName,
    required String toAccountName,
    required double amount,
  }) async {
    print(
        'Transferring ${(amount)} EURC from $fromAccountName to $toAccountName');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cdp/send-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromAccountName': fromAccountName,
          'toAccountName': toAccountName,
          'amountEurc': amount,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to transfer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error transferring: $e');
    }
  }

  /// Proxy request to external API (e.g., LHV bank)
  static Future<Map<String, dynamic>> proxyRequest({
    required String url,
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/proxy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'method': method,
          'headers': headers ?? {},
          'body': body,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Proxy request failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error in proxy request: $e');
    }
  }
}
