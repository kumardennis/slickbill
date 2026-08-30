import 'package:intl/intl.dart';

enum InvoiceStatusFilter { all, unpaid, processing, paid }

class InvoiceListQuery {
  final DateTime month;
  final InvoiceStatusFilter status;

  /// When true: ignore month and return every matching invoice for [status].
  final bool allTime;

  InvoiceListQuery({
    required this.month,
    required this.status,
    this.allTime = false,
  });

  DateTime get monthStart => DateTime(month.year, month.month, 1);

  DateTime get nextMonthStart => DateTime(month.year, month.month + 1, 1);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  /// Month filter is on when not in all-time mode.
  bool get monthFilterActive => !allTime;

  bool get ignoresMonth => allTime;

  String get monthLabel => DateFormat.yMMMM().format(monthStart);

  String get periodLabelKey {
    if (!ignoresMonth) return '';
    switch (status) {
      case InvoiceStatusFilter.unpaid:
        return 'lbl_AllUnpaid';
      case InvoiceStatusFilter.processing:
        return 'lbl_AllProcessing';
      case InvoiceStatusFilter.paid:
        return 'lbl_AllPaid';
      case InvoiceStatusFilter.all:
        return 'lbl_AllTime';
    }
  }

  String get emptyListLabelKey {
    if (ignoresMonth) {
      switch (status) {
        case InvoiceStatusFilter.unpaid:
          return 'lbl_NoUnpaidInvoices';
        case InvoiceStatusFilter.processing:
          return 'lbl_NoProcessingInvoices';
        case InvoiceStatusFilter.paid:
          return 'lbl_NoPaidInvoices';
        case InvoiceStatusFilter.all:
          return 'lbl_NoInvoices';
      }
    }
    if (status == InvoiceStatusFilter.unpaid) {
      return 'lbl_NoUnpaidInMonth';
    }
    if (status == InvoiceStatusFilter.processing) {
      return 'lbl_NoProcessingInMonth';
    }
    return 'lbl_NoInvoicesInMonth';
  }

  bool get emptyListNeedsMonth =>
      emptyListLabelKey == 'lbl_NoInvoicesInMonth' ||
      emptyListLabelKey == 'lbl_NoUnpaidInMonth' ||
      emptyListLabelKey == 'lbl_NoProcessingInMonth';

  String get monthSlug =>
      ignoresMonth ? 'all' : DateFormat('yyyy-MM').format(monthStart);

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

  InvoiceListQuery get previousMonth => InvoiceListQuery(
        month: DateTime(month.year, month.month - 1),
        status: status,
        allTime: false,
      );

  InvoiceListQuery? get nextMonth {
    if (isCurrentMonth) return null;
    return InvoiceListQuery(
      month: DateTime(month.year, month.month + 1),
      status: status,
      allTime: false,
    );
  }

  /// @deprecated Use [previousMonth] — kept for call sites during transition.
  InvoiceListQuery get previousPeriod => previousMonth;

  /// @deprecated Use [nextMonth].
  InvoiceListQuery? get nextPeriod => nextMonth;

  InvoiceListQuery copyWith({
    DateTime? month,
    InvoiceStatusFilter? status,
    bool? allTime,
  }) {
    return InvoiceListQuery(
      month: month ?? this.month,
      status: status ?? this.status,
      allTime: allTime ?? this.allTime,
    );
  }

  Map<String, dynamic> toRequestBody() {
    if (ignoresMonth) {
      switch (status) {
        case InvoiceStatusFilter.all:
          return {'allTime': true};
        case InvoiceStatusFilter.unpaid:
          return {'status': 'UNPAID', 'allTime': true};
        case InvoiceStatusFilter.processing:
          return {'status': 'PROCESSING', 'allTime': true};
        case InvoiceStatusFilter.paid:
          return {'status': 'PAID', 'allTime': true};
      }
    }

    switch (status) {
      case InvoiceStatusFilter.all:
        return {
          'matchAnyDate': true,
          'createdFrom': createdFrom,
          'createdTo': createdTo,
        };
      case InvoiceStatusFilter.unpaid:
        return {
          'status': 'UNPAID',
          'matchAnyDate': true,
          'createdFrom': createdFrom,
          'createdTo': createdTo,
        };
      case InvoiceStatusFilter.processing:
        return {
          'status': 'PROCESSING',
          'matchAnyDate': true,
          'createdFrom': createdFrom,
          'createdTo': createdTo,
        };
      case InvoiceStatusFilter.paid:
        return {
          'status': 'PAID',
          'paidOnDateRange': paidOnDateRange,
        };
    }
  }

  bool inSelectedMonth(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;

    final parsed = DateTime.tryParse(raw.trim());
    if (parsed != null) {
      final local = parsed.toLocal();
      return local.year == month.year && local.month == month.month;
    }

    if (raw.length < 10) return false;
    final ymd = raw.substring(0, 10);
    return ymd.compareTo(createdFrom) >= 0 && ymd.compareTo(createdTo) < 0;
  }

  bool matches({
    required String status,
    required String createdAt,
    String? paidOnDate,
    String? deadline,
  }) {
    final normalized = status.trim().toUpperCase();
    final inMonth = inSelectedMonth(createdAt) ||
        inSelectedMonth(deadline) ||
        inSelectedMonth(paidOnDate);

    switch (this.status) {
      case InvoiceStatusFilter.all:
        if (ignoresMonth) return true;
        return inMonth;
      case InvoiceStatusFilter.unpaid:
        if (normalized != 'UNPAID') return false;
        if (ignoresMonth) return true;
        return inSelectedMonth(createdAt) || inSelectedMonth(deadline);
      case InvoiceStatusFilter.processing:
        if (normalized != 'PROCESSING' && normalized != 'PENDING') {
          return false;
        }
        if (ignoresMonth) return true;
        return inSelectedMonth(createdAt) || inSelectedMonth(deadline);
      case InvoiceStatusFilter.paid:
        if (normalized != 'PAID') return false;
        if (ignoresMonth) return true;
        return inSelectedMonth(paidOnDate);
    }
  }
}

DateTime currentInvoiceMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}
