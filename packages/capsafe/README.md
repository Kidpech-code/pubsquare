# capsafe (DDD)

A Flutter plugin to protect sensitive content on Android and iOS with a strong DDD architecture.

- Android: True blocking via FLAG_SECURE (route-scoped with safe ref-count and no flicker).
- iOS: Platform cannot block screenshots; capsafe detects (screenshot + isCaptured), shows configurable overlays (full-screen or partial via SensitiveArea), and hides App Switcher snapshots. Fully App Store–compliant, using only public APIs.

Why capsafe

- Route-scoped protection: Enable per-screen with SecureScope.
- Ref-count stabilization: Safe toggling when multiple widgets/flows overlap.
- UX-first: Built-in banner to explain “why” once; localizable.
- Overlay modes (iOS): full-screen, partial (SensitiveArea only), or none.
- Telemetry hooks: Observe screenshot/capture events (no network dependency).
- Clean layering (DDD): Testable domain/services, swappable infrastructure adapters.

Limitations

- iOS cannot truly block screenshots. capsafe focuses on detection and user-friendly mitigation (overlay, messaging, snapshot privacy).
- Hardware cameras can always capture content.

Quick Start

```dart
import 'package:capsafe/capsafe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Capsafe.instance.configure(
    ScreenshotBlockerConfig(
      android: AndroidProtectionConfig(protectInRecents: true),
      ios: IosProtectionConfig(
        overlayMode: IosOverlayMode.full, // full | partial | none
        showAppSwitcherPrivacyOverlay: true,
        onScreenshot: (ctx) => ScreenshotNotifier.showInfoBanner(ctx),
      ),
      ux: UxMessagingConfig(
        localization: UxCopy(
          title: 'การป้องกันข้อมูล',
          message: 'เพื่อความเป็นส่วนตัว หน้านี้จำกัดการจับภาพหน้าจอ',
          learnMoreActionLabel: 'ทำไม?',
        ),
        showFirstTimeBanner: true,
      ),
      telemetry: TelemetryConfig(
        onScreenshotTaken: (e) => debugPrint('Screenshot at ${e.at}'),
        onCaptureStateChanged: (v) => debugPrint('isCaptured=$v'),
      ),
    ),
  );
  runApp(SystemOverlayAdapter.wrapApp(child: const MyApp()));
}

class SecurePage extends StatelessWidget {
  const SecurePage({super.key});
  @override
  Widget build(BuildContext context) {
    return SecureScope(
      policy: ProtectionPolicy.secure().copyWith(
        allowAndroidScreenShare: false, // relax to true for meeting flows
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Sensitive screen')),
        body: Column(
          children: const [
            Text('Android: BLOCK; iOS: detect + overlay'),
            SizedBox(height: 12),
            SensitiveArea(
              child: Text('Partial masking area on iOS (overlayMode: partial).'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Overlay modes (iOS)

- full: full-screen overlay while screen is being captured (UIScreen.isCaptured)
- partial: only widgets wrapped by SensitiveArea are masked (recommended for better UX)
- none: no overlay; rely on messaging/telemetry only

Store policy compliance

- iOS: Do not mimic/replace system’s screenshot UI; use only public notifications.
- Android: Provide policy to allow temporary screen sharing in legitimate flows.
- Accessibility: overlays are non-interactive; banners readable; keep contrast good.

License
MIT

Localization

You can localize the UX banner text using your app’s ARB-generated localizations. Provide a `localizationBuilder` that maps the current context to a `UxCopy`.

```
await Capsafe.instance.configure(
  ScreenshotBlockerConfig(
    ux: UxMessagingConfig(
      localizationBuilder: (context) {
        final l10n = Localizations.of<MyL10n>(context, MyL10n)!;
        return UxCopy(
          title: l10n.screenProtectionTitle,
          message: l10n.screenProtectionMessage,
          learnMoreActionLabel: l10n.learnMore,
        );
      },
    ),
  ),
);
```

# capsafe

A new Flutter plugin project.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
