class IbanExtractor {
  // IBAN regex pattern - matches most European IBANs
  static final RegExp ibanPattern = RegExp(
    r'\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b',
    caseSensitive: true,
  );

  /// Extract IBAN from text
  static String? extractIban(String text) {
    // TODO: implement
    // Remove extra spaces and normalize
    final normalized = text.replaceAll(RegExp(r'\s+'), '');

    print(normalized);

    final match = ibanPattern.firstMatch(normalized);

    print(match);
    // return match?.group(0);

    return text;
  }

  /// Extract all IBANs from text
  static List<String> extractAllIbans(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final matches = ibanPattern.allMatches(normalized);
    return matches.map((m) => m.group(0)!).toList();
  }

  /// Validate IBAN format for Estonia
  static bool isValidEstonianIban(String? iban) {
    if (iban == null) return false;

    // Estonian IBAN: EE + 2 check digits + 16 digits
    final estonianPattern = RegExp(r'^EE\d{18}$');
    return estonianPattern.hasMatch(iban);
  }

  /// Format IBAN with spaces (every 4 characters)
  static String formatIban(String iban) {
    final cleaned = iban.replaceAll(RegExp(r'\s+'), '');
    final formatted = StringBuffer();

    for (int i = 0; i < cleaned.length; i += 4) {
      if (i > 0) formatted.write(' ');
      formatted.write(cleaned.substring(
          i, i + 4 > cleaned.length ? cleaned.length : i + 4));
    }

    return formatted.toString();
  }
}
