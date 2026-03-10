import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/intent_controller.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_nearby_transaction/screens/send_nfc_invoice.dart';
import 'package:slickbill/feature_tickets/screens/tickets_folder_list.dart';
import 'package:slickbill/shared_screens/received_invoice.dart';
import 'package:slickbill/shared_widgets/global_invoice_receiver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../feature_dashboard/screens/all_bills.dart';
import '../../feature_navigation/getx_controllers/navigation_controller.dart';
import '../../feature_send/screens/send_invoice.dart';
import '../../feature_self_create/screens/open_create_self_invoice.dart';
import '../../feature_trashboard/screens/all_trash_bills.dart';

class HomeScreen extends HookWidget {
  final supabase = Supabase.instance.client;
  UserController userController = Get.put(UserController());
  ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();

  IntentController intentController = Get.put(IntentController());

  final NavigationController navigationController =
      Get.put(NavigationController()); // Initialize controller

  final List<Widget> _pages = [
    AllBills(), // 0 - Bills list
    const SendNfcInvoice(), // 2 - QR/NFC Exchange (CENTER - Main action)
    const OpenAndCreateSelfInvoice(), // 1 - Upload invoice
  ];

  @override
  Widget build(BuildContext context) {
    CurrentBankController currentBankController =
        Get.put(CurrentBankController());

    Future openNewReceivedInvoiceSheet(int invoiceId) async {
      final invoices =
          await receivedInvoicesClass.getPrivateReceivedInvoices(id: invoiceId);

      print(invoices);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceivedInvoice(invoice: invoices!.first),
        ),
      );
    }

    useEffect(() {
      final changes = supabase
          .channel('invoice-updates-home-screen')
          .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'digital_invoices',
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'receiverPrivateUserId',
                  value: userController.user.value.privateUserId.toString()),
              callback: (payload) =>
                  openNewReceivedInvoiceSheet(payload.newRecord['id']))
          .subscribe();

      return () async {
        try {
          await supabase.removeChannel(changes);
        } catch (e) {
          // Safely ignore cleanup errors
        }
      };
    }, []);

    final filePath = useState<Uint8List?>(null);
    final checkingForIntent = useState<bool>(true);
    final intentAlreadyHandled = useState<bool>(false);

    const platform = const MethodChannel('com.example.slickbill/getPdfBytes');

    Future<Uint8List?> _getFilePath() async {
      try {
        final Uint8List? result = await platform.invokeMethod('getPdfBytes');
        print('FLUTTERBYTES $result');
        return result;
      } on PlatformException catch (e) {
        print("Failed to get file path: '${e.message}'.");
        return null;
      }
    }

    // Function to check for intent
    Future<void> _checkForIntent() async {
      if (kIsWeb) return;

      checkingForIntent.value = true;

      try {
        final value = await _getFilePath();

        if (!checkingForIntent.hasListeners) return;

        if (value != null) {
          print('Intent detected with PDF data');
          filePath.value = value;
          intentController.loadIntent(true);
          navigationController.changeIndex(2);
        }
      } catch (e) {
        print('Error checking for intent: $e');
      } finally {
        if (checkingForIntent.hasListeners) {
          checkingForIntent.value = false;
        }
      }
    }

    useEffect(() {
      late AppLifecycleListener listener;
      bool isActive = true; // Track if effect is still active

      listener = AppLifecycleListener(
        onResume: () {
          if (isActive) {
            print('App resumed, checking for new intents');
            _checkForIntent();
          }
        },
        onShow: () {
          if (isActive) {
            print('App shown, checking for new intents');
            _checkForIntent();
          }
        },
      );

      // Initial check
      _checkForIntent();

      return () {
        isActive = false;
        listener.dispose();
      };
    }, []);

    var selectedBank = userController.user.value.ibans?.firstWhere(
      (bank) => bank.iban == userController.user.value.iban,
      orElse: () => userController.user.value.ibans!.first,
    );

    if (selectedBank != null) {
      currentBankController.loadCurrentBank(BankAccount(
        bankName: selectedBank.bankName,
        iban: selectedBank.iban,
        bankAccountName: selectedBank.bankAccountName,
      ));
    }

    return Scaffold(
      body: Obx(() => _pages[navigationController.currentIndex.value]),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: navigationController.currentIndex.value,
          onTap: (index) => navigationController.changeIndex(index),
          backgroundColor: Theme.of(context).colorScheme.blue,
          selectedItemColor: Theme.of(context).colorScheme.light,
          unselectedItemColor:
              Theme.of(context).colorScheme.gray.withOpacity(0.6),
          selectedFontSize: 11,
          unselectedFontSize: 10,
          items: const [
            // ✅ 0 - Bills
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.list, size: 20),
              label: 'Bills',
            ),

            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.qrcode, size: 28),
              label: 'Exchange',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.fileArrowUp, size: 20),
              label: 'Upload',
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.darkerBlue,
                  Theme.of(context).colorScheme.blue,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Theme.of(context).colorScheme.darkerBlue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'receive',
              onPressed: () => GlobalReceiveService.showReceiveOptions(context),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const FaIcon(
                FontAwesomeIcons.download,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
