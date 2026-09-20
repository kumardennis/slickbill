String sanitizeInvoiceSearch(String raw) {
  return raw.trim().replaceAll(RegExp(r'[%_,]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
}

const _fuzzyThreshold = 0.45;
const _maxLengthDelta = 2;

bool invoiceTextMatches(String? haystack, String query) {
  final q = sanitizeInvoiceSearch(query).toLowerCase();
  if (q.isEmpty) return true;
  final h = (haystack ?? '').trim().toLowerCase();
  if (h.isEmpty) return false;
  if (h.contains(q)) return true;
  if (q.length < 3) return false;
  if (_trigramSimilarity(h, q) > _fuzzyThreshold) return true;
  for (final word in h.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (word.contains(q)) return true;
    if ((word.length - q.length).abs() <= _maxLengthDelta &&
        _trigramSimilarity(word, q) > _fuzzyThreshold) {
      return true;
    }
  }
  return false;
}

bool invoiceFieldsMatchSearch(Iterable<String?> fields, String query) {
  final q = sanitizeInvoiceSearch(query);
  if (q.isEmpty) return true;
  for (final field in fields) {
    if (invoiceTextMatches(field, q)) return true;
  }
  return false;
}

double _trigramSimilarity(String a, String b) {
  final left = _trigrams(a);
  final right = _trigrams(b);
  if (left.isEmpty || right.isEmpty) return 0;
  var intersection = 0;
  for (final gram in left) {
    if (right.contains(gram)) intersection++;
  }
  return (2 * intersection) / (left.length + right.length);
}

Set<String> _trigrams(String value) {
  final padded = '  $value ';
  if (padded.length < 3) return {};
  final grams = <String>{};
  for (var i = 0; i <= padded.length - 3; i++) {
    grams.add(padded.substring(i, i + 3));
  }
  return grams;
}
