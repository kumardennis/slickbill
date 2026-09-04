import 'package:intl/intl.dart';

enum InvoiceStatusFilter { all, unpaid, processing, paid }

/// How a month folder is chosen for the invoice list.
enum InvoiceMonthBasis {
  /// Sent tab: invoices created/sent in the selected month.
  created,

  /// Received / stats: paid by paid-on date; open by created or due date.
  activity,
}

class InvoiceListQuery {
  final DateTime month;
  final InvoiceStatusFilter status;

  /// When true: ignore month and return every matching invoice for [status].
  final bool allTime;

  final InvoiceMonthBasis monthBasis;

  InvoiceListQuery({
    required this.month,
    required this.status,
    this.allTime = false,
    this.monthBasis = InvoiceMonthBasis.activity,
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

  String get paidOverviewLabelKey {
    if (allTime) return 'lbl_PaidAllTime';
    if (isCurrentMonth) return 'lbl_PaidThisMonth';
    return 'lbl_PaidInMonth';
  }

  String get receivedOverviewLabelKey {
    if (allTime) return 'lbl_ReceivedAllTime';
    if (isCurrentMonth) return 'lbl_ReceivedThisMonth';
    return 'lbl_ReceivedInMonth';
  }

  bool get overviewLabelNeedsMonth => !allTime && !isCurrentMonth;

  InvoiceListQuery get periodOnly => InvoiceListQuery(
        month: month,
        status: InvoiceStatusFilter.all,
        allTime: allTime,
        monthBasis: monthBasis,
      );

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
        monthBasis: monthBasis,
      );

  InvoiceListQuery? get nextMonth {
    if (isCurrentMonth) return null;
    return InvoiceListQuery(
      month: DateTime(month.year, month.month + 1),
      status: status,
      allTime: false,
      monthBasis: monthBasis,
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
    InvoiceMonthBasis? monthBasis,
  }) {
    return InvoiceListQuery(
      month: month ?? this.month,
      status: status ?? this.status,
      allTime: allTime ?? this.allTime,
      monthBasis: monthBasis ?? this.monthBasis,
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

    if (monthBasis == InvoiceMonthBasis.created) {
      final dates = {
        'createdFrom': createdFrom,
        'createdTo': createdTo,
      };
      switch (status) {
        case InvoiceStatusFilter.all:
          return dates;
        case InvoiceStatusFilter.unpaid:
          return {'status': 'UNPAID', ...dates};
        case InvoiceStatusFilter.processing:
          return {'status': 'PROCESSING', ...dates};
        case InvoiceStatusFilter.paid:
          return {'status': 'PAID', ...dates};
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

  bool _statusMatches(String normalized) {
    switch (status) {
      case InvoiceStatusFilter.all:
        return true;
      case InvoiceStatusFilter.unpaid:
        return normalized == 'UNPAID';
      case InvoiceStatusFilter.processing:
        return normalized == 'PROCESSING' || normalized == 'PENDING';
      case InvoiceStatusFilter.paid:
        return normalized == 'PAID';
    }
  }

  bool inSelectedMonth(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;

    final trimmed = raw.trim();
    if (trimmed.length >= 10) {
      final ymd = trimmed.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ymd)) {
        return ymd.compareTo(createdFrom) >= 0 && ymd.compareTo(createdTo) < 0;
      }
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return false;
    return parsed.year == month.year && parsed.month == month.month;
  }

  bool matches({
    required String status,
    required String createdAt,
    String? paidOnDate,
    String? deadline,
  }) {
    final normalized = status.trim().toUpperCase();
    if (!_statusMatches(normalized)) return false;
    if (ignoresMonth) return true;

    if (monthBasis == InvoiceMonthBasis.created) {
      return inSelectedMonth(createdAt);
    }

    if (normalized == 'PAID') {
      if (paidOnDate != null && paidOnDate.trim().isNotEmpty) {
        return inSelectedMonth(paidOnDate);
      }
      return inSelectedMonth(createdAt);
    }
    return inSelectedMonth(createdAt) || inSelectedMonth(deadline);
  }
}

DateTime currentInvoiceMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}
