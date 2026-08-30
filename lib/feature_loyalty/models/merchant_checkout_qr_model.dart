class MerchantCheckoutQrModel {
  final String checkoutToken;
  final String checkoutUrl;

  const MerchantCheckoutQrModel({
    required this.checkoutToken,
    required this.checkoutUrl,
  });

  factory MerchantCheckoutQrModel.fromJson(Map<String, dynamic> json) {
    return MerchantCheckoutQrModel(
      checkoutToken: (json['checkoutToken'] as String?)?.trim() ?? '',
      checkoutUrl: (json['checkoutUrl'] as String?)?.trim() ?? '',
    );
  }
}
