# Installation Guide

This guide details how to install and configure **MetaMantle** in Flutter Web applications, pure Dart server applications, and local development workspaces.

---

## 1. Environment Requirements

- **Dart SDK:** `>=3.0.0 <4.0.0`
- **Flutter SDK:** `>=3.3.0` (Tested on Flutter 3.47.5+)
- **Platforms Supported:**
  - **Flutter Web:** Fully supported (JavaScript and WebAssembly / `dart2wasm`).
  - **Dart Server / VM:** Fully supported for Native SSR, static generation CLI, and caching.
  - **iOS / Android / macOS / Windows / Linux:** Compiles safely with zero-overhead no-op stubs.

---

## 2. Dependency Setup

### Recommended: Git Dependency (GitHub)
To install MetaMantle directly from the official GitHub repository, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  meta_mantle:
    git:
      url: https://github.com/JRalex07/meta_mantle.git
      ref: main # Or pin to a specific release tag such as v0.1.0
```

For pure Dart server applications (no Flutter dependencies), depend on the pure Dart entrypoint:
```yaml
dependencies:
  meta_mantle:
    git:
      url: https://github.com/JRalex07/meta_mantle.git
      ref: main
```

### Local Path Dependency
For monorepos or local package development:
```yaml
dependencies:
  meta_mantle:
    path: ../meta_mantle
```

Then resolve dependencies:
```bash
flutter pub get
# Or for pure Dart projects:
dart pub get
```

---

## 3. Public Entrypoints

MetaMantle exposes distinct libraries to prevent unnecessary dependency pollution:

```dart
// 1. Flutter Web Client Applications (Widgets & Reactive DOM)
import 'package:meta_mantle/meta_mantle.dart';

// 2. Pure Dart Server Applications (SSR, Caching, DB Providers, Security)
import 'package:meta_mantle/meta_mantle_server.dart';

// 3. Static Site Generation CLI & Builders
import 'package:meta_mantle/meta_mantle_builder.dart';

// 4. Pure Dart Core Models & Policy Primitives (Zero Flutter, Zero IO)
import 'package:meta_mantle/meta_mantle_core.dart';
```

---

## 4. Optional Framework Dependencies

If you are using optional server adapters or web frameworks:
- **Shelf Adapter:** Add `shelf: ^1.4.0` to your server project.
- **Jaspr Web Framework:** Add `jaspr: ^0.16.0` to your Jaspr project.

---

## 5. Troubleshooting Common Installation Issues

### 1. `dart:html` Deprecation Warnings
MetaMantle uses modern Wasm-ready `package:web` and `dart:js_interop`. It contains **zero** `dart:html` imports. If you see `dart:html` warnings in your build, inspect other third-party dependencies in your project.

### 2. CupertinoIcons Tree-Shaking Warning
In Flutter Web applications, if you receive a warning about CupertinoIcons missing during tree-shaking, ensure `cupertino_icons` is declared in your `pubspec.yaml`.

### 3. Git Authentication / Submodule Failures
Ensure your machine has network access to `https://github.com/JRalex07/meta_mantle.git`.
