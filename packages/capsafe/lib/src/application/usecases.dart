import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/policy.dart';
import 'ports.dart';
import 'config.dart';

class UseCases {
  final PlatformPort platform;
  final OverlayPort overlay;
  final TelemetryPort telemetry;
  final ScreenshotBlockerConfig config;

  UseCases({
    required this.platform,
    required this.overlay,
    required this.telemetry,
    required this.config,
  });

  // Public listenables (Presentation can bind to these)
  final ValueNotifier<bool> isCaptured = ValueNotifier(
    false,
  ); // iOS capture state
  final ValueNotifier<bool> sensitiveObscured = ValueNotifier(
    false,
  ); // for SensitiveArea

  int _refCount = 0;
  bool _androidSecureOn = false;
  StreamSubscription? _capSub;
  StreamSubscription? _shotSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _capSub = platform.captureStateStream().listen((e) {
      isCaptured.value = e.isCaptured;
      telemetry.safeCaptured(e.isCaptured);

      // Overlay behavior based on mode
      switch (config.ios.overlayMode) {
        case IosOverlayMode.full:
          overlay.showCapturedOverlay(e.isCaptured, config.ios.overlayStyle);
          sensitiveObscured.value = false; // managed by global overlay
          break;
        case IosOverlayMode.partial:
          overlay.showCapturedOverlay(false, config.ios.overlayStyle);
          sensitiveObscured.value = e.isCaptured;
          break;
        case IosOverlayMode.none:
          overlay.showCapturedOverlay(false, config.ios.overlayStyle);
          sensitiveObscured.value = false;
          break;
      }
    });

    _shotSub = platform.screenshotStream().listen((e) {
      telemetry.safeScreenshot(e);
      config.ios.onScreenshot?.call(null); // host app can show banner/toast
    });
    _initialized = true;
  }

  Future<void> enableProtection(ProtectionPolicy policy) async {
    _refCount++;
    if (_refCount == 1) {
      // Android
      if (policy.androidFlagSecure && !policy.allowAndroidScreenShare) {
        await platform.setAndroidSecure(true);
        _androidSecureOn = true;
      }
      // iOS: App Switcher snapshot privacy
      if (policy.iosAppSwitcherPrivacy) {
        await platform.setIosPrivacySnapshot(true);
        overlay.showAppSwitcherPrivacy(true);
      }
      // iOS: full overlay immediate apply if already captured
      if (config.ios.overlayMode == IosOverlayMode.full && isCaptured.value) {
        overlay.showCapturedOverlay(true, config.ios.overlayStyle);
      }
    }
  }

  Future<void> disableProtection() async {
    _refCount = (_refCount - 1).clamp(0, 1 << 30);
    if (_refCount == 0) {
      if (_androidSecureOn) {
        await platform.setAndroidSecure(false);
        _androidSecureOn = false;
      }
      await platform.setIosPrivacySnapshot(false);
      overlay.showAppSwitcherPrivacy(false);
      overlay.showCapturedOverlay(false, config.ios.overlayStyle);
      overlay.showWatermark(false);
      sensitiveObscured.value = false;
    }
  }

  void showUxMessage(dynamic context) {
    final copy = config.ux.localizationBuilder?.call(context) ?? config.ux.localization;
    overlay.showUxBanner(context, copy);
  }

  void dispose() {
    _capSub?.cancel();
    _shotSub?.cancel();
  }
}
