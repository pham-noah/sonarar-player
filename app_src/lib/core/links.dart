import 'dart:io';

import 'package:flutter/services.dart';

/// Where the app points when it names itself. One place, so a rename or a move
/// is one edit.
class Links {
  static const String author = 'https://github.com/pham-noah';
  static const String source = 'https://github.com/pham-noah/sonarar-player';
}

/// Hands a URL to the phone. Returns false when nothing on it can open the
/// link, so the caller can say so instead of pretending it worked.
Future<bool> openExternal(String url) async {
  if (!Platform.isAndroid) return false;
  try {
    final opened = await const MethodChannel('personar/links')
        .invokeMethod<bool>('open', {'url': url});
    return opened ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
