import 'dart:io';

import 'package:crypto/crypto.dart';
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

  /// 复制图片到 background 目录。
  ///
  /// 返回 (path, created)：created 表示本次是否真的复制了新文件；
  /// 目录中已存在内容相同（大小 + 哈希一致）的图片时直接复用其路径，created 为 false。
  Future<({String path, bool created})> persistImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return (path: sourcePath, created: false);

    final dirPath = await backgroundDirPath;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final size = await sourceFile.length();
    final hash = await _fileHash(sourceFile);
    final existing = await _findByHash(dir, size, hash);
    if (existing != null) {
      return (path: existing.path, created: false);
    }

    final ext = p.extension(sourcePath);
    final fileName = 'bg_${utils.id}$ext';
    final destPath = p.join(dirPath, fileName);
    await sourceFile.copy(destPath);
    return (path: destPath, created: true);
  }

  Future<void> deleteImage(String imagePath) async {
    final dirPath = await backgroundDirPath;
    if (p.isWithin(dirPath, imagePath)) {
      final file = File(imagePath);
      await file.safeDelete();
    }
  }

  Future<File?> _findByHash(Directory dir, int size, String hash) async {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (await entity.length() != size) continue;
      if (await _fileHash(entity) == hash) return entity;
    }
    return null;
  }

  Future<String> _fileHash(File file) async {
    final digest = md5.bind(file.openRead());
    return (await digest.first).toString();
  }
}

final backgroundHelper = BackgroundImageHelper();
