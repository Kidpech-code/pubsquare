// Core implementation: unified network+internet status with configurable checks.
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dns_fallback_stub.dart' if (dart.library.io) 'dns_fallback_io.dart'
    as dns;
import 'image_ping_stub.dart' if (dart.library.html) 'image_ping_web.dart'
    as webping;

/// Overall network status combining link presence and true Internet reachability.
///
/// - [noNetwork]: No network interfaces are available.
/// - [networkOnly]: A local link exists (e.g., Wi‑Fi/cellular) but Internet could not be verified.
/// - [internet]: Internet connectivity verified by the configured checks.
enum NetStatus { noNetwork, networkOnly, internet }

/// The current connection type derived from connectivity signals.
enum NetType { unknown, wifi, mobile, ethernet, vpn }

/// Configuration for Internet reachability checks and behavior tuning.
///
/// Most apps can use the defaults. For stricter validation, provide multiple
/// [pingUrls], narrow the accepted status range, or require [expectedBodyContains].
class NetCheckConfig {
  /// Primary URL used to probe Internet reachability when [pingUrls] is not set.
  final Uri pingUrl;

  /// Optional list of URLs to try in order; the first success short‑circuits.
  final List<Uri>? pingUrls; // optional: try multiple endpoints in order
  /// HTTP method used for the first attempt; typically "HEAD" or "GET".
  final String pingMethod; // "HEAD" or "GET"
  /// Request timeout per attempt.
  final Duration timeout;

  /// Number of retry attempts after the initial try.
  final int retry;

  /// Base delay between retries.
  final Duration retryDelay;

  /// Minimum interval between checks to throttle energy/data usage.
  final Duration minIntervalBetweenChecks; // throttle
  /// If false, treat mobile networks as [NetStatus.networkOnly] for policy reasons.
  final bool allowMobile; // if false, treat mobile as networkOnly
  /// On Web, leverage navigator.onLine hints via connectivity_plus.
  final bool
      enableWebNavigatorOnline; // web hint (handled by connectivity_plus under the hood)
  /// Inclusive lower bound for accepted HTTP status codes (default 200).
  final int expectedStatusLowerBound; // default 200
  /// Inclusive upper bound for accepted HTTP status codes (default 299).
  final int expectedStatusUpperBound; // default 399
  /// Optional substring that must appear in the response body.
  /// Useful to guard against captive portals returning 2xx with HTML login pages.
  final String?
      expectedBodyContains; // optional body substring to assert real internet (captive portal guard)
  /// Max bytes to read from the body when [expectedBodyContains] is used.
  final int maxBodyBytes; // limit body bytes to read when checking body
  /// Factory for a custom HTTP client (testing or proxying).
  final http.Client Function()? httpClientFactory; // for testing/customization
  /// Emit [NetStatus.networkOnly] immediately before HTTP checks complete.
  final bool emitNetworkOnlyBeforePing; // fast UI feedback
  /// Enable periodic rechecks even when connectivity signals don't change.
  final bool
      enablePeriodicRecheck; // optional periodic recheck when network present
  /// Interval for periodic rechecks.
  final Duration periodicInterval; // periodic recheck interval
  /// Attempt DNS lookups if HTTP checks fail.
  final bool enableDnsFallback; // try DNS lookup if HTTP fails
  /// Hostnames to resolve during DNS fallback.
  final List<String> dnsHosts; // hosts to resolve for DNS fallback
  /// If throttled, queue one trailing recheck.
  final bool trailingRecheck; // queue one trailing check if throttled
  /// Exponential backoff multiplier (>1.0) applied to [retryDelay].
  final double? retryBackoffMultiplier; // exponential backoff multiplier
  /// If true, successful DNS-only checks count as Internet; else remain networkOnly.
  final bool
      dnsSuccessIsInternet; // if true, DNS-only success counts as Internet; else stays networkOnly
  /// Optional lightweight logging hook.
  final void Function(String message)?
      onLog; // optional lightweight logging hook
  /// Optional error hook capturing exceptions during checks.
  final void Function(Object error, StackTrace stack)?
      onError; // optional error hook

  /// Creates a [NetCheckConfig]. Most fields have sensible defaults.
  NetCheckConfig({
    Uri? pingUrl,
    this.pingUrls,
    this.pingMethod = 'HEAD',
    this.timeout = const Duration(seconds: 2),
    this.retry = 1,
    this.retryDelay = const Duration(milliseconds: 500),
    this.minIntervalBetweenChecks = const Duration(seconds: 5),
    this.allowMobile = true,
    this.enableWebNavigatorOnline = true,
    this.expectedStatusLowerBound = 200,
    this.expectedStatusUpperBound = 299,
    this.expectedBodyContains,
    this.maxBodyBytes = 2048,
    this.httpClientFactory,
    this.emitNetworkOnlyBeforePing = true,
    this.enablePeriodicRecheck = false,
    this.periodicInterval = const Duration(seconds: 30),
    this.enableDnsFallback = false,
    this.dnsHosts = const ['one.one.one.one', 'dns.google'],
    this.trailingRecheck = true,
    this.retryBackoffMultiplier,
    this.dnsSuccessIsInternet = false,
    this.onLog,
    this.onError,
  }) : pingUrl = pingUrl ?? _kDefaultPingUrl;
}

