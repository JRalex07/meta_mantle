# Compatibility & Environment Matrix

MetaMantle is engineered to support both modern Flutter Web compilation targets and headless Dart server runtimes.

The server/core source entrypoints avoid Flutter imports, but the root package manifest declares Flutter as an SDK dependency. Therefore Dart SDK-only dependency resolution is not currently supported by this package distribution.

---

## 1. Supported SDK & Runtime Targets

| Target | Supported Version | Notes |
|---|---|---|
| **Dart SDK** | `>= 3.13.0 < 4.0.0` | Uses modern patterns, records, and sound null safety. |
| **Flutter SDK** | `>= 3.47.0` | Compatible with latest Flutter stable. |
| **Flutter WebAssembly (Wasm)** | Fully Supported | Uses `package:web` and `dart:js_interop`. Zero `dart:html` legacy code. |
| **Flutter CanvasKit / HTML** | Fully Supported | Standard web client builds. |
| **Dart Server (AOT / JIT)** | Fully Supported | Compiles to native binaries (`dart compile exe`) and Docker containers. |
| **Shelf Ecosystem** | `^1.4.1` | Native handler and middleware interoperability. |

---

## 2. Browser Compatibility Matrix

MetaMantle Runtime works across all modern browsers:
- Google Chrome / Chromium (`>= 90`)
- Mozilla Firefox (`>= 90`)
- Apple Safari & iOS Safari (`>= 15`)
- Microsoft Edge (`>= 90`)
- Android Chrome & Mobile WebViews

---

## 3. UI Framework & Material Compatibility

- **Material UI:** Migrated to standalone `package:material_ui/material_ui.dart` (`^1.11.0`), eliminating deprecated `package:flutter/material.dart` references on Flutter 3.47+ / 3.50+ toolchains.
- **Flutter Islands Multi-View:** Strategy C (`dom-with-flutter-islands`) leverages Flutter's native multi-view embedding API (`multiViewEnabled: true`, `app.addView({ hostElement })`, and `app.removeView(viewId)`).
- **Sitemap Protocol Limits:** Full compliance with the sitemaps.org protocol, enforcing both the 50,000 URL limit and the 50 MB (`52,428,800` bytes) uncompressed UTF-8 size limit.


