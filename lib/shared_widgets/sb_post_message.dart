import 'dart:async';

/// Cross-platform message stream coming from wallet-client (React) iframe/tab.
///
/// On non-web platforms this is an empty stream.
Stream<Map<String, dynamic>> slickBillsPostMessages() =>
    const Stream.empty();