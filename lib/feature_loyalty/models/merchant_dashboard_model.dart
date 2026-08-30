class MerchantDashboardModel {
  final int uniqueCustomers;
  final int repeatCustomers;
  final double totalReceivedEur;
  final int regularCustomers;
  final int openSessions;

  const MerchantDashboardModel({
    required this.uniqueCustomers,
    required this.repeatCustomers,
    required this.totalReceivedEur,
    required this.regularCustomers,
    this.openSessions = 0,
  });

  factory MerchantDashboardModel.fromJson(Map<String, dynamic> json) {
    return MerchantDashboardModel(
      uniqueCustomers: (json['uniqueCustomers'] as num?)?.toInt() ?? 0,
      repeatCustomers: (json['repeatCustomers'] as num?)?.toInt() ?? 0,
      totalReceivedEur: (json['totalReceivedEur'] as num?)?.toDouble() ?? 0,
      regularCustomers: (json['regularCustomers'] as num?)?.toInt() ?? 0,
      openSessions: (json['openSessions'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = MerchantDashboardModel(
    uniqueCustomers: 0,
    repeatCustomers: 0,
    totalReceivedEur: 0,
    regularCustomers: 0,
    openSessions: 0,
  );
}
