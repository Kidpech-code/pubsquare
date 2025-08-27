<!-- 1. **License Section:** The "License" heading is missing a markdown header (`## License`).
2. **Overlay Modes Section:** Consider using a subheading for clarity.
3. **Store Policy Compliance:** Use a subheading for better structure.
4. **Localization Section:** Use a subheading for consistency.
5. **Duplicate Heading:** The second `# capsafe` and "Getting Started" section are boilerplate from Flutter and can be removed, as the earlier sections already cover usage and installation. -->

```markdown
# capsafe 

![pub package](https://img.shields.io/pub/v/capsafe?label=pub.dev&color=blue)

A Flutter plugin to protect sensitive content on Android and iOS with a strong DDD architecture.

- **Android:** True blocking via `FLAG_SECURE` (route-scoped with safe ref-count and no flicker).
- **iOS:** Platform cannot block screenshots; capsafe detects (screenshot + isCaptured), shows configurable overlays (full-screen or partial via `SensitiveArea`), and hides App Switcher snapshots. Fully App Store–compliant, using only public APIs.

## Why capsafe

- **Route-scoped protection:** Enable per-screen with `SecureScope`.
- **Ref-count stabilization:** Safe toggling when multiple widgets/flows overlap.
- **UX-first:** Built-in banner to explain “why” once; localizable.
- **Overlay modes (iOS):** full-screen, partial (`SensitiveArea` only), or none.
- **Telemetry hooks:** Observe screenshot/capture events (no network dependency).
- **Clean layering:** Testable domain/services, swappable infrastructure adapters.

## Limitations

- iOS cannot truly block screenshots. capsafe focuses on detection and user-friendly mitigation (overlay, messaging, snapshot privacy).
- Hardware cameras can always capture content.

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  capsafe: ^<latest_version>
```

## Quick Start

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

## Overlay Modes (iOS)

- **full:** Full-screen overlay while screen is being captured (`UIScreen.isCaptured`)
- **partial:** Only widgets wrapped by `SensitiveArea` are masked (recommended for better UX)
- **none:** No overlay; rely on messaging/telemetry only

## Store Policy Compliance

- **iOS:** Do not mimic/replace system’s screenshot UI; use only public notifications.
- **Android:** Provide policy to allow temporary screen sharing in legitimate flows.
- **Accessibility:** Overlays are non-interactive; banners readable; keep contrast good.

## License

MIT

## Localization

You can localize the UX banner text using your app’s ARB-generated localizations. Provide a `localizationBuilder` that maps the current context to a `UxCopy`.

```dart
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
```

Summary:
- The markdown is correct and clear.
- Minor improvements are suggested for structure and clarity.
- Remove duplicate/boilerplate sections at the end.
- Add missing subheadings for better navigation.
