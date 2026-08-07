import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MoneriumTransferListenerService {
  static const String _erc20TransferTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

  static final Map<int, StreamSubscription<FilterEvent>> _subscriptions = {};
  static final Map<int, Timer> _timeouts = {};
  static final Map<int, Web3Client> _clients = {};
  static final Set<int> _inflightCallbacks = <int>{};

  static void _log(String message) {
    debugPrint('[MoneriumTransferListener] $message');
  }

  static String _toWsUrl(String rpcUrl) {
    final uri = Uri.parse(rpcUrl);
    final wsScheme = switch (uri.scheme.toLowerCase()) {
      'https' => 'wss',
      'http' => 'ws',
      _ => uri.scheme,
    };
    return uri.replace(scheme: wsScheme).toString();
  }

  static String _topicToAddress(String? topic) {
    if (topic == null) {
      return '';
    }

    var value = topic.toLowerCase();
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }

    if (value.length < 40) {
      return '';
    }

    return '0x${value.substring(value.length - 40)}';
  }

  static BigInt _hexToBigInt(String? hexValue) {
    if (hexValue == null || hexValue.isEmpty) {
      return BigInt.zero;
    }

    var value = hexValue.toLowerCase();
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.isEmpty) {
      return BigInt.zero;
    }

    return BigInt.parse(value, radix: 16);
  }

  static Future<bool> startWatchingInvoiceTransfer({
    required int invoiceId,
    required String payerWalletAddress,
    required Future<void> Function() onRelevantTransfer,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final rpcUrl = EnvConfig.alchemyNetworkUrl.trim();
    final contractAddress = EnvConfig.moneriumNetworkAddress.trim();

    if (invoiceId <= 0) {
      _log('skip start: invalid invoiceId=$invoiceId');
      return false;
    }

    if (kIsWeb) {
      _log('skip start: websocket listener disabled on web');
      return false;
    }

    if (rpcUrl.isEmpty || contractAddress.isEmpty) {
      _log(
          'skip start: missing ALCHEMY_NETWORK_URL or MONERIUM_NETWORK_ADDRESS');
      return false;
    }

    final normalizedWallet = payerWalletAddress.trim().toLowerCase();
    if (normalizedWallet.isEmpty) {
      _log('skip start: empty payer wallet for invoiceId=$invoiceId');
      return false;
    }

    await stopWatchingInvoice(invoiceId);

    try {
      final wsUrl = _toWsUrl(rpcUrl);
      final httpClient = Client();

      final web3 = Web3Client(
        rpcUrl,
        httpClient,
        socketConnector: () =>
            WebSocketChannel.connect(Uri.parse(wsUrl)).cast<String>(),
      );

      final stream = web3.events(
        FilterOptions(
          fromBlock: const BlockNum.current(),
          topics: const [
            [_erc20TransferTopic]
          ],
        ),
      );

      final normalizedContract = contractAddress.toLowerCase();

      _clients[invoiceId] = web3;
      _timeouts[invoiceId] = Timer(timeout, () {
        _log('timeout reached, stopping watcher for invoiceId=$invoiceId');
        stopWatchingInvoice(invoiceId);
      });

      _subscriptions[invoiceId] = stream.listen(
        (filterEvent) async {
          if (_inflightCallbacks.contains(invoiceId)) {
            return;
          }
          if (filterEvent.removed == true || filterEvent.topics == null) {
            return;
          }

          if (normalizedContract.isNotEmpty) {
            final eventContract =
                filterEvent.address?.toString().toLowerCase() ?? '';
            if (eventContract != normalizedContract) {
              return;
            }
          }

          final topics = filterEvent.topics!;
          if (topics.length < 3) {
            return;
          }

          final from = _topicToAddress(topics[1]);
          final to = _topicToAddress(topics[2]);
          if (from.isEmpty || to.isEmpty) {
            return;
          }

          final value = _hexToBigInt(filterEvent.data);

          if (value <= BigInt.zero) {
            return;
          }

          final involvesPayer =
              from == normalizedWallet || to == normalizedWallet;
          if (!involvesPayer) {
            return;
          }

          _inflightCallbacks.add(invoiceId);
          _log(
            'matched transfer for invoiceId=$invoiceId tx=${filterEvent.transactionHash} from=$from to=$to value=$value',
          );

          try {
            await onRelevantTransfer();
          } finally {
            await stopWatchingInvoice(invoiceId);
            _inflightCallbacks.remove(invoiceId);
          }
        },
        onError: (error) async {
          _log('stream error for invoiceId=$invoiceId: $error');
          await stopWatchingInvoice(invoiceId);
          _inflightCallbacks.remove(invoiceId);
        },
      );

      _log('watcher started for invoiceId=$invoiceId');
      return true;
    } catch (error) {
      _log('failed to start watcher for invoiceId=$invoiceId: $error');
      await stopWatchingInvoice(invoiceId);
      return false;
    }
  }

  static Future<void> stopWatchingInvoice(int invoiceId) async {
    final timeout = _timeouts.remove(invoiceId);
    timeout?.cancel();

    final subscription = _subscriptions.remove(invoiceId);
    await subscription?.cancel();

    final client = _clients.remove(invoiceId);
    await client?.dispose();

    _inflightCallbacks.remove(invoiceId);
  }

  static Future<void> stopAll() async {
    final invoiceIds = _subscriptions.keys.toList(growable: false);
    for (final invoiceId in invoiceIds) {
      await stopWatchingInvoice(invoiceId);
    }
  }
}
