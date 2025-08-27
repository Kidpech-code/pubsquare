import 'package:flutter/material.dart';
import 'package:capsafe/capsafe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Capsafe.instance.configure(
    const ScreenshotBlockerConfig(
      ios: IosProtectionConfig(
        overlayMode: IosOverlayMode.partial, // use partial to mask only sensitive areas
        overlayStyle: IosOverlayStyle.blur,
      ),
    ),
  );
  runApp(SystemOverlayAdapter.wrapApp(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const Home(), theme: ThemeData(useMaterial3: true));
  }
}

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('capsafe demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: const Text('Open secure screen (scoped)'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurePage())),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Meeting flow: allow Android share temporarily'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeetingPage())),
            ),
          ],
        ),
      ),
    );
  }
}

class SecurePage extends StatelessWidget {
  const SecurePage({super.key});
  @override
  Widget build(BuildContext context) {
    return SecureScope(
      policy: ProtectionPolicy.secure(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Secure Page')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              Text('Android: FLAG_SECURE; iOS: partial overlay with SensitiveArea'),
              SizedBox(height: 12),
              SensitiveArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.amber),
                  child: Padding(padding: EdgeInsets.all(8.0), child: Text('Only this area is obscured when captured.')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MeetingPage extends StatelessWidget {
  const MeetingPage({super.key});
  @override
  Widget build(BuildContext context) {
    // Allow Android screen share temporarily (e.g., during a call), but keep iOS UX light (partial overlay)
    final meetingPolicy = ProtectionPolicy.secure().copyWith(allowAndroidScreenShare: true);
    return SecureScope(
      policy: meetingPolicy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Meeting (temporary share)')),
        body: const Center(child: Text('Android can screen-share; iOS uses partial overlay for sensitive areas.')),
      ),
    );
  }
}