/// Service that exposes a unified stream of [NetStatus] changes.
///
/// The service listens to connectivity changes and performs lightweight
/// Internet reachability checks with configurable fallbacks.
class NetStatusService {
  /// Active configuration for checks and behavior.
  final NetCheckConfig config;
  final _controller = StreamController<NetStatus>.broadcast();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  NetStatus? _lastStatus;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;
  bool _checking = false;
  Timer? _periodicTimer;
  bool _trailingRequested = false;

  // Optional injection for tests
  final Stream<List<ConnectivityResult>>? _customConnectivityStream;
  final Future<List<ConnectivityResult>> Function()? _customConnectivityCheck;

  NetStatusService([
    NetCheckConfig? config,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
  ])  : config = config ?? NetCheckConfig(),
        _customConnectivityStream = connectivityStream,
        _customConnectivityCheck = connectivityCheck {
    _start();
  }

  /// Broadcast stream of [NetStatus] changes, deduplicated.
  Stream<NetStatus> observeNetStatus() => _controller.stream.distinct();

  Future<void> _start() async {
    // connectivity_plus on web already leverages navigator.onLine; we keep a single code path.
    final stream =
        _customConnectivityStream ?? _connectivity.onConnectivityChanged;
    _connectivitySub = stream.listen((results) {
      _onConnectivityChanged(results);
    });
    final initial = await (_customConnectivityCheck != null
        ? _customConnectivityCheck!()
        : _connectivity.checkConnectivity());
    // Kick an initial evaluation (forced, bypass throttle at startup).
    unawaited(_onConnectivityChanged(initial, forced: true));

    // Optional periodic recheck (covers WAN down while link stays up)
    if (config.enablePeriodicRecheck) {
      _periodicTimer?.cancel();
      _periodicTimer = Timer.periodic(config.periodicInterval, (_) async {
        if (_disposed) return;
        final r = await (_customConnectivityCheck != null
            ? _customConnectivityCheck!()
            : _connectivity.checkConnectivity());
        await _onConnectivityChanged(r, forced: true);
      });
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results,
      {bool forced = false}) async {
    if (_disposed) return;

    // Throttle pinging to save battery/data.
    final now = DateTime.now();
    // Throttle pinging to save battery/data; optionally queue a trailing check.
    final sinceLast = now.difference(_lastCheck);
    if (!forced && sinceLast < config.minIntervalBetweenChecks) {
      if (config.trailingRecheck && !_trailingRequested) {
        _trailingRequested = true;
        final dueIn = config.minIntervalBetweenChecks - sinceLast;
        Timer(dueIn, () {
          if (_trailingRequested && !_disposed) {
            _trailingRequested = false;
            // Fetch fresh connectivity snapshot for trailing recheck
            Future(() async {
              final r = await (_customConnectivityCheck != null
                  ? _customConnectivityCheck!()
                  : _connectivity.checkConnectivity());
              unawaited(_onConnectivityChanged(r, forced: true));
            });
          }
        });
      }
      return;
    }
    _lastCheck = now;

    if (_isNoNetwork(results)) {
      _emit(NetStatus.noNetwork);
      return;
    }

    final type = _pickNetType(results);
    if (!config.allowMobile && type == NetType.mobile) {
      _emit(NetStatus.networkOnly);
      return;
    }

    // Optionally emit networkOnly immediately for quick UI reaction.
    if (config.emitNetworkOnlyBeforePing) {
      _emit(NetStatus.networkOnly);
    }

    // Avoid overlapping pings.
    if (_checking) return;
    _checking = true;
    final ok = await _checkInternet();
    _checking = false;
    _emit(ok ? NetStatus.internet : NetStatus.networkOnly);
  }

  /// Forces an immediate evaluation and returns the resulting [NetStatus].
  Future<NetStatus> checkNow() async {
    final r = await (_customConnectivityCheck != null
        ? _customConnectivityCheck!()
        : _connectivity.checkConnectivity());
    await _onConnectivityChanged(r, forced: true);
    return _lastStatus ?? NetStatus.noNetwork;
  }

  /// Returns the current [NetType] based on connectivity signals.
  Future<NetType> getCurrentNetType() async {
    final r = await (_customConnectivityCheck != null
        ? _customConnectivityCheck!()
        : _connectivity.checkConnectivity());
    return _pickNetType(r);
  }

  bool _isNoNetwork(List<ConnectivityResult> results) {
    return results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none);
  }

