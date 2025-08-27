class ScreenshotTaken {
  final String? routeName;
  final DateTime at;
  const ScreenshotTaken({this.routeName, required this.at});
}

class CaptureStateChanged {
  final bool isCaptured; // iOS: UIScreen.isCaptured
  final DateTime at;
  const CaptureStateChanged({required this.isCaptured, required this.at});
}
