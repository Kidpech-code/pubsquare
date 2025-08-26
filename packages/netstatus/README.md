# netstatus

Unified network + real internet status as a single Dart Stream. Multi-platform (Android, iOS, Web, Desktop), configurable ping, retry/timeout, and connection type. Pure Dart Streams with advanced mitigations for production use.

## Key Features

- **Single Stream API**: `Stream<NetStatus>` with values: `noNetwork`, `networkOnly`, `internet`
- **Connection Classification**: `NetType` detection (wifi, mobile, ethernet, vpn, unknown)
- **Multi-Platform**: Android, iOS, Web, Desktop via `connectivity_plus` + HTTP/DNS checks
- **Production Ready**: Configurable timeouts, retries, backoff, throttling, and fallbacks
- **Web Optimized**: CORS-aware with image-ping fallback, multiple endpoint support
- **Energy Efficient**: Smart throttling, trailing recheck, optional periodic validation
- **Developer Friendly**: Logging hooks, error capture, immediate status access

## Why netstatus?

Unlike basic connectivity checkers, netstatus distinguishes between **network presence** and **actual internet access**:

- `noNetwork`: No network interface available
- `networkOnly`: Connected to network but no internet (captive portal, WAN down, etc.)
- `internet`: Full internet connectivity confirmed via HTTP/DNS

Perfect for apps that need reliable connectivity detection across all platforms.

## Quick Start

Add to `pubspec.yaml`:

```yaml
dependencies:
  netstatus: ^0.1.1
```

Basic usage:

```dart
import 'package:netstatus/netstatus.dart';

final service = NetStatusService();

// Listen to status changes
service.observeNetStatus().listen((status) {
  switch (status) {
    case NetStatus.noNetwork:
      print('No network connection');
    case NetStatus.networkOnly:
      print('Connected but no internet');
    case NetStatus.internet:
      print('Full internet access');
  }
});

// Get current status immediately
final current = await service.checkNow();
final connectionType = await service.getCurrentNetType();

// Clean up
service.dispose();
```

## Advanced Configuration

```dart
final service = NetStatusService(
  NetCheckConfig(
    // Multiple endpoints for reliability
    pingUrls: const [
      Uri.parse('https://clients3.google.com/generate_204'),
      Uri.parse('https://cloudflare.com/cdn-cgi/trace'),
    ],

    // Strict 2xx responses only (avoid captive portal false positives)
    expectedStatusLowerBound: 200,
    expectedStatusUpperBound: 299,

    // Energy efficient settings
    minIntervalBetweenChecks: const Duration(seconds: 10),
    retry: 2,
    retryBackoffMultiplier: 2.0,

    // Advanced features
    enableDnsFallback: true,
    dnsSuccessIsInternet: false, // Keep strict
    enablePeriodicRecheck: true,
    periodicInterval: const Duration(minutes: 1),

    // Debugging
    onLog: (message) => debugPrint('[NetStatus] $message'),
    onError: (error, stack) => debugPrint('NetStatus Error: $error'),
  ),
);

// Stream with immediate last value for new listeners
service.observeNetStatusWithInitial().listen((status) {
  // Receives last known status immediately, then updates
});
```

## Configuration Options

| Option                      | Type         | Default                   | Description                          |
| --------------------------- | ------------ | ------------------------- | ------------------------------------ |
| `pingUrl`                   | Uri          | Google 204                | Single endpoint to check             |
| `pingUrls`                  | List<Uri>?   | null                      | Multiple endpoints (tries in order)  |
| `pingMethod`                | String       | 'HEAD'                    | HTTP method ('HEAD' or 'GET')        |
| `timeout`                   | Duration     | 2s                        | Request timeout                      |
| `retry`                     | int          | 1                         | Number of retries                    |
| `retryDelay`                | Duration     | 500ms                     | Base delay between retries           |
| `retryBackoffMultiplier`    | double?      | null                      | Exponential backoff (e.g., 2.0)      |
| `minIntervalBetweenChecks`  | Duration     | 5s                        | Throttle interval                    |
| `allowMobile`               | bool         | true                      | Allow internet checks on mobile      |
| `expectedStatusLowerBound`  | int          | 200                       | Min HTTP status for success          |
| `expectedStatusUpperBound`  | int          | 299                       | Max HTTP status for success          |
| `expectedBodyContains`      | String?      | null                      | Required substring in response       |
| `maxBodyBytes`              | int          | 2048                      | Max bytes to read when checking body |
| `emitNetworkOnlyBeforePing` | bool         | true                      | Quick UI feedback                    |
| `enablePeriodicRecheck`     | bool         | false                     | Background validation                |
| `periodicInterval`          | Duration     | 30s                       | How often to recheck                 |
| `enableDnsFallback`         | bool         | false                     | Try DNS if HTTP fails                |
| `dnsHosts`                  | List<String> | ['1.1.1.1', 'dns.google'] | DNS hosts to resolve                 |
| `dnsSuccessIsInternet`      | bool         | false                     | Whether DNS success = internet       |
| `trailingRecheck`           | bool         | true                      | Recheck after throttle period        |
| `onLog`                     | Function?    | null                      | Logging callback                     |
| `onError`                   | Function?    | null                      | Error callback                       |

## Platform-Specific Notes

### Web

- CORS may block cross-origin requests
- Image-ping fallback automatically attempted on CORS failures
- No DNS fallback available (browser limitation)
- Configure `pingUrls` to CORS-enabled endpoints or your own domain

### Android

Required permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Optional for enhanced detection:

