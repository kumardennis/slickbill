import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/core/services/view_tracking_service.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_dashboard/models/public_invoice_claim_model.dart';
import 'package:slickbill/feature_dashboard/repos/digital_invoices_repo.dart';

class DigitalInvoiceController extends GetxController {
  final DigitalInvoiceRepository _repository = DigitalInvoiceRepository();

  final ViewTrackingService _viewTracker = ViewTrackingService();

  // ==================== OBSERVABLES ====================

  // Private invoices
  final RxList<InvoiceModel> sentInvoices = <InvoiceModel>[].obs;
  final RxList<InvoiceModel> receivedInvoices = <InvoiceModel>[].obs;
  final RxList<InvoiceModel> allInvoices = <InvoiceModel>[].obs;

  // Public invoices
  final RxList<PublicInvoiceModel> publicInvoices = <PublicInvoiceModel>[].obs;
  final RxList<PublicInvoiceModel> claimedPublicInvoices =
      <PublicInvoiceModel>[].obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isCreatingPublicInvoice = false.obs;
  final RxBool isClaiming = false.obs;

  // Selected invoice for details view
  final Rx<InvoiceModel?> selectedInvoice = Rx<InvoiceModel?>(null);
  final Rx<PublicInvoiceModel?> selectedPublicInvoice =
      Rx<PublicInvoiceModel?>(null);

  // ==================== PRIVATE INVOICE METHODS ====================

