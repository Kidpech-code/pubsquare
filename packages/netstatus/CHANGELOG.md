## 0.1.2

### Fixes

- Applied `dart format` to align with pub.dev formatter checks (no functional changes).

## 0.1.1

### Improvements

- Added comprehensive dartdoc for public API (enums, config fields, service methods) to improve pub score and developer experience.
- Fixed dangling library doc by adding `library netstatus;` and top-level docs on the public export.
- Updated `issue_tracker` in pubspec to a reachable URL.

No runtime behavior changes; API remains backward compatible.

## 0.1.0

**Initial Release**

### Features

- 🌐 **Unified Status Stream**: Single `Stream<NetStatus>` with `noNetwork`, `networkOnly`, `internet`
- 🔍 **Connection Type Detection**: `NetType` classification (wifi, mobile, ethernet, vpn, unknown)
- ⚙️ **Highly Configurable**: Ping URLs, timeouts, retries, throttling, backoff
- 🚀 **Multi-Platform**: Android, iOS, Web (with WASM), Windows, macOS, Linux
- 🔄 **Smart Fallbacks**: DNS fallback, image-ping for Web CORS, HEAD→GET fallback
- 🔋 **Energy Efficient**: Intelligent throttling, trailing recheck, periodic validation
- 🐛 **Developer Friendly**: Logging hooks, error capture, immediate status access

### Platform Support

- ✅ Android (with required permissions)
- ✅ iOS
- ✅ Web (CORS-aware with fallbacks, WASM compatible)
- ✅ Windows
- ✅ macOS
- ✅ Linux

### Dependencies

- `connectivity_plus: ^6.0.5` - Network state detection
- `http: ^1.2.2` - HTTP connectivity checks
- `web: ^1.1.0` - Modern web APIs (replaces deprecated dart:html)
- `meta: ^1.16.0` - Annotations
