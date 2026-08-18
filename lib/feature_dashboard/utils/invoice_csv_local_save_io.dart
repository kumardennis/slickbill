import 'dart:io';
import 'dart:typed_data';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

bool _mediaStoreReady = false;

Future<String> saveCsvLocally({
  required Uint8List bytes,
  required String filename,
}) async {
  if (Platform.isAndroid) {
    if (!_mediaStoreReady) {
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'SlickBills';
      _mediaStoreReady = true;
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$filename');
    await tempFile.writeAsBytes(bytes, flush: true);

    final saved = await MediaStore().saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    if (saved == null) {
      throw Exception('Could not save CSV to Downloads');
    }
    return 'Downloads/SlickBills/$filename';
  }

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
