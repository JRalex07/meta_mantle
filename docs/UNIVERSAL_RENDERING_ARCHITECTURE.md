# MetaMantle Universal Rendering Architecture

## Architecture Decision Record & Technical Specification (ADR-004)

**Status:** Accepted & Implemented  
**Author:** Principal Dart Architect & Rendering Systems Specialist  
**Date:** November 2026  
**Target:** Flutter Web, Dart Server, Desktop & Mobile  

---

## 1. Executive Summary & Problem Space

Modern web development in Dart historically suffered from a stark dichotomy:
1. **Flutter Web:** Exceptional UI consistency, rich gesture physics, and 100% pixel matching with mobile/desktop via Skia/Impeller. However, Flutter Web renders to an opaque `<canvas>` element (CanvasKit or Skwasm), rendering it opaque to search engine crawlers without pre-rendered HTML, suffering from heavy initial asset bundles, and lacking native DOM semantics.
2. **Web-Only Frameworks (e.g. Jaspr):** Render native semantic HTML/CSS directly to the DOM and support SSR/SSG. However, they traditionally require distinct component models, duplicate UI definitions, or awkward split entrypoints (`.client.dart` vs `.server.dart`) that break compatibility with Flutter mobile/desktop applications.

MetaMantle resolves this dichotomy by introducing a **Universal Intermediate Representation (IR)** component model and a **Dual-Mode Architectural Framework**.

---

## 2. Reverse Engineering & Architectural Comparative Analysis

### 2.1 Jaspr Reverse Engineering
Jaspr (created by Kilian Schulte) models components similarly to Flutter (`Component`, `StatelessComponent`, `StatefulComponent`), but compiles directly to HTML DOM tree nodes (`DomNode`, `ElementNode`, `TextNode`) rather than Flutter `RenderObject`s.
- **Hydration & Islands:** Jaspr utilizes `@client` annotations or island wrappers to hydrate only interactive components while leaving static HTML untouched.
- **Entrypoint Separation:** Jaspr separates compilation targets via `.client.dart` and `.server.dart` source files.
- **Flutter Embed:** Jaspr embeds Flutter via an `<iframe>` or host `<div>`, treating Flutter as an isolated child rather than a unified component tree.

### 2.2 Flutter Web Engine Evolution (Flutter 3.22 - 3.29+)
- **Removal of Legacy HTML Renderer:** In Flutter 3.29, the legacy DOM-based HTML renderer was permanently removed. Flutter Web now operates exclusively in canvas-rendering mode:
  - **CanvasKit Backend:** Compiles Skia to WebAssembly and renders using WebGL.
  - **Skwasm Backend (`--wasm`):** Multi-threaded WebAssembly using `SharedArrayBuffer`, WasmGC, and WebGPU/WebGL2, requiring `COOP: same-origin` and `COEP: require-corp` headers.
- **package:web & dart:js_interop Migration:** Complete migration away from legacy `dart:html` and `package:js`.

### 2.3 Architectural Comparison Matrix

| Architectural Dimension | Flutter Web (Mode A) | Jaspr | MetaMantle Universal (Mode B) |
| :--- | :--- | :--- | :--- |
| **Component Model** | Flutter `Widget` | Jaspr `Component` | Universal `MantleComponent` |
| **Render Backends** | CanvasKit / Skwasm (`<canvas>`) | Native DOM / Server HTML | Native DOM, Server HTML, and Flutter Widgets |
| **SEO Indexability** | Zero native DOM without SSR | 100% Semantic HTML | 100% Semantic HTML + Schema.org + OpenGraph |
| **Mobile/Desktop Native** | Direct native compilation | Not supported | Direct compilation via `MantleFlutterRenderer` |
| **Application Entrypoint**| `main() => runApp(...)` | Dual (`.client` / `.server`) | Single unified `runMantleApp(app)` |
| **Client Hydration** | None (Engine re-runs from scratch) | Selective Island Hydration | Non-destructive DOM event attaching |

---

## 3. The MetaMantle Universal IR Architecture

The core of MetaMantle is an intermediate representation (IR) tree that decouples component definitions from the rendering target:

