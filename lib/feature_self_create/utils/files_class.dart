import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../models/extracted_invoice_data_model.dart';

class FilesClass {
  final UserController userController = Get.find();

  var unescape = HtmlUnescape();

  Future<ExtractedInvoiceDataModel?> uploadTextToExtractData(
      incomingText) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-invoice-custom-fields', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "fileText": unescape.convert(incomingText)
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Map<String, dynamic> extractData =
            (data['data'] as Map<String, dynamic>);
        ExtractedInvoiceDataModel extractedData =
            ExtractedInvoiceDataModel.fromJson(extractData);

        return extractedData;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReceiptExtractData(String imageUrl) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-receipt-extracted-data', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "supabaseStorageUrl": imageUrl
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Map<String, dynamic> extractData =
            (data['data'] as Map<String, dynamic>);

        return extractData;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<String?> uploadImageToSupabase(Uint8List image) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('temporary-files')
          .uploadBinary(
              '${userController.user.value.id}_receipt_${DateTime.now()}',
              image,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final data = response;

      return data;
    } catch (err) {
      print(err);
      return null;
    }
  }
}
