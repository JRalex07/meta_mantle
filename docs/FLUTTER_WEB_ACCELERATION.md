# Flutter Web Acceleration & Optimization Guide

## Architecture Decision Record & Optimization Playbook (ADR-005)

**Status:** Production Ready  
**Target:** Flutter Web (Mode A: CanvasKit & Skwasm)  
**Author:** Principal Web-Platform Architect & Performance Specialist  
**Tooling:** `meta_mantle web analyze`, `meta_mantle web build`, `meta_mantle web report`  

---

## 1. Executive Summary

Flutter Web is an exceptional technology for canvas-based, high-fidelity user experiences that share pixel-perfect rendering with iOS, Android, and desktop. However, out-of-the-box Flutter Web applications frequently suffer from significant startup latency, heavy bundle payloads, and sub-optimal web server configuration.

MetaMantle provides **Mode A: Flutter Web Compatibility & Acceleration**, enabling engineering teams to maximize the performance of standard Flutter Web applications without sacrificing widgets or native architecture.

---

## 2. Core Flutter Web Performance Bottlenecks

### 2.1 The Two Compilation Models: CanvasKit vs Skwasm (`--wasm`)
In Flutter 3.22+, Flutter Web introduced the **Skwasm** renderer powered by Dart-to-Wasm (`dart2wasm`):
- **CanvasKit (JavaScript + Wasm Fallback):**
  - Compiles Dart to `main.dart.js` (~2.5 MB - 5 MB uncompressed).
  - Skia engine runs in a single-threaded WebAssembly module (`canvaskit.wasm`).
  - Lacks multi-threading; all rendering, layout, and application logic execute on the main browser thread.
- **Skwasm (Native Multi-Threaded Wasm):**
  - Compiles Dart directly to WebAssembly (`main.dart.wasm`) utilizing WasmGC.
  - Multi-threaded rendering using Web Workers and `SharedArrayBuffer`.
  - Achieves near-native framerates (60-120 FPS) and significantly reduced CPU overhead.
  - **Prerequisite:** Browser must be in a Cross-Origin Isolated state via COOP and COEP HTTP response headers.

### 2.2 Bootstrap Script Overhead
Older Flutter Web applications initialized via the monolithic `flutter.js` script. Flutter 3.22+ introduced `flutter_bootstrap.js`, which allows immediate pre-loading of engine artifacts, customizable loading spinners, and progressive engine initialization.

---

## 3. MetaMantle Acceleration Suite (`meta_mantle web`)

MetaMantle includes a dedicated CLI command suite to diagnose and accelerate Flutter Web applications:

### 3.1 Analyzing Web Project Health
```bash
dart run meta_mantle web analyze --project-dir .
```

The accelerator inspects:
1. **Wasm Readiness:** Scans `pubspec.yaml` and dependencies for legacy `dart:html` or `package:js` imports that block `dart2wasm` compilation.
2. **Modern Bootstrap:** Verifies whether `web/index.html` leverages `flutter_bootstrap.js` or outdated scripts.
3. **Resource Hints:** Audits `web/index.html` for `<link rel="preconnect">` and `<link rel="preload">` directives for fonts and CanvasKit CDN origins.
4. **Bundle Metrics:** Analyzes `build/web` to detect oversized JavaScript bundles (`main.dart.js > 2MB`), untruncated icon fonts, or unused assets.

Sample output:
```
=== Flutter Web Acceleration & Optimization Report ===

Project Type:      Flutter App
Wasm Supported:    Yes
Modern Bootstrap:  Yes (flutter_bootstrap.js)
Findings:          2

[WARNING] [bundle] Large JavaScript Bundle
  main.dart.js is 3.2 MB. This impacts initial mobile download time.
  Suggested Fix: Compile with "flutter build web --wasm" to leverage compact WebAssembly binaries.

[INFO] [wasm] WebAssembly Binary Available
  Native Wasm artifacts found in build/web. Ensure server emits COOP/COEP headers.
  Suggested Fix: Serve with Cross-Origin-Embedder-Policy: require-corp and Cross-Origin-Opener-Policy: same-origin.

Bundle Metrics:
  main.dart.wasm: 1,842.1 KB
  main.dart.js: 3,240.5 KB
  assets/FontManifest.json: 4.2 KB
  total_bundle_size: 6,420.8 KB
```

---

## 4. Production Deployment & Server Configuration

### 4.1 Cross-Origin Isolation Headers (Mandatory for Skwasm)
To execute multi-threaded Skwasm on web browsers, your hosting server (Shelf, Nginx, Cloudflare, Firebase Hosting) must emit these exact headers:

```http
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
Cache-Control: public, max-age=3600
X-Content-Type-Options: nosniff
```

#### Shelf Server Middleware Example:
```dart
import 'package:shelf/shelf.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

Handler addSkwasmHeaders(Handler innerHandler) {
  const accelerator = FlutterWebAccelerator();
  final headers = accelerator.getRecommendedServerHeaders();

  return (Request request) async {
    final response = await innerHandler(request);
    return response.change(headers: headers);
  };
}
```

### 4.2 Optimized Flutter CLI Build Command
Run:
```bash
dart run meta_mantle web build
```

Recommended production invocation:
```bash
flutter build web --wasm --tree-shake-icons --release
```

- `--wasm`: Emits compact, multi-threaded WebAssembly binaries.
- `--tree-shake-icons`: Removes unused glyphs from Material and Cupertino icon font files, shaving hundreds of kilobytes off initial asset downloads.