  /// Load all invoices for current user
  Future<void> loadAllInvoices(int privateUserId) async {
    try {
      isLoading.value = true;
      final invoices = await _repository.getAllInvoices(privateUserId);
      allInvoices.value = invoices;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load invoices: $e');
      print('Error loading all invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load sent invoices
  Future<void> loadSentInvoices(int privateUserId) async {
    try {
      isLoading.value = true;
      final invoices = await _repository.getSentInvoices(privateUserId);
      sentInvoices.value = invoices;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load sent invoices: $e');
      print('Error loading sent invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load received invoices
  Future<void> loadReceivedInvoices(int privateUserId) async {
    try {
      isLoading.value = true;
      final invoices = await _repository.getReceivedInvoices(privateUserId);
      receivedInvoices.value = invoices;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load received invoices: $e');
      print('Error loading received invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load both sent and received invoices
  Future<void> loadUserInvoices(int privateUserId) async {
    await Future.wait([
      loadSentInvoices(privateUserId),
      loadReceivedInvoices(privateUserId),
    ]);
  }

  /// Get invoice by ID
  Future<InvoiceModel?> getInvoiceById(int invoiceId) async {
    try {
      final invoice = await _repository.getInvoiceById(invoiceId);
      if (invoice != null) {
        selectedInvoice.value = invoice;
      }
      return invoice;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load invoice: $e');
      print('Error loading invoice: $e');
      return null;
    }
  }

  /// Update the transaction hash for an invoice
  Future<InvoiceModel?> updateTxHashForInvoice(
      int invoiceId, String txHash) async {
    try {
      isLoading.value = true;
      final updatedInvoice =
          await _repository.updateTxHashForInvoiceById(invoiceId, txHash);
      if (updatedInvoice != null) {
        Get.snackbar('Success', 'Transaction hash updated successfully!');
        return updatedInvoice;
      }
      debugPrint('Error: Failed to update transaction hash');
      return null;
    } catch (e) {
      debugPrint('Error updating transaction hash: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a new private invoice
  Future<InvoiceModel?> createPrivateInvoice(
      Map<String, dynamic> invoiceData) async {
    try {
      isLoading.value = true;
      final invoice = await _repository.createInvoice(invoiceData);
      sentInvoices.insert(0, invoice);
      allInvoices.insert(0, invoice);
      Get.snackbar('Success', 'Invoice created successfully!');
      return invoice;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create invoice: $e');
      print('Error creating invoice: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mark invoice as paid

  /// Delete invoice
  Future<void> deleteInvoice(int invoiceId) async {
    try {
      await _repository.deleteInvoice(invoiceId);
      sentInvoices.removeWhere((inv) => inv.id == invoiceId);
      receivedInvoices.removeWhere((inv) => inv.id == invoiceId);
      allInvoices.removeWhere((inv) => inv.id == invoiceId);
      Get.snackbar('Success', 'Invoice deleted');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete invoice: $e');
      print('Error deleting invoice: $e');
    }
  }

  // ==================== PUBLIC INVOICE METHODS ====================

  /// Create a public shareable invoice
  Future<PublicInvoiceModel?> createPublicInvoice({
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
    try {
      isCreatingPublicInvoice.value = true;
      final invoice = await _repository.createPublicInvoice(
        status: status,
        amount: amount,
        data: data,
        description: description,
        rawInvoiceId: rawInvoiceId,
        senderName: senderName,
        deadline: deadline,
        invoiceNo: invoiceNo,
        originalInvoiceNo: originalInvoiceNo,
        referenceNo: referenceNo,
        senderIban: senderIban,
        category: category,
        privateGroupId: privateGroupId,
        receiverPrivateUserId: receiverPrivateUserId,
        senderPrivateUserId: senderPrivateUserId,
      );

      publicInvoices.insert(0, invoice);
      Get.snackbar('Success', 'Public invoice created!');
      return invoice;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create public invoice: $e');
      print('Error creating public invoice: $e');
      return null;
    } finally {
      isCreatingPublicInvoice.value = false;
    }
  }

  /// Load public invoices created by user
  Future<void> loadPublicInvoices(int senderId) async {
    try {
      isLoading.value = true;
      final invoices = await _repository.getPublicInvoicesBySender(senderId);
      publicInvoices.value = invoices;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load public invoices: $e');
      print('Error loading public invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get public invoice by token (for viewing)
  Future<PublicInvoiceModel?> getPublicInvoiceByToken(String token) async {
    try {
      final invoice = await _repository.getPublicInvoiceByToken(token);
      if (invoice != null) {
        selectedPublicInvoice.value = invoice;
      }
      return invoice;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load public invoice: $e');
      print('Error loading public invoice: $e');
      return null;
    }
  }

  /// Claim a public invoice
  Future<InvoiceModel?> claimPublicInvoice({
    required String token,
    required int claimerUserId,
    required int claimerPrivateUserId,
  }) async {
    try {
      isClaiming.value = true;

      // Check if already claimed
      final publicInvoice = selectedPublicInvoice.value;
      if (publicInvoice != null) {
        final existingClaim = await _repository.getUserClaimForPublicInvoice(
          publicInvoiceId: publicInvoice.id,
          claimerUserId: claimerUserId,
        );

        if (existingClaim != null) {
          Get.snackbar(
            'Already Claimed',
            'You already have this bill in your account',
          );
          // Load the existing invoice
          final existingInvoice =
              await _repository.getInvoiceById(existingClaim.digitalInvoiceId!);
          return existingInvoice;
        }
      }

      // Claim the invoice (creates sender, receiver, digital_invoice)
      final invoice = await _repository.claimPublicInvoice(
        token: token,
        claimerPrivateUserId: claimerPrivateUserId,
      );

      // Add to local lists
      receivedInvoices.insert(0, invoice);
      allInvoices.insert(0, invoice);

      // Reload to get fresh data with relationships
      await loadReceivedInvoices(claimerPrivateUserId);

      Get.snackbar('Success', 'Invoice added to your account!');

      return invoice;
    } catch (e) {
      Get.snackbar('Error', 'Failed to claim invoice: $e');
      print('Error claiming invoice: $e');
      return null;
    } finally {
      isClaiming.value = false;
    }
  }

  /// Load public invoices claimed by user
  Future<void> loadClaimedPublicInvoices(int claimerUserId) async {
    try {
      isLoading.value = true;
      final invoices =
          await _repository.getClaimedPublicInvoices(claimerUserId);
      claimedPublicInvoices.value = invoices;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load claimed invoices: $e');
      print('Error loading claimed invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get claims for a public invoice (for analytics)
  Future<List<PublicInvoiceClaimModel>> getClaimsForPublicInvoice(
      int publicInvoiceId) async {
    try {
      return await _repository.getClaimsForPublicInvoice(publicInvoiceId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load claims: $e');
      print('Error loading claims: $e');
      return [];
    }
  }

  /// Get claimers with details (for analytics)
  Future<List<Map<String, dynamic>>> getClaimersForPublicInvoice(
      int publicInvoiceId) async {
    try {
      return await _repository.getClaimersForPublicInvoice(publicInvoiceId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load claimers: $e');
      print('Error loading claimers: $e');
      return [];
    }
  }

  Future<void> trackPublicInvoiceView(String publicToken) async {
    try {
      // Check if should track (not viewed in last 30 days)
      final shouldTrack = await _viewTracker.shouldTrackView(publicToken);

      if (!shouldTrack) {
        print('Skipping view tracking - already counted');
        return;
      }

      // Increment in database
      await _repository.incrementPublicInvoiceViewCount(publicToken);

      // Mark as viewed locally
      await _viewTracker.markAsViewed(publicToken);

      print('✅ View tracked successfully');
    } catch (e) {
      print('Error tracking view: $e');
      // Silent fail - don't break UX
    }
  }

  // ==================== HELPER METHODS ====================

  /// Refresh all data for a user
  Future<void> refreshAllData(int privateUserId, int senderId) async {
    await Future.wait([
      loadUserInvoices(privateUserId),
      loadPublicInvoices(senderId),
      loadClaimedPublicInvoices(senderId),
    ]);
  }

  /// Clear all data (on logout)
  void clearAllData() {
    sentInvoices.clear();
    receivedInvoices.clear();
    allInvoices.clear();
    publicInvoices.clear();
    claimedPublicInvoices.clear();
    selectedInvoice.value = null;
    selectedPublicInvoice.value = null;
  }
}
