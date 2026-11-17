import 'package:flutter_test/flutter_test.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';

void main() {
  test('keeps only the IBAN issued for the current wallet', () {
    final filtered = MoneriumService.filterIbansForWallet(
      ibans: [
        {'iban': 'EE111', 'address': '0xAAAAaaAAaaaaAAAAaaaaAAAAaaaaAAAAaaaaAAAa'},
        {'iban': 'EE222', 'address': '0xBBBBbbbbBBBBbbbbBBBBbbbbBBBBbbbbBBBBbbbb'},
      ],
      walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    expect(filtered, hasLength(1));
    expect(filtered.first['iban'], 'EE222');
  });

  test('does not copy an unscoped IBAN onto the signed-in user', () {
    expect(
      MoneriumService.filterIbansForWallet(
        ibans: [
          {'iban': 'EE111'},
        ],
        walletAddress: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      isEmpty,
    );
  });

  test('returns nothing when the current wallet is missing', () {
    expect(
      MoneriumService.filterIbansForWallet(
        ibans: [
          {
            'iban': 'EE111',
            'address': '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        ],
        walletAddress: '',
      ),
      isEmpty,
    );
  });
}
