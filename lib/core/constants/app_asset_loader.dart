import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reads a translation file as bytes and decodes it here.
///
/// easy_localization's own loader goes through `rootBundle.loadString`, which
/// hands any file over 50 KB to a background isolate. `ar.json` is past that:
/// starting an isolate for a few milliseconds of decoding costs more than it
/// saves, and a widget test's fake clock never sees it finish. Every
/// `EasyLocalization` in the app and its tests uses this one.
class AppAssetLoader extends AssetLoader {
  const AppAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final ByteData data = await rootBundle.load(
      '$path/${locale.languageCode}.json',
    );
    final Object? decoded = jsonDecode(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
