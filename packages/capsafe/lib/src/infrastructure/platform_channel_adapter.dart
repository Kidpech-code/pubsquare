import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../application/ports.dart';
import '../application/config.dart';
import '../domain/events.dart';

class PlatformChannelAdapter implements PlatformPort {
  final ScreenshotBlockerConfig config;
  PlatformChannelAdapter(this.config);

  static const _method = MethodChannel('capsafe/methods');
  static const _events = EventChannel('capsafe/events');

  Stream<CaptureStateChanged>? _capStream;
  Stream<ScreenshotTaken>? _shotStream;

  @override
  Future<void> setAndroidSecure(bool enable) async {
    if (!Platform.isAndroid) return;
    await _method.invokeMethod('android.setSecure', enable);
  }

  @override
  Future<void> setIosPrivacySnapshot(bool enable) async {
    if (!Platform.isIOS) return;
    await _method.invokeMethod('ios.setPrivacySnapshot', enable);
  }

  @override
  Stream<CaptureStateChanged> captureStateStream() {
    _capStream ??= _events
        .receiveBroadcastStream()
        .where((raw) {
          return raw is Map && raw['type'] == 'captured';
        })
        .map((raw) {
          final v = (raw as Map)['value'] == true;
          return CaptureStateChanged(isCaptured: v, at: DateTime.now());
        })
        .asBroadcastStream();
    return _capStream!;
  }

  @override
  Stream<ScreenshotTaken> screenshotStream() {
    _shotStream ??= _events
        .receiveBroadcastStream()
        .where((raw) {
          return raw is Map && raw['type'] == 'screenshot';
        })
        .map((_) {
          return ScreenshotTaken(at: DateTime.now());
        })
        .asBroadcastStream();
    return _shotStream!;
  }
}
