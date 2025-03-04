import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// Import other necessary packages

class NFCHandlerWidget extends StatefulWidget {
  final Widget child;

  NFCHandlerWidget({Key? key, required this.child}) : super(key: key);

  @override
  _NFCHandlerWidgetState createState() => _NFCHandlerWidgetState();
}

class _NFCHandlerWidgetState extends State<NFCHandlerWidget> {
  static const platform = const MethodChannel('com.example.slickbill/nfc');

  @override
  void initState() {
    super.initState();
    _handleIntent();
  }

  Future<void> _handleIntent() async {
    try {
      final String intentAction =
          await platform.invokeMethod('getIntentAction');
      if (intentAction == 'android.nfc.action.NDEF_DISCOVERED' ||
          intentAction == 'android.nfc.action.TECH_DISCOVERED' ||
          intentAction == 'android.nfc.action.TAG_DISCOVERED') {
        // Handle the NFC intent here
        print('NFC tag detected');
        // You can add your own logic here to handle the NFC tag
      }
    } on PlatformException catch (e) {
      print("Failed to get intent action: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
