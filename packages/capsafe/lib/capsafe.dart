library capsafe;

export 'src/domain/policy.dart';
export 'src/domain/events.dart';
export 'src/application/config.dart';
export 'src/presentation/secure_scope.dart';
export 'src/presentation/notifiers.dart';
export 'src/presentation/sensitive_area.dart';
export 'src/infrastructure/system_overlay_adapter.dart' show SystemOverlayAdapter;
export 'src/application/ports.dart' show PlatformPort, OverlayPort;

import 'src/application/config.dart';
import 'src/application/ports.dart';
import 'src/application/usecases.dart';
import 'src/infrastructure/platform_channel_adapter.dart';
import 'src/infrastructure/system_overlay_adapter.dart';

class Capsafe {
  Capsafe._();
  static final Capsafe instance = Capsafe._();

  late final PlatformPort _platform;
  late final OverlayPort _overlay;
  late final TelemetryPort _telemetry;
  late final UseCases _useCases;
  bool _configured = false;

  Future<void> configure(
    ScreenshotBlockerConfig config, {
    PlatformPort? platformOverride,
    OverlayPort? overlayOverride,
    TelemetryPort? telemetryOverride,
  }) async {
    if (_configured) return;
    _platform = platformOverride ?? PlatformChannelAdapter(config);
    _overlay = overlayOverride ?? SystemOverlayAdapter(config);
    _telemetry = telemetryOverride ?? config.telemetry;
    _useCases = UseCases(
      platform: _platform,
      overlay: _overlay,
      telemetry: _telemetry,
      config: config,
    );
    await _useCases.initialize();
    _configured = true;
  }

  UseCases get useCases {
    if (!_configured) {
      throw StateError(
        'Capsafe not configured. Call configure() during startup.',
      );
    }
    return _useCases;
  }
}
