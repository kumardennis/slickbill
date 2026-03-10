// This is a mock implementation for the web to avoid build errors.

class AppLinks {
  // Mock the stream to be an empty stream
  Stream<Uri> get uriLinkStream => Stream.empty();

  // Mock the method to return a completed Future with null
  Future<Uri?> getInitialLink() => Future.value(null);
}
