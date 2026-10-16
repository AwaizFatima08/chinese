import 'dart:io';

import 'package:flutter/services.dart';

/// Reads assets straight from the project folder, for host-side tests.
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
