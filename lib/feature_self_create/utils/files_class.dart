import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../models/extracted_invoice_data_model.dart';

class FilesClass {
  final UserController userController = Get.find();

  var unescape = HtmlUnescape();

  Future<ExtractedInvoiceDataModel?> uploadFileToExtractData(fileBytes,
      [incomingText]) async {
    // html.FormData formData = html.FormData();

    // formData.append('file', fileBytes);

    try {
      PdfDocument document = PdfDocument(inputBytes: fileBytes);
//Extract the text from page 1.
      String text = incomingText ??
          PdfTextExtractor(document).extractText(startPageIndex: 0);

      //Create a new instance of the PdfTextExtractor.
      PdfTextExtractor extractor = PdfTextExtractor(document);

//Extract all the text from a particular page.
      List<TextLine> result = extractor.extractTextLines(startPageIndex: 0);

//Dispose the document.
      document.dispose();

      List<String> joinedTextList = [];

      result.forEach(
        (element) {
          joinedTextList.add(element.text);
        },
      );

      String joinedText = (joinedTextList.join('\n'));

      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-invoice-custom-fields', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "fileText": joinedText
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
