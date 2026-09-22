import 'package:flutter_test/flutter_test.dart';
import 'package:slickbill/shared_utils/epc_qr.dart';

void main() {
  group('EpcQrPayload', () {
    test('builds BCD 002 with empty structured remittance', () {
      final payload = EpcQrPayload.build(
        beneficiaryName: 'Ada Lovelace',
        iban: 'EE38 2200 2210 2014 5685',
        amountEur: 12.5,
        paymentMemo: '[sb:42]',
        description: 'Lunch',
      );

      expect(payload, isNotNull);
      final lines = payload!.split('\n');
      expect(lines[0], 'BCD');
      expect(lines[1], '002');
      expect(lines[3], 'SCT');
      expect(lines[4], isEmpty);
      expect(lines[5], 'Ada Lovelace');
      expect(lines[6], 'EE382200221020145685');
      expect(lines[7], 'EUR12.50');
      expect(lines[8], isEmpty);
      expect(lines[9], isEmpty);
      expect(lines[10], 'Lunch [sb:42]');
      expect(EpcQrPayload.structuredRemittanceOf(payload), isEmpty);
    });

    test('never copies an invoice number into structured remittance', () {
      final payload = EpcQrPayload.build(
        beneficiaryName: 'Cafe',
        iban: 'EE382200221020145685',
        amountEur: 1,
        paymentMemo: '[sb:99]',
        description: 'INV-2026-001',
      )!;

      expect(EpcQrPayload.structuredRemittanceOf(payload), isEmpty);
      expect(
        EpcQrPayload.unstructuredRemittanceOf(payload),
        contains('[sb:99]'),
      );
      expect(payload.contains('RF'), isFalse);
    });

    test('keeps [sb:id] when description is long', () {
      final payload = EpcQrPayload.build(
        beneficiaryName: 'Cafe',
        iban: 'EE382200221020145685',
        amountEur: 3,
        paymentMemo: '[sb:7]',
        description: 'x' * 200,
      )!;

      final remittance = EpcQrPayload.unstructuredRemittanceOf(payload);
      expect(remittance.endsWith('[sb:7]'), isTrue);
      expect(remittance.length, lessThanOrEqualTo(140));
    });

    test('returns null without a real IBAN or name', () {
      expect(
        EpcQrPayload.build(
          beneficiaryName: 'Ada',
          iban: '-',
          amountEur: 10,
          paymentMemo: '[sb:1]',
        ),
        isNull,
      );
      expect(
        EpcQrPayload.build(
          beneficiaryName: '  ',
          iban: 'EE382200221020145685',
          amountEur: 10,
        ),
        isNull,
      );
      expect(
        EpcQrPayload.build(
          beneficiaryName: 'Ada',
          iban: 'EE382200221020145685',
          amountEur: 0,
        ),
        isNull,
      );
    });
  });
}
