import '../domain/events.dart';

class AndroidProtectionConfig {
  final bool protectInRecents;
  const AndroidProtectionConfig({this.protectInRecents = true});
}

enum IosOverlayMode { full, partial, none }

enum IosOverlayStyle { black, blur, watermark }

class IosProtectionConfig {
  final IosOverlayMode overlayMode;
  final IosOverlayStyle overlayStyle;
  final bool showAppSwitcherPrivacyOverlay;
  final void Function(dynamic context)? onScreenshot;

  const IosProtectionConfig({
    this.overlayMode = IosOverlayMode.full,
    this.overlayStyle = IosOverlayStyle.black,
    this.showAppSwitcherPrivacyOverlay = true,
    this.onScreenshot,
  });
}

class UxCopy {
  final String title;
  final String message;
  final String learnMoreActionLabel;
  const UxCopy({
    this.title = 'Screen protection',
    this.message = 'For your privacy, screenshots are restricted on this screen.',
    this.learnMoreActionLabel = 'Learn more',
  });
}

class UxMessagingConfig {
  final UxCopy localization;
  final UxCopy Function(dynamic context)? localizationBuilder;
  final bool showFirstTimeBanner; // show once per route via SecureScope
  const UxMessagingConfig({
    this.localization = const UxCopy(),
    this.localizationBuilder,
    this.showFirstTimeBanner = true,
  });
}

class TelemetryConfig implements TelemetryPort {
  final void Function(ScreenshotTaken)? onScreenshotTakenHandler;
  final void Function(bool isCaptured)? onCaptureStateChangedHandler;
  const TelemetryConfig({
    this.onScreenshotTakenHandler,
    this.onCaptureStateChangedHandler,
  });

  @override
  void onCaptureStateChanged(bool isCaptured) => onCaptureStateChangedHandler?.call(isCaptured);

  @override
  void onScreenshotTaken(ScreenshotTaken event) => onScreenshotTakenHandler?.call(event);
}

class ScreenshotBlockerConfig {
  final AndroidProtectionConfig android;
  final IosProtectionConfig ios;
  final UxMessagingConfig ux;
  final TelemetryConfig telemetry;

  const ScreenshotBlockerConfig({
    this.android = const AndroidProtectionConfig(),
    this.ios = const IosProtectionConfig(),
    this.ux = const UxMessagingConfig(),
    this.telemetry = const TelemetryConfig(),
  });
}

abstract class TelemetryPort {
  void onScreenshotTaken(ScreenshotTaken event);
  void onCaptureStateChanged(bool isCaptured);
}
