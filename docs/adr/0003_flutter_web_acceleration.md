# Architecture Decision Record 0003: Flutter Web Acceleration

## Status
Accepted

## Context
Many existing applications are built with standard Flutter widgets (`StatelessWidget`, `StatefulWidget`, custom painters) and cannot be immediately rewritten into portable `MantleComponent`s. These applications still suffer from Flutter Web's inherent challenges: slow initial load, large bundle downloads, and zero indexing for web search crawlers.

## Decision
MetaMantle provides **Flutter Web Acceleration** with two dedicated operational modes:

### Mode A: Hybrid Pre-Rendering & HTML Hydration
- MetaMantle generates static HTML snapshots for critical entry routes (e.g. landing pages, blog articles, documentation) using `HybridStaticGenerator` and `FileRegenerationQueue`.
- The browser downloads and displays semantic, styled HTML immediately (sub-100ms FCP/LCP).
- In the background, the Flutter Web engine (CanvasKit/Skwasm or Wasm bundle) loads asynchronously.
- Once the Flutter engine is warm, it seamlessly mounts over or replaces the static view without blocking user content access.

### Mode B: Direct Native DOM Rendering
- Applications rewritten or built with MetaMantle's universal component library (`MantleComponent`) compile directly to native DOM elements.
- The Flutter engine is completely bypassed on the web.
- Bundle sizes drop from ~2-5 MB to ~30-60 KB.

### Build and Analysis CLI
The `meta_mantle` CLI includes dedicated web acceleration tools:
- `meta_mantle web analyze`: Inspects the project's `pubspec.yaml`, dependencies, web assets, and identifies Wasm compatibility, font overhead, and renderer recommendations.
- `meta_mantle web build`: Generates optimized `flutter build web` commands configured for modern Wasm/CanvasKit or native DOM pipelines.
- `meta_mantle web profile`: Measures asset distribution, JavaScript chunks, and font footprint.
- `meta_mantle web report`: Emits a comprehensive performance report with actionable recommendations.

## Consequences
- Teams with existing Flutter codebases can achieve instant initial page loads without refactoring their entire UI.
- New applications or performance-critical content routes can adopt native DOM rendering for best-in-class web performance.

