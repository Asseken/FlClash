import 'dart:io';

import 'package:path/path.dart' as p;

import 'file.dart';
import 'path.dart';
import 'snowflake.dart';

/// Copies picked background images into the app directory, so the theme
/// setting keeps resolving after the source file is moved or deleted.
class BackgroundImageHelper {
  static BackgroundImageHelper? _instance;

  BackgroundImageHelper._internal();

  factory BackgroundImageHelper() {
    _instance ??= BackgroundImageHelper._internal();
    return _instance!;
  }

  Future<String> persistImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }
    final dirPath = await appPath.backgroundDirPath;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final destPath = p.join(
      dirPath,
      'background_${snowflake.id}${p.extension(sourcePath)}',
    );
    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<void> deleteImage(String imagePath) async {
    final dirPath = await appPath.backgroundDirPath;
    if (!p.isWithin(dirPath, imagePath)) {
      return;
    }
    await File(imagePath).safeDelete();
  }

  /// Moves every stored path into the app directory, which is what an Android
  /// setting picked before the image was copied needs: the picker leaves it in
  /// the cache. Paths whose file is already gone are dropped.
  Future<List<String>> persistImages(List<String> imagePaths) async {
    final dirPath = await appPath.backgroundDirPath;
    final storedPaths = <String>[];
    for (final imagePath in imagePaths) {
      if (p.isWithin(dirPath, imagePath)) {
        storedPaths.add(imagePath);
        continue;
      }
      final storedPath = await persistImage(imagePath);
      if (storedPath != imagePath) {
        storedPaths.add(storedPath);
      }
    }
    return storedPaths;
  }
}

final backgroundHelper = BackgroundImageHelper();
