import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:path/path.dart' as p;

class BackgroundImageHelper {
  static BackgroundImageHelper? _instance;

  BackgroundImageHelper._internal();

  factory BackgroundImageHelper() {
    _instance ??= BackgroundImageHelper._internal();
    return _instance!;
  }

  Future<String> get backgroundDirPath async {
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'background');
  }

  Future<String> persistImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    final dirPath = await backgroundDirPath;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(sourcePath);
    final fileName = 'bg_${utils.id}$ext';
    final destPath = p.join(dirPath, fileName);

    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<void> deleteImage(String imagePath) async {
    final dirPath = await backgroundDirPath;
    if (imagePath.startsWith(dirPath)) {
      final file = File(imagePath);
      await file.safeDelete();
    }
  }
}

final backgroundHelper = BackgroundImageHelper();