```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

### iOS/Desktop

No special configuration required. Uses standard network APIs.

## Web CORS Solutions

Express (Node.js)

```js
// server.js
const express = require("express");
const app = express();

app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

app.head("/ping", (req, res) => res.sendStatus(204));
app.get("/ping", (req, res) => res.sendStatus(204));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log("ping on :" + port));
```

Cloudflare Worker

```js
export default {
  async fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === "/ping") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET,HEAD,OPTIONS",
        },
      });
    }
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET,HEAD,OPTIONS",
        },
      });
    }
    return new Response("ok", { status: 200 });
  },
};
```

Then set in Flutter:

```dart
final service = NetStatusService(NetCheckConfig(
  pingUrl: Uri.parse('https://your-domain.example/ping'),
  pingMethod: 'HEAD',
));
```

## Production Best Practices

### Energy & Data Optimization

```dart
NetCheckConfig(
  minIntervalBetweenChecks: const Duration(minutes: 1), // Reduce frequency
  retry: 1, // Minimize failed attempts
  enablePeriodicRecheck: false, // Disable background checks
  retryBackoffMultiplier: 2.0, // Exponential backoff
)
```

### Reliability & Accuracy

```dart
NetCheckConfig(
  pingUrls: [
    Uri.parse('https://your-api.com/health'), // Your own endpoint
    Uri.parse('https://cloudflare.com/cdn-cgi/trace'),
  ],
  expectedBodyContains: 'ok', // Validate response content
  enableDnsFallback: true,
  dnsSuccessIsInternet: false, // Keep strict validation
)
```

### Development & Debugging

```dart
NetCheckConfig(
  onLog: (msg) => debugPrint('[NetStatus] $msg'),
  onError: (error, stack) => logger.error('NetStatus', error, stack),
  minIntervalBetweenChecks: const Duration(seconds: 2), // Faster feedback
)
```

### Enterprise/Privacy Focused

```dart
NetCheckConfig(
  pingUrls: [
    Uri.parse('https://internal-health.company.com/ping'),
  ],
  enableDnsFallback: false, // Avoid external DNS queries
  allowMobile: false, // WiFi only for cost control
)
```

## Common Patterns

### React to Connectivity Changes

```dart
StreamSubscription? _netSub;

@override
void initState() {
  super.initState();
  _netSub = netService.observeNetStatus().listen((status) {
    switch (status) {
      case NetStatus.noNetwork:
        showSnackBar('No internet connection');
      case NetStatus.networkOnly:
        showSnackBar('Limited connectivity - some features unavailable');
      case NetStatus.internet:
        hideConnectivityWarnings();
    }
  });
}

@override
void dispose() {
  _netSub?.cancel();
  netService.dispose();
  super.dispose();
}
```

### Conditional API Calls

```dart
Future<void> syncData() async {
  final status = await netService.checkNow();

  if (status == NetStatus.internet) {
    await api.uploadPendingData();
    await api.downloadUpdates();
  } else if (status == NetStatus.networkOnly) {
    // Maybe try cached/local operations
    showRetryOption();
  } else {
    showOfflineMessage();
  }
}
```

### Background Monitoring

```dart
final service = NetStatusService(
  NetCheckConfig(
    enablePeriodicRecheck: true,
    periodicInterval: const Duration(minutes: 5),
    onLog: (msg) => debugPrint(msg),
  ),
);

// Automatic background validation - useful for long-running apps
```

## Troubleshooting

**Q: Getting `networkOnly` but internet works in browser?**
A: Likely a captive portal or the ping endpoint is blocked. Try:

- Set `pingUrls` to a different endpoint you control
- Enable `onLog` to see what's failing
- Check if `expectedBodyContains` is too strict

**Q: High battery/data usage?**
A: Tune throttling and retries:

- Increase `minIntervalBetweenChecks`
- Reduce `retry` count
- Disable `enablePeriodicRecheck` if not needed
- Set `retryBackoffMultiplier: 2.0`

**Q: Web CORS errors?**
A: Use your own endpoint or known CORS-friendly URLs:

```dart
pingUrls: [
  Uri.parse('https://httpbin.org/status/204'), // CORS-enabled
  Uri.parse('https://your-domain.com/ping'),
]
```

**Q: Inconsistent `NetType` detection?**
A: This is limited by the underlying OS/browser APIs. `connectivity_plus` does its best but VPNs, complex network setups, etc. may not be perfectly classified.

## API Reference

### NetStatusService

| Method                          | Returns             | Description                     |
| ------------------------------- | ------------------- | ------------------------------- |
| `observeNetStatus()`            | `Stream<NetStatus>` | Deduplicated status updates     |
| `observeNetStatusWithInitial()` | `Stream<NetStatus>` | Include last status immediately |
| `checkNow()`                    | `Future<NetStatus>` | Force immediate check           |
| `getCurrentNetType()`           | `Future<NetType>`   | Get connection type             |
| `lastStatus`                    | `NetStatus?`        | Last known status (sync)        |
| `lastCheckTime`                 | `DateTime`          | When last check occurred        |
| `dispose()`                     | `void`              | Clean up resources              |

### Enums

**NetStatus**

- `noNetwork`: No network interface
- `networkOnly`: Network but no internet
- `internet`: Full internet access

**NetType**

- `unknown`: Cannot determine
- `wifi`: WiFi connection
- `mobile`: Cellular data
- `ethernet`: Wired connection
- `vpn`: VPN detected

## Android permissions

Ensure you have:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Optionally:

```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

## License

MIT
