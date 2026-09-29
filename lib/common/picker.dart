import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Picker {
  /// Swapped in tests: no test can raise the platform's gallery UI.
  @visibleForTesting
  static Future<String?> Function()? pickImageOverride;

  Future<PlatformFile?> pickerFile() async {
    return FilePicker.pickFile(initialDirectory: await appPath.downloadDirPath);
  }

  /// Android answers with a copy in the app cache directory, which the system
  /// may delete at any time, so callers have to move it before storing it.
  Future<String?> pickerImage() async {
    final override = pickImageOverride;
    if (override != null) {
      return override();
    }
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    return xFile?.path;
  }

  Future<Uri?> saveFile(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (!system.isAndroid && uri != null && uri.scheme == 'file') {
      final file = File(uri.toFilePath());
      await file.safeWriteAsBytes(bytes);
    }
    return uri;
  }

  Future<Uri?> saveFileWithPath(String fileName, String localPath) async {
    final localFile = File(localPath);
    if (!await localFile.exists()) {
      await localFile.create(recursive: true);
    }
    final bytes = await localFile.readAsBytes();
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    await localFile.safeDelete();
    return uri;
  }

  Future<String?> pickerConfigQRCode() async {
    final path = await pickerImage();
    if (path == null) {
      return null;
    }
    final controller = MobileScannerController();
    final capture = await controller.analyzeImage(
      path,
      formats: [BarcodeFormat.qrCode],
    );
    final result = capture?.barcodes.first.rawValue;
    if (result == null || !result.isUrl) {
      throw MessageException(currentAppLocalizations.pleaseUploadValidQrcode);
    }
    return result;
  }
}

extension PlatformFileExt on PlatformFile {
  Future<Uint8List> readBytes() {
    return readAsBytes();
  }
}

final picker = Picker();
