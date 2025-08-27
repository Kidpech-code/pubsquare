import '../domain/events.dart';
import 'config.dart';

abstract class PlatformPort {
  Future<void> setAndroidSecure(bool enable);
  Future<void> setIosPrivacySnapshot(bool enable);
  Stream<CaptureStateChanged> captureStateStream(); // iOS
  Stream<ScreenshotTaken> screenshotStream(); // iOS
}

abstract class OverlayPort {
  void showCapturedOverlay(bool show, IosOverlayStyle style);
  void showAppSwitcherPrivacy(bool show);
  void showUxBanner(dynamic context, UxCopy copy);
  void showWatermark(bool show);
}

extension TelemetryPortExt on TelemetryPort {
  void safeScreenshot(ScreenshotTaken e) {
    try {
      onScreenshotTaken(e);
    } catch (_) {}
  }

  void safeCaptured(bool v) {
    try {
      onCaptureStateChanged(v);
    } catch (_) {}
  }
}
