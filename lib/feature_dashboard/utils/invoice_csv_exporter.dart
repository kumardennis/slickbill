import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/invoice_csv_local_save_io.dart'
    if (dart.library.html) 'invoice_csv_local_save_web.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';

class InvoiceCsvExporter {
  static final NumberFormat _amount = NumberFormat('0.00');

  static Future<void> exportSent({
    required List<InvoiceModel> invoices,
    required InvoiceListQuery query,
  }) {
    return _save(
      filename: 'slickbills-sent-${query.monthSlug}-${query.statusSlug}.csv',
      rows: [
        [
          'Date',
          'Invoice no',
          'Payer',
          'Amount',
          'Currency',
          'Status',
          'Reference',
          'Description',
          'Due',
          'Paid on',
        ],
        ...invoices.map(
          (invoice) => [
            _date(invoice.createdAt),
            invoice.invoiceNo,
            invoice.displayReceiverName,
            _amount.format(invoice.amount),
            'EUR',
            invoice.status.trim().toUpperCase(),
            invoice.referenceNo ?? '',
            invoice.description,
            _date(invoice.deadline),
            _date(invoice.paidOnDate),
          ],
        ),
      ],
    );
  }

  static Future<void> exportReceived({
    required List<InvoiceModel> invoices,
    required InvoiceListQuery query,
  }) {
    return _save(
      filename:
          'slickbills-received-${query.monthSlug}-${query.statusSlug}.csv',
      rows: [
        [
          'Date',
          'Invoice no',
          'From',
          'Amount',
          'Currency',
          'Status',
          'Reference',
          'Description',
          'Due',
          'Paid on',
        ],
        ...invoices.map(
          (invoice) => [
            _date(invoice.createdAt),
            invoice.invoiceNo,
            invoice.displaySenderName,
            _amount.format(invoice.amount),
            'EUR',
            invoice.status.trim().toUpperCase(),
            invoice.referenceNo ?? '',
            invoice.description,
            _date(invoice.deadline),
            _date(invoice.paidOnDate),
          ],
        ),
      ],
    );
  }

  static Future<void> exportPublic({
    required List<PublicInvoiceModel> invoices,
    required InvoiceListQuery query,
  }) {
    return _save(
      filename: 'slickbills-links-${query.monthSlug}-${query.statusSlug}.csv',
      rows: [
        [
          'Date',
          'Amount',
          'Currency',
          'Status',
          'Reference',
          'Description',
          'Due',
          'Paid on',
          'Views',
          'Claims',
          'Link',
        ],
        ...invoices.map((invoice) {
          final token = invoice.publicToken?.trim() ?? '';
          return [
            DateFormat('yyyy-MM-dd').format(invoice.createdAt),
            _amount.format(invoice.amount),
            'EUR',
            invoice.status.trim().toUpperCase(),
            invoice.referenceNo ?? '',
            invoice.description ?? '',
            _date(invoice.deadline),
            _date(invoice.paidOnDate),
            '${invoice.viewCount}',
            '${invoice.claimCount}',
            token.isEmpty ? '' : 'https://app.slickbills.com/bill/$token',
          ];
        }),
      ],
    );
  }

  static Future<void> _save({
    required String filename,
    required List<List<String>> rows,
  }) async {
    if (rows.length <= 1) {
      Get.snackbar('Oops..', 'inf_CsvNothingToExport'.tr);
      return;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(_encode(rows)));
      await saveCsvLocally(bytes: bytes, filename: filename);
      Get.snackbar('btn_ExportCsv'.tr, 'inf_CsvSaved'.trParams({
        'file': filename,
      }));
    } catch (err) {
      print(err);
      Get.snackbar('Oops..', 'inf_CsvExportFailed'.tr);
    }
  }

  static String _encode(List<List<String>> rows) {
    final buffer = StringBuffer('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(';'));
    }
    return buffer.toString();
  }

  static String _escape(String value) {
    final cleaned = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (cleaned.contains(';') ||
        cleaned.contains('"') ||
        cleaned.contains('\n')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  static String _date(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  }
}
