import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> imagePing(Uri url, Duration timeout) async {
  final completer = Completer<bool>();
  final img = web.HTMLImageElement();
  void done(bool ok) {
    if (!completer.isCompleted) completer.complete(ok);
    img.onload = null;
    img.onerror = null;
  }

  img.onload = ((web.Event _) {
    done(true);
  }).toJS;

  img.onerror = ((web.Event _) {
    done(false);
  }).toJS;

  img.src = url.replace(queryParameters: {
    ...url.queryParameters,
    '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
  }).toString();
  // timeout
  Future.delayed(timeout, () => done(false));
  return completer.future;
}
