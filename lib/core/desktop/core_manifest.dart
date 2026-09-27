import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:path/path.dart' as p;

final class CoreManifest {
  const CoreManifest._();

  static Future<String?> readCoreSha256({String? path}) async {
    try {
      final file = File(path ?? _defaultPath());
      final value = jsonDecode(await file.readAsString());
      if (value is! Map) return null;
      final coreSha256 = value['coreSha256'];
      if (coreSha256 is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(coreSha256)) {
        return null;
      }
      return coreSha256;
    } on Object {
      return null;
    }
  }

  static Future<bool> writeCoreSha256(String sha256, {String? path}) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      return false;
    }
    try {
      final file = File(path ?? _defaultPath());
      final values = <String, Object?>{'coreSha256': sha256};
      final existing = await file.exists()
          ? jsonDecode(await file.readAsString())
          : null;
      if (existing is Map) {
        values.addAll(Map<String, Object?>.from(existing));
        values['coreSha256'] = sha256;
      }
      await file.writeAsString(jsonEncode(values), flush: true);
      return true;
    } on Object {
      return false;
    }
  }

  static String _defaultPath() {
    return p.join(p.dirname(Platform.resolvedExecutable), coreManifestName);
  }
}
