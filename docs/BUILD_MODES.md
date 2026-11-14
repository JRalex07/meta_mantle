# MetaMantle Build Modes Architecture

MetaMantle supports three primary compilation and rendering modes through `dart run meta_mantle build-web --mode=<mode>`.

---

## 1. Static Mode (`--mode=static`)

Generates pure, self-contained semantic HTML documents for all declared routes.

- **Characteristics**:
  - Excludes Flutter Web CanvasKit and Skwasm JavaScript engines.
  - Generates lightweight HTML pages with pure CSS styling.
  - Injects full SEO metadata: `<title>`, `<meta name="description">`, Open Graph cards, Twitter cards, and JSON-LD structured data.
- **Ideal For**: Marketing landing pages, documentation wikis, blog posts, and regulatory disclosure sites where minimal page load time and search crawler indexing are paramount.

---

## 2. Hybrid Mode (`--mode=hybrid`) [Default]

Combines pre-rendered semantic HTML with the full interactive power of Flutter Web.

- **Characteristics**:
  - Pre-renders semantic HTML snapshots inside `#mantle-prerender-root` during build time.
  - When the user visits the page, the browser immediately displays the semantic HTML (FCP < 300ms, Lighthouse SEO score = 100).
  - Flutter Web downloads and compiles its WebAssembly / CanvasKit bundle in the background.
  - Once Flutter renders its first frame (`MetaMantleGoRouterObserver` / `MetaMantle.markReady()`), `#mantle-prerender-root` fades out smoothly (250ms CSS transition) and is removed from the DOM.
- **Fail-Safe Mechanism**: If an unhandled client script error occurs during Flutter startup, the static HTML snapshot remains visible, ensuring users never see a blank white screen.

---

## 3. Universal Mode (`--mode=universal`)

Renders semantic HTML on the server and hydrates client-side interactivity using MetaMantle's lightweight DOM reconciler (Engine B).

- **Characteristics**:
  - Server renders initial markup with hydration identifiers (`data-mm-id`).
  - Browser executes `runMantleApp(app, hydrate: true)` using pure Dart-to-Wasm/JS compilation.
  - Zero Flutter engine overhead; direct DOM manipulation with atomic diffing patches.
- **Ideal For**: Dynamic web applications, e-commerce storefronts, and SaaS dashboards requiring instant interaction and reactive client-side navigation without downloading Flutter's rendering canvas.
