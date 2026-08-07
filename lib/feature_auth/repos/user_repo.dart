import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepo {
  final SupabaseClient _client = Supabase.instance.client;

  /// Update CDP wallet ID for a user.
  Future<Map<String, dynamic>?> updateCdpWalletId({
    required int userId,
    required String cdpWalletId,
    required String cdpUserId,
  }) async {
    try {
      final response = await _client
          .from('users')
          .update({
            'cdpWalletId': cdpWalletId,
            'cdpUserId': cdpUserId,
          })
          .eq('id', userId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error updating CDP wallet ID: $e');
      rethrow;
    }
  }

  /// Get user's CDP wallet ID.
  Future<String?> getCdpWalletId(int userId) async {
    try {
      final response = await _client
          .from('users')
          .select('cdpWalletId')
          .eq('id', userId)
          .single();

      return response['cdpWalletId'] as String?;
    } catch (e) {
      debugPrint('Error fetching CDP wallet ID: $e');
      return null;
    }
  }

  /// Update MetaMask wallet address for a user.
  Future<Map<String, dynamic>?> updateMetamaskWalletAddress({
    required int userId,
    required String walletAddress,
  }) async {
    try {
      final response = await _client
          .from('users')
          .update({'metamask_wallet_address': walletAddress})
          .eq('id', userId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error updating MetaMask wallet address: $e');
      rethrow;
    }
  }

  /// Get user's MetaMask wallet address.
  Future<String?> getMetamaskWalletAddress(int userId) async {
    try {
      final response = await _client
          .from('users')
          .select('metamask_wallet_address')
          .eq('id', userId)
          .single();

      return response['metamask_wallet_address'] as String?;
    } catch (e) {
      debugPrint('Error fetching MetaMask wallet address: $e');
      return null;
    }
  }

  /// Update primary IBAN fields for a private user profile.
  Future<Map<String, dynamic>?> updatePrimaryIbanColumn({
    required int privateUserId,
    required String iban,
    String? bankName,
    String? bankAccountName,
    bool includeTopLevelBankName = true,
  }) async {
    try {
      final payload = <String, dynamic>{'iban': iban};
      final normalizedIban = iban.trim();
      final trimmedBankName = bankName?.trim();
      final trimmedBankAccountName = bankAccountName?.trim();

      if (includeTopLevelBankName &&
          bankName != null &&
          bankName.trim().isNotEmpty) {
        payload['bankName'] = bankName.trim();
      }
      if (bankAccountName != null && bankAccountName.trim().isNotEmpty) {
        payload['bankAccountName'] = bankAccountName.trim();
      }

      final existing = await _client
          .from('private_users')
          .select('ibans')
          .eq('id', privateUserId)
          .maybeSingle();

      final existingIbans = (existing?['ibans'] as List<dynamic>?) ?? const [];
      final updatedIbans = <Map<String, dynamic>>[];
      var hasTargetIban = false;

      for (final item in existingIbans) {
        if (item is! Map) {
          continue;
        }

        final row = Map<String, dynamic>.from(item);
        final rowIban = row['iban']?.toString().trim() ?? '';
        final isTarget = rowIban == normalizedIban;

        row['isPrimary'] = isTarget;
        if (isTarget) {
          hasTargetIban = true;
          if (trimmedBankName != null && trimmedBankName.isNotEmpty) {
            row['bankName'] = trimmedBankName;
          }
          if (trimmedBankAccountName != null &&
              trimmedBankAccountName.isNotEmpty) {
            row['bankAccountName'] = trimmedBankAccountName;
          }
        }

        updatedIbans.add(row);
      }

      if (!hasTargetIban) {
        updatedIbans.add({
          'iban': normalizedIban,
          'bankName': trimmedBankName ?? '',
          'bankAccountName': trimmedBankAccountName ?? '',
          'isPrimary': true,
        });
      }

      payload['ibans'] = updatedIbans;

      final response = await _client
          .from('private_users')
          .update(payload)
          .eq('id', privateUserId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error updating primary IBAN column: $e');
      rethrow;
    }
  }

  /// Merge and persist IBAN JSON entries while keeping current primary selection.
  /// If no primary exists after merge, the first IBAN is promoted to primary and
  /// top-level iban / bankName / bankAccountName columns are synced.
  Future<Map<String, dynamic>?> upsertIbansJson({
    required int privateUserId,
    required List<Map<String, dynamic>> ibans,
  }) async {
    try {
      final existing = await _client
          .from('private_users')
          .select('ibans, iban, bankName, bankAccountName')
          .eq('id', privateUserId)
          .maybeSingle();

      final existingIbans = (existing?['ibans'] as List<dynamic>?) ?? const [];
      final merged = <Map<String, dynamic>>[];

      for (final item in existingIbans) {
        if (item is! Map) {
          continue;
        }
        merged.add(Map<String, dynamic>.from(item));
      }

      for (final incoming in ibans) {
        final next = Map<String, dynamic>.from(incoming);
        final normalizedIban = next['iban']?.toString().trim() ?? '';
        if (normalizedIban.isEmpty) {
          continue;
        }

        final existingIndex = merged.indexWhere(
          (row) => (row['iban']?.toString().trim() ?? '') == normalizedIban,
        );

        if (existingIndex >= 0) {
          final current = Map<String, dynamic>.from(merged[existingIndex]);
          final hasIncomingBankName =
              (next['bankName']?.toString().trim().isNotEmpty ?? false);
          final hasIncomingAccountName =
              (next['bankAccountName']?.toString().trim().isNotEmpty ?? false);

          if (hasIncomingBankName) {
            current['bankName'] = next['bankName'].toString().trim();
          }
          if (hasIncomingAccountName) {
            current['bankAccountName'] =
                next['bankAccountName'].toString().trim();
          }

          merged[existingIndex] = current;
          continue;
        }

        merged.add({
          'iban': normalizedIban,
          'bankName': next['bankName']?.toString().trim() ?? '',
          'bankAccountName': next['bankAccountName']?.toString().trim() ?? '',
          'isPrimary': false,
        });
      }

      final hasPrimary = merged.any((row) => row['isPrimary'] == true);
      if (!hasPrimary && merged.isNotEmpty) {
        merged[0] = {
          ...merged[0],
          'isPrimary': true,
        };
      }

      final payload = <String, dynamic>{'ibans': merged};
      Map<String, dynamic>? primary;
      for (final row in merged) {
        if (row['isPrimary'] == true) {
          primary = row;
          break;
        }
      }
      primary ??= merged.isNotEmpty ? merged.first : null;

      if (primary != null) {
        final primaryIban = primary['iban']?.toString().trim() ?? '';
        final primaryBankName = primary['bankName']?.toString().trim() ?? '';
        final primaryAccountName =
            primary['bankAccountName']?.toString().trim() ?? '';

        if (primaryIban.isNotEmpty) {
          payload['iban'] = primaryIban;
        }
        if (primaryBankName.isNotEmpty) {
          payload['bankName'] = primaryBankName;
        }
        if (primaryAccountName.isNotEmpty) {
          payload['bankAccountName'] = primaryAccountName;
        }
      }

      final response = await _client
          .from('private_users')
          .update(payload)
          .eq('id', privateUserId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error upserting ibans JSON: $e');
      rethrow;
    }
  }
}
