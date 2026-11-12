# Architecture Decision Record 0001: Universal Dart Rendering Architecture

## Status
Accepted

## Context
MetaMantle initially focused on SEO, server-side rendering (SSR), static site generation (SSG), and incremental static regeneration (ISR) for Flutter Web applications. While Flutter Web excels at building rich, canvas-driven graphical applications, its canvas-based rendering (CanvasKit / Skwasm) introduces significant payload size (several megabytes for WebAssembly runtimes, Skia fonts, and engine logic), non-native text selection and accessibility, and rendering overhead for standard content-heavy websites.

To solve this, MetaMantle is evolving into a universal Dart rendering architecture where developers write UI components and application logic **once in pure Dart** and compile/render them across three distinct targets:
1. **Flutter Mobile/Desktop/Web Canvas**: Native widgets on Android, iOS, Windows, macOS, Linux, and Flutter CanvasKit.
2. **Native Browser DOM**: Real HTML5 elements, CSS3 flex/grid layouts, and native DOM event listeners via modern Dart Web interoperability (`package:web` and `dart:js_interop`).
3. **Semantic Server HTML**: Accessible, SEO-optimized HTML strings and documents with hydration markers for pre-rendering, SSG, and ISR.

## Jaspr vs. Flutter Web vs. React Architecture Comparison

### 1. Jaspr
- **Core Model**: Jaspr maps Dart component trees directly to HTML DOM nodes in the browser and semantic HTML strings on the server.
- **Component Lifecycle**: Emulates Flutter's `StatelessComponent` and `StatefulComponent` paradigms (`createElement()`, `build()`), but backing elements correspond directly to DOM nodes rather than Flutter's `RenderObject` pipeline.
- **Hydration**: Jaspr serializes state and component tree locations during SSR and matches them on the client using element-level markers, binding event listeners without re-creating matching DOM nodes.
- **Key Takeaways for MetaMantle**: A pure-Dart intermediate representation (IR) decoupled from Flutter SDK libraries (`dart:ui`, `package:flutter`) allows portable components to run on native Dart VM (server/CLI) and Dart Web without dragging in Flutter's multi-megabyte engine.

### 2. Flutter Web
- **Core Model**: Compiles Dart code to JavaScript or WebAssembly (WasmGC) and executes Flutter's retained-mode graphics engine (`RenderObject`, layout, paint, rasterization) onto a `<canvas>` element via CanvasKit/Skwasm.
- **Strengths**: Pixel-perfect rendering across platforms; identical animation, physics, and custom painters.
- **Weaknesses**: Heavy initial download (Wasm + font assets), poor native browser text integration, lack of semantic HTML tags for search crawlers (without complex accessibility DOM bridges), high initial latency (TTFB/FCP).
- **Key Takeaways for MetaMantle**: MetaMantle should not replace Flutter's engine for complex graphical apps, but provide **Flutter Web Acceleration** for existing apps (Mode A: SSR/SSG/ISR pre-rendering; Mode B: native DOM rendering for content/marketing/e-commerce workflows).

### 3. React
- **Core Model**: Declarative Virtual DOM tree (`ReactElement`), fiber-based incremental reconciler, synthetic event delegation, and hydration (`hydrateRoot`).
- **Reconciliation Algorithm**: Heuristic O(n) diffing based on component keys and node types. When keys and types match, DOM nodes are preserved and only changed attributes, styles, and children are patched.
- **Hydration**: Validates server-rendered DOM nodes against client Virtual DOM nodes, attaching event handlers without destroying DOM nodes.
- **Key Takeaways for MetaMantle**: Implement key-based incremental reconciliation in the browser DOM renderer to update only mutated elements during `setState` rather than tearing down the DOM tree.

---

## Architectural Decisions

1. **Headless Universal Intermediate Representation (IR)**:
   - `MantleNode`: Abstract representation with three subclasses: `MantleElementNode`, `MantleTextNode`, and `MantleFragment`.
   - `MantleStyle`: Type-safe styling tokens (`MantleColor`, `MantleEdgeInsets`, `MantleTextStyle`, `MantleBorderRadius`, `MantleBoxShadow`, `MantleBorder`) that compile deterministically to both CSS3 property maps and Flutter `TextStyle`/`BoxDecoration`/`EdgeInsets`.
   - `MantleEvent`: Normalized event contract (`click`, `input`, `change`, `submit`, `focus`, `blur`) independent of `web.Event` or Flutter gesture details.

2. **Package Boundaries & Compilation Constraints**:
   - The portable core (`lib/src/universal/ir/`, `components/`, `routing/`, `state/`) must have **zero dependencies on `package:flutter` or `package:web`**. It is 100% pure Dart, compiling on VM, Web, and Flutter.
   - The Flutter renderer (`lib/src/universal/rendering/flutter_renderer.dart`) imports `package:flutter`.
   - The DOM renderer (`lib/src/universal/rendering/dom_renderer_web.dart`) imports `package:web` and `dart:js_interop`.
   - On the server, `dom_renderer_stub.dart` supplies no-op stubs so server code can reference universal modules without compiler failures.

3. **Shared Canonical Routing**:
   - `MantleApp` and `MantleRoute` define routes once with path templates (e.g. `/products/:id`), title, and route builders.
   - The same route table drives Flutter navigator on mobile, browser History API on web, and path routing during static site generation or server SSR.

4. **Reconciliation & Hydration**:
   - Server rendering emits `data-mantle-key` and `data-mantle-node` markers.
   - Client hydration engine walks existing DOM elements, verifies type matches, and binds event listeners without DOM thrashing.

## Consequences
- Developers write UI components using `MantleComponent` (`MantleContainer`, `MantleText`, `MantleButton`, etc.) once.
- On Android/iOS, the app runs as high-performance native Flutter widgets.
- On Web (Mode B), the app loads instantly as native HTML5/CSS3 with minimal JS footprint (tens of KB instead of megabytes).
- On the server, routes are pre-rendered into HTML artifacts for search engine crawlers and CDN distribution.