  NetType _pickNetType(List<ConnectivityResult> results) {
    if (_isNoNetwork(results)) return NetType.unknown;
    if (results.contains(ConnectivityResult.wifi)) return NetType.wifi;
    if (results.contains(ConnectivityResult.ethernet)) return NetType.ethernet;
    if (results.contains(ConnectivityResult.mobile)) return NetType.mobile;
    if (results.contains(ConnectivityResult.vpn)) return NetType.vpn;
    return NetType.unknown;
  }

  Future<bool> _checkInternet() async {
    config.onLog?.call('[netstatus] check start');
    // Attempt with retry (single client per check for efficiency)
    final client = (config.httpClientFactory ?? () => http.Client())();
    final urls = (config.pingUrls != null && config.pingUrls!.isNotEmpty)
        ? config.pingUrls!
        : <Uri>[config.pingUrl];
    try {
      var delay = config.retryDelay;
      for (var attempt = 0; attempt <= config.retry; attempt++) {
        try {
          // Try each URL in order for this attempt; short-circuit when any succeeds.
          for (final url in urls) {
            // First try configured method
            final ok =
                await _tryPing(client, method: config.pingMethod, url: url);
            if (ok == true) {
              config.onLog
                  ?.call('[netstatus] HTTP OK via ${config.pingMethod} $url');
              return true;
            }

            // If HEAD is configured and failed (e.g., 405/501), try GET fallback once per URL
            if (config.pingMethod.toUpperCase() == 'HEAD') {
              final fallbackOk =
                  await _tryPing(client, method: 'GET', url: url);
              if (fallbackOk == true) {
                config.onLog?.call('[netstatus] GET fallback OK $url');
                return true;
              }
            }

            // On web, attempt image ping as a CORS-agnostic fallback for this URL
            final imageOk = await webping.imagePing(url, config.timeout);
            if (imageOk) {
              config.onLog?.call('[netstatus] image ping OK $url');
              return true;
            }
          }
        } catch (e, st) {
          config.onError?.call(e, st);
        }
        if (attempt < config.retry) {
          await Future.delayed(delay);
          if (config.retryBackoffMultiplier != null &&
              config.retryBackoffMultiplier! > 1.0) {
            final nextMs =
                (delay.inMilliseconds * config.retryBackoffMultiplier!).toInt();
            delay = Duration(milliseconds: nextMs.clamp(1, 60000));
          }
        }
      }
    } finally {
      client.close();
    }
    // Optional DNS fallback if HTTP path failed
    if (config.enableDnsFallback) {
      try {
        final ok = await dns.performDnsLookup(config.dnsHosts, config.timeout);
        if (ok) {
          config.onLog?.call(
              '[netstatus] DNS fallback ${config.dnsHosts} => ${config.dnsSuccessIsInternet ? 'internet' : 'networkOnly'}');
          if (config.dnsSuccessIsInternet) return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Last observed [NetStatus] without forcing a new check.
  NetStatus? get lastStatus => _lastStatus;

  /// Timestamp of the last check.
  DateTime get lastCheckTime => _lastCheck;

  Future<bool> _tryPing(http.Client client,
      {required String method, required Uri url}) async {
    final req = http.Request(method.toUpperCase(), url);
    req.headers.addAll(<String, String>{
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'User-Agent': 'netstatus/0.1',
    });
    final res = await client.send(req).timeout(config.timeout);
    final status = res.statusCode;
    final statusOk = status >= config.expectedStatusLowerBound &&
        status <= config.expectedStatusUpperBound;
    if (!statusOk) return false;

    // If body content is required (captive portal guard), sample up to maxBodyBytes
    if (config.expectedBodyContains != null) {
      final buf = <int>[];
      final sub = res.stream.take(config.maxBodyBytes).listen(buf.addAll);
      await sub.asFuture<void>();
      final body = String.fromCharCodes(buf);
      return body.contains(config.expectedBodyContains!);
    }
    return true;
  }

  /// Emits the last known status immediately (if any) then continues streaming updates.
  Stream<NetStatus> observeNetStatusWithInitial() async* {
    if (_lastStatus != null) yield _lastStatus!;
    yield* observeNetStatus();
  }

  void _emit(NetStatus s) {
    if (_lastStatus != s && !_disposed) {
      _lastStatus = s;
      _controller.add(s);
    }
  }

  /// Releases resources and stops background timers/subscriptions.
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    _controller.close();
    _periodicTimer?.cancel();
  }
}

// Defaults and helpers
final Uri _kDefaultPingUrl =
    Uri.parse('https://clients3.google.com/generate_204');
