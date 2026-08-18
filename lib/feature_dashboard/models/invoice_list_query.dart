import 'package:intl/intl.dart';

enum InvoiceStatusFilter { all, unpaid, processing, paid }

class InvoiceListQuery {
  final DateTime month;
  final InvoiceStatusFilter status;

  InvoiceListQuery({
    required this.month,
    required this.status,
  });

  DateTime get monthStart => DateTime(month.year, month.month, 1);

  DateTime get nextMonthStart => DateTime(month.year, month.month + 1, 1);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  String get monthLabel => DateFormat.yMMMM().format(monthStart);

  String get monthSlug => DateFormat('yyyy-MM').format(monthStart);

  String get statusSlug {
    switch (status) {
      case InvoiceStatusFilter.all:
        return 'all';
      case InvoiceStatusFilter.unpaid:
        return 'unpaid';
      case InvoiceStatusFilter.processing:
        return 'processing';
      case InvoiceStatusFilter.paid:
        return 'paid';
    }
  }

  String get createdFrom => DateFormat('yyyy-MM-dd').format(monthStart);

  String get createdTo => DateFormat('yyyy-MM-dd').format(nextMonthStart);

  List<String> get paidOnDateRange {
    final lastDay = DateTime(month.year, month.month + 1, 0);
    return [
      DateFormat('yyyy-MM-dd').format(monthStart),
      DateFormat('yyyy-MM-dd').format(lastDay),
    ];
  }

  InvoiceListQuery get previousMonth {
    return InvoiceListQuery(
      month: DateTime(month.year, month.month - 1),
      status: status,
    );
  }

  InvoiceListQuery? get nextMonth {
    if (isCurrentMonth) return null;
    return InvoiceListQuery(
      month: DateTime(month.year, month.month + 1),
      status: status,
    );
  }

  InvoiceListQuery copyWith({
    DateTime? month,
    InvoiceStatusFilter? status,
  }) {
    return InvoiceListQuery(
      month: month ?? this.month,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toRequestBody() {
    switch (status) {
      case InvoiceStatusFilter.all:
        return {
          'createdFrom': createdFrom,
          'createdTo': createdTo,
          'includeOpen': true,
        };
      case InvoiceStatusFilter.unpaid:
        return {'status': 'UNPAID'};
      case InvoiceStatusFilter.processing:
        return {'status': 'PROCESSING'};
      case InvoiceStatusFilter.paid:
        return {
          'status': 'PAID',
          'paidOnDateRange': paidOnDateRange,
        };
    }
  }

  bool matches({
    required String status,
    required String createdAt,
    String? paidOnDate,
  }) {
    final normalized = status.trim().toUpperCase();
    final isOpen = normalized == 'UNPAID' ||
        normalized == 'PROCESSING' ||
        normalized == 'PENDING';

    bool inSelectedMonth(String? raw) {
      if (raw == null || raw.length < 10) return false;
      final ymd = raw.substring(0, 10);
      return ymd.compareTo(createdFrom) >= 0 && ymd.compareTo(createdTo) < 0;
    }

    switch (this.status) {
      case InvoiceStatusFilter.all:
        return inSelectedMonth(createdAt) || isOpen;
      case InvoiceStatusFilter.unpaid:
        return normalized == 'UNPAID';
      case InvoiceStatusFilter.processing:
        return normalized == 'PROCESSING';
      case InvoiceStatusFilter.paid:
        return normalized == 'PAID' && inSelectedMonth(paidOnDate);
    }
  }
}

DateTime currentInvoiceMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}
