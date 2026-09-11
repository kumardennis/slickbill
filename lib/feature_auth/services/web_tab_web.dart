// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void slickBillsAssignCurrentTab(String url) {
  html.window.location.assign(url);
}

void slickBillsMarkWebOAuthPending({String? invoiceToken}) {
  html.window.sessionStorage['sb_oauth_pending'] = '1';
  if (invoiceToken != null && invoiceToken.isNotEmpty) {
    html.window.sessionStorage['sb_oauth_invoice_token'] = invoiceToken;
  } else {
    html.window.sessionStorage.remove('sb_oauth_invoice_token');
  }
}

bool slickBillsHasWebOAuthPending() =>
    html.window.sessionStorage['sb_oauth_pending'] == '1';

String? slickBillsPeekWebOAuthInvoiceToken() {
  final value = html.window.sessionStorage['sb_oauth_invoice_token'];
  if (value == null || value.isEmpty) return null;
  return value;
}

void slickBillsClearWebOAuthPending() {
  html.window.sessionStorage.remove('sb_oauth_pending');
  html.window.sessionStorage.remove('sb_oauth_invoice_token');
}
