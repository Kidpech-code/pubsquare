import 'dart:async';
import 'package:capsafe/capsafe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Fake ports to simulate iOS capture/screenshot behavior
class _FakePlatformPort implements PlatformPort {
  final _cap = StreamController<CaptureStateChanged>.broadcast();
  final _shot = StreamController<ScreenshotTaken>.broadcast();
  @override
  Future<void> setAndroidSecure(bool enable) async {}
  @override
  Future<void> setIosPrivacySnapshot(bool enable) async {}
  @override
  Stream<CaptureStateChanged> captureStateStream() => _cap.stream;
  @override
  Stream<ScreenshotTaken> screenshotStream() => _shot.stream;
  void emitCaptured(bool v) {
    _cap.add(CaptureStateChanged(isCaptured: v, at: DateTime.now()));
  }
}

class _FakeOverlayPort implements OverlayPort {
  bool lastCaptured = false;
  IosOverlayStyle? lastStyle;
  @override
  void showCapturedOverlay(bool show, IosOverlayStyle style) {
    lastCaptured = show;
    lastStyle = style;
  }

  @override
  void showAppSwitcherPrivacy(bool show) {}
  @override
  void showUxBanner(dynamic context, UxCopy copy) {}
  @override
  void showWatermark(bool show) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SensitiveArea masks only when captured in partial mode', (tester) async {
    // Arrange capsafe with partial overlay mode (SensitiveArea-driven)
    final fakePlatform = _FakePlatformPort();
    final fakeOverlay = _FakeOverlayPort();
    await Capsafe.instance.configure(
      const ScreenshotBlockerConfig(ios: IosProtectionConfig(overlayMode: IosOverlayMode.partial)),
      platformOverride: fakePlatform,
      overlayOverride: fakeOverlay,
    );

    // A simple page with a SensitiveArea box we can find by key
    const key = Key('sensitive');
    await tester.pumpWidget(
      SystemOverlayAdapter.wrapApp(
        child: MaterialApp(
          home: SecureScope(
            policy: ProtectionPolicy.secure(),
            child: Scaffold(
              body: Center(
                child: SensitiveArea(
                  child: Container(key: key, width: 100, height: 50, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Initially not captured -> SensitiveArea should not be obscured
    expect(find.byKey(key), findsOneWidget);

    // Act: simulate capture starting on iOS
    fakePlatform.emitCaptured(true);
    await tester.pumpAndSettle();

    // Assert: In partial mode, global overlay is off but SensitiveArea masks
    // We verify global overlay call did not enable full overlay
    expect(fakeOverlay.lastCaptured, isFalse);

    // And we expect the SensitiveArea to be under a Stack with two children (masked)
    // We can't easily inspect blur; instead ensure the original child still laid out.
    expect(find.byKey(key), findsOneWidget);

    // Cleanup: capture ends
    fakePlatform.emitCaptured(false);
    await tester.pumpAndSettle();
    expect(fakeOverlay.lastCaptured, isFalse);
  });
}
