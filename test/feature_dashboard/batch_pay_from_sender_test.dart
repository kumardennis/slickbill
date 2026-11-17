import 'package:flutter_test/flutter_test.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/batch_pay_from_sender.dart';

Map<String, dynamic> _invoiceJson({
  required int id,
  required String status,
  required double amount,
  int senderPrivateUserId = 7,
  String senderIban = 'EE38 2200 2210 2014 5685',
  String createdAt = '2026-09-01T10:00:00Z',
  String description = 'Weekly fee',
}) {
  return {
    'id': id,
    'created_at': createdAt,
    'senderId': 1,
    'receiverId': 2,
    'status': status,
    'amount': amount,
    'description': description,
    'senderName': 'Gym',
    'senderPrivateUserId': senderPrivateUserId,
    'senderIban': senderIban,
    'deadline': '2026-09-10',
    'invoiceNo': '$id',
    'isSeen': true,
    'receivers': {
      'id': 2,
      'privateUserId': 2,
      'private_users': {
        'id': 2,
        'firstName': 'Ada',
        'lastName': 'L',
        'userId': 2,
        'iban': '',
        'bankAccountName': '',
      },
    },
  };
}

InvoiceModel _invoice({
  required int id,
  required String status,
  required double amount,
  int senderPrivateUserId = 7,
  String senderIban = 'EE38 2200 2210 2014 5685',
  String createdAt = '2026-09-01T10:00:00Z',
}) {
  return InvoiceModel.fromJson(_invoiceJson(
    id: id,
    status: status,
    amount: amount,
    senderPrivateUserId: senderPrivateUserId,
    senderIban: senderIban,
    createdAt: createdAt,
  ));
}

void main() {
  group('BatchPayFromSender', () {
    test('offers picker for unpaid bills from a known sender', () {
      expect(BatchPayFromSender.canOfferPicker(_invoice(
        id: 1,
        status: 'UNPAID',
        amount: 20,
      )), isTrue);
      expect(BatchPayFromSender.canOfferPicker(_invoice(
        id: 2,
        status: 'PAID',
        amount: 20,
      )), isFalse);
      expect(BatchPayFromSender.canOfferPicker(_invoice(
        id: 3,
        status: 'UNPAID',
        amount: 20,
        senderIban: '',
      )), isFalse);
    });

    test('selectionError returns locale keys', () {
      expect(
        BatchPayFromSender.selectionError([]),
        'err_BatchSelectAtLeastOne',
      );
      expect(
        BatchPayFromSender.selectionError([
          _invoice(id: 1, status: 'UNPAID', amount: 10),
          _invoice(id: 2, status: 'PAID', amount: 10),
        ]),
        'err_BatchOnlyUnpaid',
      );
      expect(
        BatchPayFromSender.selectionError([
          _invoice(id: 1, status: 'UNPAID', amount: 10),
          _invoice(
            id: 2,
            status: 'UNPAID',
            amount: 10,
            senderPrivateUserId: 8,
          ),
        ]),
        'err_BatchSameSenderIban',
      );
    });

    test('keeps same-sender same-IBAN unpaid bills and drops the rest', () {
      final seed = _invoice(id: 10, status: 'UNPAID', amount: 20);
      final eligible = BatchPayFromSender.eligibleWithSeed(
        seed: seed,
        candidates: [
          seed,
          _invoice(
            id: 11,
            status: 'UNPAID',
            amount: 20,
            createdAt: '2026-09-08T10:00:00Z',
          ),
          _invoice(id: 12, status: 'PAID', amount: 20),
          _invoice(
            id: 13,
            status: 'UNPAID',
            amount: 20,
            senderPrivateUserId: 99,
          ),
          _invoice(
            id: 14,
            status: 'UNPAID',
            amount: 20,
            senderIban: 'EE382200000000000001',
          ),
        ],
      );

      expect(eligible.map((invoice) => invoice.id), [11, 10]);
      expect(BatchPayFromSender.sum(eligible), 40);
    });

    test('rejects mixed senders in a selection', () {
      expect(
        BatchPayFromSender.selectionError([
          _invoice(id: 1, status: 'UNPAID', amount: 10),
          _invoice(
            id: 2,
            status: 'UNPAID',
            amount: 10,
            senderPrivateUserId: 8,
          ),
        ]),
        isNotNull,
      );
      expect(
        BatchPayFromSender.selectionError([
          _invoice(id: 1, status: 'UNPAID', amount: 10),
          _invoice(id: 2, status: 'UNPAID', amount: 15),
        ]),
        isNull,
      );
    });
  });
}
