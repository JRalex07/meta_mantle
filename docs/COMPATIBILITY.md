# Compatibility & Environment Matrix

MetaMantle is engineered to support both modern Flutter Web compilation targets and headless Dart server runtimes.

---

## 1. Supported SDK & Runtime Targets

| Target | Supported Version | Notes |
|---|---|---|
| **Dart SDK** | `>= 3.6.0 < 4.0.0` | Uses modern patterns, records, and sound null safety. |
| **Flutter SDK** | `>= 3.27.0` | Compatible with latest Flutter stable. |
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

