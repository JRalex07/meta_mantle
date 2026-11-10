# Build and Verification Status

This document reflects the verified status of the `meta_mantle` package (version `0.1.0`) as of 2026-11-10.

## Verified Environment

- **Official Repository:** [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
- **Official Documentation:** [https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)
- **Operating System:** Windows 10/11
- **Flutter SDK:** 3.47.5 (Channel stable)
- **Dart SDK:** 3.13.4
- **Browser:** Google Chrome 156.0.7118.0
- **Architecture Target:** Web (Native WebAssembly & JavaScript verified) + Non-Web cross-platform fallback

---

## Verification Test Matrix

| Command / Check | Working Directory | Result | Notes |
| :--- | :--- | :--- | :--- |
| `dart format --output=none --set-exit-if-changed .` | `.` (Root) | **PASS** (0 changed) | Clean formatting across all files |
| `flutter pub get` | `.` (Root) | **PASS** | Dependencies resolved |
| `flutter analyze` | `.` (Root) | **PASS** (0 issues) | Strict analysis enabled |
| `flutter test` | `.` (Root) | **PASS** (47/47 passing) | Unit, widget, lifecycle, title deduplication, static builder |
| `flutter pub get` | `example/` | **PASS** | Dependencies resolved |
| `flutter analyze` | `example/` | **PASS** (0 issues) | Example application clean |
| `flutter build web --release` | `example/` | **PASS** | JavaScript bundle built in `build/web` (52.2s) |
| `flutter build web --wasm` | `example/` | **PASS** | Native WebAssembly compiled (`main.dart.wasm`, 60.6s) |
| `flutter run -d chrome --wasm` | `example/` | **PASS** | Actual Wasm runtime compiled and loaded in Chrome (30.0s) |
| `dart run meta_mantle doctor` | `example/` | **PASS** | Preflight checks passed |
| `dart run meta_mantle inspect` | `example/` | **PASS** | 4 static routes resolved |
| `dart run meta_mantle build` | `example/` | **PASS** | Generated 6 static files for 4 routes |
| `Raw HTTP static inspection` | `localhost:8091` | **PASS** | Homepage `<title>` clean (no duplication), subpages templated |
| `dart pub publish --dry-run` | `.` (Root) | **PASS** (0 warnings) | Clean 45 KB package archive |

---

## Core Capabilities Verified

### 1. Title Resolution & Deduplication
- **Homepage Cleanliness:** Automatically detects when the page title matches `siteName`, `defaultTitle`, or the template's brand suffix, preventing duplicated titles (e.g., `<title>MetaMantle</title>`).
- **Normal Subpages:** Standard subpages correctly receive formatted titles (e.g., `<title>About Us | MetaMantle</title>`).
- **Pre-Templated Titles:** If a page title already ends with the template suffix, the template is not applied twice.
- **Opt-Out Control:** Respects `applyTitleTemplate: false`.

### 2. Native WebAssembly (Wasm) Support
- **Actual Wasm Compilation:** Verified `flutter build web --wasm` emits `main.dart.wasm` (1.6 MB).
- **Chrome Wasm Execution:** Verified interactive debugging and execution via `flutter run -d chrome --wasm`.
- **Pure Web Interop:** Uses modern `package:web` and `dart.library.js_interop` without deprecated `dart:html`, allowing frictionless execution in Wasm runtimes.

### 3. Router Integrations
- **Flutter Navigator:** `MetaMantleNavigatorObserver` synchronizes browser URL automatically.
- **GoRouter Integration:** Fully documented manual `MetaHead` wrapping pattern inside `GoRoute.builder`, avoiding fragile hard dependencies or version locks on `go_router`.

### 4. DOM Ownership & Isolation
- Injects `data-mm-owner="meta_mantle"` and `data-mm-key` attributes, safely adopting and restoring pre-existing head elements while never deleting unrelated third-party tags.

### 5. Static Route Generation (Engine B)
- HTML5 AST-based parsing via `package:html`.
- Preserves modern `flutter_bootstrap.js` and legacy `{{flutter_js}}` tokens.
- Generates compliant `sitemap.xml` and `robots.txt` referencing `https://metamantle.alex.runs-on.dev/`.

### 6. GitHub Actions CI/CD Pipeline Order & Formatting
- **Dependency Resolution Before Formatting:** CI workflow (`.github/workflows/ci.yml`) executes `flutter pub get` for root and `example/` prior to invoking `dart format --output=none --set-exit-if-changed .`, preventing `analysis_options.yaml` package resolution failures on `package:flutter_lints/flutter.yaml`.
- **Formatted Repository:** All 26 Dart files are strictly formatted according to Dart formatting standards (0 changed, clean exit code 0).
- **Separated Analysis & Test Execution:** Enforces sequential root dependency installation, example dependency installation, format verification, root analysis, example analysis, full unit/widget test suite, example release + wasm builds, static generation preflight, and package publication dry-run.

### 7. Strict Static SEO Validation
- **Complete Route Metadata:** All routes (including `/about`) define explicit titles and descriptions matching strict preflight validation rules.
- **Cupertino Icons Asset Resolution:** `cupertino_icons: ^1.0.8` is declared in `example/pubspec.yaml`, resolving Flutter framework Material fallback references and enabling clean font tree-shaking (99.4% reduction for `CupertinoIcons.ttf`, 99.5% for `MaterialIcons-Regular.otf`) with zero font asset warnings.


