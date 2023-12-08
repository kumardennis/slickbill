import 'package:intl/intl.dart';

class FormatNumber {
  String formatMoney(double value) {
    var formatter = NumberFormat.currency(symbol: "€ ");

    return formatter.format(value);
  }
}