```
                      ┌──────────────────────┐
                      │   MantleComponent    │
                      │  (Portable UI Def)   │
                      └──────────┬───────────┘
                                 │ .toNode(context)
                                 ▼
                      ┌──────────────────────┐
                      │      MantleNode      │
                      │   (Universal IR)     │
                      └──────────┬───────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │ node.accept(visitor)  │ node.accept(visitor)  │ node.accept(visitor)
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  MantleServer   │     │   MantleDom     │     │  MantleFlutter  │
│    Renderer     │     │    Renderer     │     │    Renderer     │
│  (Dart Server)  │     │ (Browser DOM)   │     │ (Flutter Native)│
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
   Semantic HTML5           Real Browser          Flutter Widget
     Documents              DOM Elements               Tree
```

### 3.1 Node Tree Hierarchy
- `MantleNode`: Base abstract class with stable reconciliation `MantleKey`.
- `MantleElementNode`: Semantic element with `tag`, `classes`, `attributes`, `styles`, `events`, and `children`.
- `MantleTextNode`: Text node with optional `MantleTextStyle`.
- `MantleFragment`: Grouping of sibling nodes without DOM-polluting parent elements.

### 3.2 Styling Abstraction (`MantleStyle`)
`MantleStyle` provides clean, bidirectional property mappings between CSS and Flutter properties:
- `MantleColor`: Supports ARGB, RGBO, hex `#RRGGBB`, and CSS `rgba(r, g, b, a)` mapping.
- `MantleEdgeInsets`: Maps to CSS `padding`/`margin` (`top right bottom left`) and Flutter `EdgeInsets`.
- `MantleBorderRadius`: Maps to CSS `border-radius` and Flutter `BorderRadius`.
- `MantleBorder`: Maps to CSS `border: width style color` and Flutter `Border.all`.
- `MantleBoxShadow`: Maps to CSS `box-shadow: dx dy blur spread color` and Flutter `BoxShadow`.
- Flex alignments: Bidirectional conversion for `justify-content`, `align-items`, and Flutter `MainAxisAlignment` / `CrossAxisAlignment`.

---

## 4. Multi-Target Rendering Backends

### 4.1 Server-Side Renderer (`MantleServerRenderer`)
- Compiles `MantleNode` trees into `HtmlNode` and complete `<!DOCTYPE html>` documents.
- Automatically escapes text and attributes, eliminating Cross-Site Scripting (XSS) vectors.
- Emits Schema.org JSON-LD structured data, OpenGraph, Twitter Cards, and canonical tags.
- Identifies self-closing void elements (`img`, `input`, `br`, `hr`) in compliance with W3C HTML5.

### 4.2 Browser DOM Renderer & Hydrator (`MantleDomRenderer` & `MantleHydrator`)
- Implemented using modern `package:web` and `dart:js_interop`.
- Conditionally exported with non-web stubs to ensure safety across Dart Server and Native targets.
- Features selective, non-destructive hydration: attaches event listeners to pre-rendered SSR elements without rebuilding the DOM tree.

### 4.3 Flutter Native Renderer (`MantleFlutterRenderer`)
- Compiles portable `MantleNode` trees into standard Flutter `Widget`s (`ElevatedButton`, `TextFormField`, `Row`, `Column`, `Container`, `Image.network`, `Text`).
- Allows universal components to run inside Flutter applications on iOS, Android, macOS, Windows, Linux, and Flutter Web CanvasKit.

---

## 5. Single Entrypoint & Platform Adaptation

Applications define one unified `MantleApp` with routes, which executes through `runMantleApp(app)`:
- On Dart Server: Renders route to HTML document.
- On Browser DOM (Mode B): Mounts into `document.body` or `#app` container.
- On Flutter Native / CanvasKit (Mode A): Mounts into `runApp(MantleAppWidget(app))`.

```dart
void main() {
  runMantleApp(
    MantleApp(
      title: 'Universal Store',
      routes: [
        MantleRoute(path: '/', builder: (ctx) => const HomePage()),
        MantleRoute(path: '/products/:id', builder: (ctx) => const ProductPage()),
      ],
    ),
  );
}
```

