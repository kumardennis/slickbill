import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class FilesForTicketsClass {
  final UserController userController = Get.find();

  var unescape = HtmlUnescape();

  Future<Map<String, dynamic>?> getTicketExtractData(
      String fileText, String fileUrl) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('tickets/get-ticket-brief-data', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "supabaseStorageUrl": fileUrl,
        "fileText": unescape.convert(fileText)
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

  Future<String?> uploadPdfToSupabase(Uint8List image) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('temporary-files-tickets')
          .uploadBinary(
              '${userController.user.value.id}_ticket_${DateTime.now()}', image,
              fileOptions: const FileOptions(contentType: 'application/pdf'));

      final data = response;

      return data;
    } catch (err) {
      print(err);
      return null;
    }
  }
}
