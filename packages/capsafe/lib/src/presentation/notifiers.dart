import 'package:flutter/material.dart';

class ScreenshotNotifier {
  static void showInfoBanner(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('เพื่อความปลอดภัย บางหน้าจออาจจำกัดการจับภาพหน้าจอ'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
