import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../application/config.dart';
import '../application/ports.dart';

class SystemOverlayAdapter implements OverlayPort {
  final ScreenshotBlockerConfig config;
  static final _overlayKey = GlobalKey<_GlobalOverlayState>();

  SystemOverlayAdapter(this.config);

  @override
  void showCapturedOverlay(bool show, IosOverlayStyle style) {
    _overlayKey.currentState?._setCapturedOverlay(show: show, style: style);
  }

  @override
  void showAppSwitcherPrivacy(bool show) {
    _overlayKey.currentState?._setAppSwitcherPrivacy(show);
  }

  @override
  void showUxBanner(dynamic context, UxCopy copy) {
    if (context is BuildContext && config.ux.showFirstTimeBanner) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(copy.message),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void showWatermark(bool show) {
    _overlayKey.currentState?._setWatermark(show);
  }

  static Widget wrapApp({required Widget child}) {
    return _GlobalOverlay(key: _overlayKey, child: child);
  }
}

class _GlobalOverlay extends StatefulWidget {
  final Widget child;
  const _GlobalOverlay({super.key, required this.child});
  @override
  State<_GlobalOverlay> createState() => _GlobalOverlayState();
}

class _GlobalOverlayState extends State<_GlobalOverlay> {
  bool _showCapturedOverlay = false;
  bool _showWatermark = false;
  IosOverlayStyle _style = IosOverlayStyle.black;

  void _setCapturedOverlay({
    required bool show,
    required IosOverlayStyle style,
  }) {
    if (!Platform.isIOS) return;
    setState(() {
      _showCapturedOverlay = show;
      _style = style;
    });
  }

  void _setAppSwitcherPrivacy(bool show) {
    if (!Platform.isIOS) return;
    // Visual privacy overlay is optional; native snapshot privacy handled in iOS plugin.
  }

  void _setWatermark(bool show) {
    setState(() {
      _showWatermark = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overlays = <Widget>[];

    if (_showCapturedOverlay) {
      overlays.add(Positioned.fill(child: _buildStyle()));
    }

    if (_showWatermark) {
      overlays.add(
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              painter: _WatermarkPainter(text: 'Sensitive • ${DateTime.now()}'),
            ),
          ),
        ),
      );
    }

    // _showPrivacyOverlay is visual only. Real snapshot privacy is handled natively.
    return Stack(fit: StackFit.expand, children: [widget.child, ...overlays]);
  }

  Widget _buildStyle() {
    switch (_style) {
      case IosOverlayStyle.black:
        return Container(color: Colors.black);
      case IosOverlayStyle.blur:
        return Container(
          color: Colors.black26,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: const SizedBox.expand(),
          ),
        );
      case IosOverlayStyle.watermark:
        return Container(color: Colors.black45);
    }
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    const step = 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.5); // diagonal
    canvas.translate(-size.width / 2, -size.height / 2);

    for (double y = 0; y < size.height + step; y += step) {
      for (double x = -100; x < size.width + step; x += step) {
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) => oldDelegate.text != text;
}
