import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_dashboard/models/public_invoice_claim_model.dart';

class DigitalInvoiceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================== PRIVATE INVOICES ====================

  /// Fetch all invoices for a user (sent + received)
  Future<List<InvoiceModel>> getAllInvoices(int privateUserId) async {
    final response = await _client
        .from('digital_invoices')
        .select()
        .or('senderPrivateUserId.eq.$privateUserId,receiverPrivateUserId.eq.$privateUserId')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => InvoiceModel.fromJson(json))
        .toList();
  }

  /// Fetch invoices sent by user
  Future<List<InvoiceModel>> getSentInvoices(int privateUserId) async {
    final response = await _client
        .from('digital_invoices')
        .select()
        .eq('senderPrivateUserId', privateUserId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => InvoiceModel.fromJson(json))
        .toList();
  }

  /// Fetch invoices received by user
  Future<List<InvoiceModel>> getReceivedInvoices(int privateUserId) async {
    final response = await _client
        .from('digital_invoices')
        .select()
        .eq('receiverPrivateUserId', privateUserId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => InvoiceModel.fromJson(json))
        .toList();
  }

  /// Get single invoice by ID
  Future<InvoiceModel?> getInvoiceById(int invoiceId) async {
    final response = await _client
        .from('digital_invoices')
        .select()
        .eq('id', invoiceId)
        .maybeSingle();

    if (response == null) return null;
    return InvoiceModel.fromJson(response);
  }

  Future<InvoiceModel?> updateTxHashForInvoiceById(
      int invoiceId, String txHash) async {
    final response = await _client
        .from('digital_invoices')
        .update({'txHash': txHash})
        .eq('id', invoiceId)
        .select();

    if (response == null || response.isEmpty) return null;
    return InvoiceModel.fromJson(response.first);
  }

  /// Create a new private invoice
  Future<InvoiceModel> createInvoice(Map<String, dynamic> invoiceData) async {
    final response = await _client
        .from('digital_invoices')
        .insert(invoiceData)
        .select()
        .single();

    return InvoiceModel.fromJson(response);
  }

  /// Update invoice status (e.g., mark as paid)
  Future<void> updateInvoiceStatus(int invoiceId, String status) async {
    await _client
        .from('digital_invoices')
        .update({'status': status}).eq('id', invoiceId);
  }

  /// Delete invoice
  Future<void> deleteInvoice(int invoiceId) async {
    await _client.from('digital_invoices').delete().eq('id', invoiceId);
  }

  // ==================== PUBLIC INVOICES ====================

  /// Create a public (shareable) invoice
  Future<PublicInvoiceModel> createPublicInvoice({
    required String status,
    required double amount,
    Map<String, dynamic>? data,
    String? description,
    int? rawInvoiceId,
    String? senderName,
    DateTime? deadline,
    String? invoiceNo,
    String? originalInvoiceNo,
    String? referenceNo,
    String? senderIban,
    String? category,
    int? privateGroupId,
    int? receiverPrivateUserId,
    int? senderPrivateUserId,
  }) async {
    // Generate unique token (using uuid type from your schema)

    final invoiceData = {
      'status': status,
      'amount': amount,
      'data': data,
      'description': description,
      'rawInvoiceId': rawInvoiceId,
      'senderName': senderName,
      'deadline': deadline?.toIso8601String(),
      'invoiceNo': invoiceNo,
      'originalInvoiceNo': originalInvoiceNo,
      'isSeen': false,
      'referenceNo': referenceNo,
      'paidOnDate': null,
      'senderIban': senderIban,
      'category': category,
      'privateGroupId': privateGroupId,
      'receiverPrivateUserId': receiverPrivateUserId,
      'senderPrivateUserId': senderPrivateUserId,
      'viewCount': 0,
      'claimCount': 0,
    };

    final response = await _client
        .from('public_digital_invoices')
        .insert(invoiceData)
        .select()
        .single();

    return PublicInvoiceModel.fromJson(response);
  }

  /// Get public invoice by token (for guest viewing)
  Future<PublicInvoiceModel?> getPublicInvoiceByToken(String token) async {
    final response = await _client
        .from('public_digital_invoices')
        .select('''
        *,
        sender:private_users!public_digital_invoices_senderPrivateUserId_fkey(*),
        receiver:private_users!public_digital_invoices_receiverPrivateUserId_fkey(*)
      ''')
        .eq('publicToken', token)
        .not('publicToken', 'is', null)
        .maybeSingle();

    if (response == null) return null;

    return PublicInvoiceModel.fromJson(response);
  }

  /// Claim a public invoice (creates sender, receiver, digital_invoice + claim record)
  Future<InvoiceModel> claimPublicInvoice({
    required String token,
    required int claimerPrivateUserId,
  }) async {
    try {
      // Step 1: Fetch public invoice by token
      final publicInvoiceResponse = await _client
          .from('public_digital_invoices')
          .select()
          .eq('publicToken', token)
          .single();

      final publicInvoice = PublicInvoiceModel.fromJson(publicInvoiceResponse);

      // Step 2: Check if already claimed by this user
      final existingClaim = await _client
          .from('public_invoice_claims')
          .select()
          .eq('public_invoice_id', publicInvoice.id)
          .eq('claimed_by_user_id', claimerPrivateUserId)
          .maybeSingle();

      if (existingClaim != null) {
        // Already claimed, return existing invoice
        final existingInvoiceId = existingClaim['digital_invoice_id'];
        final existingInvoice = await getInvoiceById(existingInvoiceId);
        if (existingInvoice != null) {
          throw Exception('You have already claimed this invoice');
        }
      }

      // Step 3: Create sender record (from the original public invoice sender)
      final senderResponse = await _client
          .from('senders')
          .insert({
            'privateUserId': publicInvoice.senderPrivateUserId,
          })
          .select()
          .single();

      final senderId = senderResponse['id'];

      // Step 4: Create receiver record (the person claiming the invoice)
      final receiverResponse = await _client
          .from('receivers')
          .insert({
            'privateUserId': claimerPrivateUserId,
          })
          .select()
          .single();

      final receiverId = receiverResponse['id'];

      // Step 5: Create digital invoice
      final digitalInvoiceResponse =
          await _client.from('digital_invoices').insert({
        'senderId': senderId,
        'receiverId': receiverId,
        'amount': publicInvoice.amount,
        'description': publicInvoice.description,
        'category': publicInvoice.category,
        'status': publicInvoice.status,
        'deadline': publicInvoice.deadline,
        'senderIban': publicInvoice.senderIban,
        'senderName': publicInvoice.senderName,
        'referenceNo': publicInvoice.referenceNo,
        'invoiceNo':
            '${claimerPrivateUserId}${DateTime.now().millisecondsSinceEpoch}',
        'receiverPrivateUserId': claimerPrivateUserId,
        'senderPrivateUserId': publicInvoice.senderPrivateUserId,
        'originalInvoiceNo': publicInvoice.originalInvoiceNo,
        'data': publicInvoice.data,
        'isSeen': false,
      }).select('''
          *,
          senders(*,
            private_users(*)
          ),
          receivers(*,
            private_users(*),
            business_users(*)
          )
        ''').single();

      final digitalInvoice = InvoiceModel.fromJson(digitalInvoiceResponse);

      print('Digital invoice created: ${digitalInvoiceResponse['id']}');

      // Step 6: Create the claim record linking public invoice to digital invoice
      final claimResponse = await _client
          .from('public_invoice_claims')
          .insert({
            'public_invoice_id': publicInvoice.id,
            'digital_invoice_id': digitalInvoice.id,
            'claimed_by_user_id': claimerPrivateUserId,
          })
          .select()
          .single();

      print('Claim record created: ${claimResponse['id']}');

      // Step 7: Increment view count and claim count
      await _client.from('public_digital_invoices').update({
        'viewCount': publicInvoice.viewCount + 1,
        'claimCount': publicInvoice.claimCount + 1,
      }).eq('id', publicInvoice.id);

      print('Invoice claimed successfully: ${digitalInvoice.id}');
      return digitalInvoice;
    } catch (e) {
      print('Error claiming invoice: $e');
      rethrow;
    }
  }

  /// Get all claims for a public invoice (for creator analytics)
  Future<List<PublicInvoiceClaimModel>> getClaimsForPublicInvoice(
      int publicInvoiceId) async {
    final response = await _client
        .from('public_invoice_claims')
        .select()
        .eq('public_invoice_id', publicInvoiceId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PublicInvoiceClaimModel.fromJson(json))
        .toList();
  }

  /// Get all public invoices created by a user (by senderPrivateUserId)
  Future<List<PublicInvoiceModel>> getPublicInvoicesBySender(
      int senderPrivateUserId) async {
    try {
      final response = await _client
          .from('public_digital_invoices')
          .select('''
          *,
          claimed_invoices:public_invoice_claims(
            digital_invoice_id,
            claimed_by_user_id,
            created_at,
            digital_invoices(
              *,
              receivers(
                id,
                privateUserId,
                businessUserId,
                created_at,
                private_users(
                  id,
                  firstName,
                  lastName,
                  bankAccountName,
                  iban
                ),
                business_users(
                  *
                )
              ),
              senders(
                id,
                privateUserId,
                created_at,
                private_users(
                  id,
                  firstName,
                  lastName,
                  bankAccountName,
                  iban
                )
              )
            )
          )
        ''')
          .eq('senderPrivateUserId', senderPrivateUserId)
          .not('publicToken', 'is', null) // Filter out null tokens
          .order('created_at', ascending: false);

      print('Public invoices raw response: $response');

      return (response as List)
          .where((invoice) => invoice['publicToken'] != null) // Extra safety
          .map((invoice) {
        print(
            'Processing invoice: ${invoice['id']}, token: ${invoice['publicToken']}');
        return PublicInvoiceModel.fromJson(invoice);
      }).toList();
    } catch (e, stackTrace) {
      print('Error fetching public invoices by sender: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all public invoices claimed by a user
  Future<List<PublicInvoiceModel>> getClaimedPublicInvoices(
      int claimerUserId) async {
    // First get all claim records for this user
    final claimResponse = await _client
        .from('public_invoice_claims')
        .select('public_invoice_id')
        .eq('claimed_by_user_id', claimerUserId);

    if (claimResponse.isEmpty) return [];

    // Extract public invoice IDs
    final publicInvoiceIds = (claimResponse as List)
        .map((claim) => claim['public_invoice_id'] as int)
        .toList();

    // Fetch the actual public invoices
    final invoicesResponse = await _client
        .from('public_digital_invoices')
        .select()
        .inFilter('id', publicInvoiceIds)
        .order('created_at', ascending: false);

    return (invoicesResponse as List)
        .map((json) => PublicInvoiceModel.fromJson(json))
        .toList();
  }

  /// Get user's claims with full invoice details
  Future<List<Map<String, dynamic>>> getUserClaimsWithInvoices(
      int claimerUserId) async {
    final response = await _client
        .from('public_invoice_claims')
        .select('''
          *,
          public_digital_invoices (*),
          digital_invoices (*)
        ''')
        .eq('claimed_by_user_id', claimerUserId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Check if user has already claimed a specific public invoice
  Future<PublicInvoiceClaimModel?> getUserClaimForPublicInvoice({
    required int publicInvoiceId,
    required int claimerUserId,
  }) async {
    final response = await _client
        .from('public_invoice_claims')
        .select()
        .eq('public_invoice_id', publicInvoiceId)
        .eq('claimed_by_user_id', claimerUserId)
        .maybeSingle();

    if (response == null) return null;
    return PublicInvoiceClaimModel.fromJson(response);
  }

  /// Get all users who claimed a specific public invoice (for creator analytics)
  Future<List<Map<String, dynamic>>> getClaimersForPublicInvoice(
      int publicInvoiceId) async {
    final response = await _client
        .from('public_invoice_claims')
        .select('''
          *,
          users:claimed_by_user_id (
            id,
            username,
            email
          )
        ''')
        .eq('public_invoice_id', publicInvoiceId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> incrementPublicInvoiceViewCount(String publicToken) async {
    try {
      // ✅ First fetch current value, then increment
      final response = await _client
          .from('public_digital_invoices')
          .select('viewCount')
          .eq('publicToken', publicToken)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invoice not found');
      }

      final currentCount = (response['viewCount'] as int?) ?? 0;

      await _client.from('public_digital_invoices').update(
          {'viewCount': currentCount + 1}).eq('publicToken', publicToken);

      print('✅ View count incremented in DB for: $publicToken');
    } catch (e) {
      print('❌ Error incrementing view count: $e');
      rethrow;
    }
  }

  // ==================== HELPERS ====================

  /// Generate a random URL-safe token
  String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(10, (i) => chars[(random + i) % chars.length]).join();
  }
}
