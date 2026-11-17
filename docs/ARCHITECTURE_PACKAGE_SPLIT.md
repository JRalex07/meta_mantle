# Architecture Proposal: Clean Package Split for Pure-Dart SDK Environments

## 1. Executive Summary

MetaMantle currently provides pure-Dart libraries (`meta_mantle_core.dart` and `meta_mantle_server.dart`) that contain zero imports of Flutter, `dart:ui`, or Flutter widgets at runtime. However, because the root `meta_mantle` package manifest (`pubspec.yaml`) includes:

```yaml
dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.0
```

any consumer attempting to resolve dependencies with `dart pub get` in an environment without the Flutter SDK installed will experience dependency resolution failure.

This document outlines the proposed architectural transition to a **multi-package monorepo workspace**, enabling standalone Dart servers, headless CLIs, and backend microservices to install MetaMantle via `dart pub add` without requiring the Flutter SDK, while preserving 100% backward compatibility for existing Flutter Web consumers.

---

## 2. Current State vs. Proposed Architecture

### Current State (Single Monolithic Package)

```
meta_mantle (Root Package)
├── lib/
│   ├── meta_mantle.dart            (Depends on Flutter SDK & material_ui)
│   ├── meta_mantle_core.dart       (Pure Dart runtime, but blocked by pubspec)
│   ├── meta_mantle_server.dart     (Pure Dart runtime, but blocked by pubspec)
│   ├── meta_mantle_builder.dart    (Pure Dart runtime, but blocked by pubspec)
│   └── meta_mantle_universal.dart  (Pure Dart runtime, but blocked by pubspec)
└── pubspec.yaml                    (Requires Flutter SDK)
```

- **Limitation:** Headless Dart microservices, pure Shelf servers, and CI runners without Flutter cannot run `dart pub get`.

---

### Proposed Future Architecture (Clean Three-Package Split)

```
packages/
├── meta_mantle_core/             (Pure Dart Package - ZERO Flutter Dependencies)
│   ├── lib/
│   │   ├── meta_mantle_core.dart
│   │   ├── meta_mantle_server.dart
│   │   ├── meta_mantle_builder.dart
│   │   └── meta_mantle_universal.dart
│   └── pubspec.yaml              (environment: sdk: '>=3.13.0 <4.0.0')
│
├── meta_mantle_flutter/          (Flutter Web Client Package)
│   ├── lib/
│   │   └── meta_mantle_flutter.dart (MetaHead, GoRouterObserver, Widgets)
│   └── pubspec.yaml              (depends on meta_mantle_core + flutter sdk)
│
└── meta_mantle/                  (Umbrella / Metapackage for Backward Compatibility)
    ├── lib/
    │   ├── meta_mantle.dart      (re-exports meta_mantle_flutter)
    │   └── meta_mantle_core.dart (re-exports meta_mantle_core)
    └── pubspec.yaml              (depends on meta_mantle_core & meta_mantle_flutter)
```

---

## 3. Package Responsibilities

### 1. `package:meta_mantle_core` (Pure Dart SDK)
- **SDK Constraint:** `sdk: '>=3.13.0 <4.0.0'` (NO Flutter SDK dependency).
- **Dependencies:** `crypto`, `shelf`, `html`, `http`, `args`.
- **Contents:**
  - `WebMetadata`, `OpenGraph`, `TwitterCard`, Schema.org JSON-LD builders.
  - `HtmlDocument`, `HtmlNode`, `HtmlSanitizer`, `UrlPolicy`.
  - `MetaMantleServerEngine`, database providers, true LRU caching, SSRF guard.
  - `StaticHeadBuilder`, `SitemapGenerator`, robots.txt, Core Web Vitals telemetry.
  - Universal component tree (`MantleComponent`, `MantlePage`, `MantleTable`).

### 2. `package:meta_mantle_flutter` (Flutter Web Extension)
- **SDK Constraint:** `sdk: '>=3.13.0 <4.0.0'`, `flutter: '>=3.47.0'`.
- **Dependencies:** `meta_mantle_core`, `flutter`, `material_ui`, `web`.
- **Contents:**
  - `MetaHead`, `WebHead`, `MetaMantleGoRouterObserver`.
  - `MantleFlutterRenderer` (rendering universal components as Flutter widgets).
  - Wasm-compatible DOM reconciliation hooks.

### 3. `package:meta_mantle` (Umbrella Metapackage)
- Re-exports both packages to ensure existing Flutter apps do not experience breaking import changes when upgrading.

---

## 4. Migration & Compatibility Impact Analysis

| Consumer Type | Current Import Pattern | Future Import Pattern | Impact |
| :--- | :--- | :--- | :--- |
| **Existing Flutter Web Apps** | `import 'package:meta_mantle/meta_mantle.dart';` | Identical (via umbrella) | **Zero breaking changes** |
| **Pure Dart Shelf Servers** | `import 'package:meta_mantle/meta_mantle_server.dart';` | `import 'package:meta_mantle_core/meta_mantle_server.dart';` | Installable with `dart pub add meta_mantle_core` |
| **Static Site Generator CLIs** | `import 'package:meta_mantle/meta_mantle_builder.dart';` | `import 'package:meta_mantle_core/meta_mantle_builder.dart';` | Zero Flutter SDK required in CI |

---

## 5. Implementation Roadmap

1. **Phase 1 (Current v0.3.0 Baseline):** Document the Flutter SDK resolution requirement transparently across all guides; maintain pure Dart source-level separation within the unified repository.
2. **Phase 2 (v0.4.0 Transition):** Establish monorepo workspace with `packages/meta_mantle_core`, verify published dependency trees via `dart pub publish --dry-run`.
3. **Phase 3 (v1.0.0 Production Release):** Publish `meta_mantle_core` independently to pub.dev, followed by `meta_mantle_flutter` and umbrella `meta_mantle`.
