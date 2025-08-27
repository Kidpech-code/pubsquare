import 'dart:io';
import 'package:flutter/material.dart';
import '../../capsafe.dart';

class SensitiveArea extends StatefulWidget {
  final Widget child;
  const SensitiveArea({super.key, required this.child});
  @override
  State<SensitiveArea> createState() => _SensitiveAreaState();
}

class _SensitiveAreaState extends State<SensitiveArea> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return widget.child; // Android is blocked globally via FLAG_SECURE
    }
    return ValueListenableBuilder<bool>(
      valueListenable: Capsafe.instance.useCases.sensitiveObscured,
      builder: (context, obscured, child) {
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            if (obscured) Positioned.fill(child: _mask()),
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _mask() {
    switch (Capsafe.instance.useCases.config.ios.overlayStyle) {
      case IosOverlayStyle.black:
        return Container(color: Colors.black.withValues(alpha: 0.75));
      case IosOverlayStyle.blur:
        return Container(
          color: Colors.black26,
        ); // local blur is expensive; keep simple for areas
      case IosOverlayStyle.watermark:
        return Container(color: Colors.black45);
    }
  }
}
