// This is a mock implementation for the web to avoid build errors.

class AppLinks {
  // Mock the stream to be an empty stream
  Stream<Uri> get uriLinkStream => Stream.empty();

  // Mock the method to return a completed Future with null
  Future<Uri?> getInitialLink() => Future.value(null);

  // Keep API parity with app_links package methods used in app code.
  Future<String?> getInitialLinkString() => Future.value(null);

  Future<Uri?> getLatestLink() => Future.value(null);

  Future<String?> getLatestLinkString() => Future.value(null);
}
