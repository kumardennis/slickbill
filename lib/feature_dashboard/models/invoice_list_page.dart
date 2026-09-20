import 'invoice_model.dart';

class InvoiceListPage {
  const InvoiceListPage({
    required this.invoices,
    this.openSum,
    this.paidSum,
  });

  final List<InvoiceModel> invoices;
  final double? openSum;
  final double? paidSum;
}

double openInvoiceSum(Iterable<InvoiceModel> invoices) {
  return invoices
      .where((invoice) {
        final status = invoice.status.trim().toUpperCase();
        return status != 'PAID';
      })
      .fold<double>(0.0, (sum, invoice) => sum + invoice.amount);
}

double paidInvoiceSum(Iterable<InvoiceModel> invoices) {
  return invoices
      .where((invoice) => invoice.status.trim().toUpperCase() == 'PAID')
      .fold<double>(0.0, (sum, invoice) => sum + invoice.amount);
}
