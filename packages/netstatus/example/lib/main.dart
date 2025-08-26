import 'dart:async';
import 'package:flutter/material.dart';
import 'package:netstatus/netstatus.dart';

void main() {
  runApp(const MaterialApp(home: DemoPage()));
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final NetStatusService service;
  NetStatus status = NetStatus.noNetwork;
  NetType type = NetType.unknown;
  StreamSubscription<NetStatus>? sub;

  @override
  void initState() {
    super.initState();
    service = NetStatusService();
    sub = service.observeNetStatus().listen((s) async {
      final t = await service.getCurrentNetType();
      if (!mounted) return;
      setState(() {
        status = s;
        type = t;
      });
    });
    service.checkNow();
  }

  @override
  void dispose() {
    sub?.cancel();
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('netstatus example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Status: $status'),
            Text('Type:   $type'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final s = await service.checkNow();
                final t = await service.getCurrentNetType();
                if (!mounted) return;
                setState(() {
                  status = s;
                  type = t;
                });
              },
              child: const Text('Check now'),
            ),
          ],
        ),
      ),
    );
  }
}
