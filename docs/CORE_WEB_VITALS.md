# MetaMantle Core Web Vitals Optimization

MetaMantle is engineered to deliver 95+ scores across Google Core Web Vitals metrics:

---

## 1. Largest Contentful Paint (LCP)

- **Target**: `< 2.5 seconds`
- **MetaMantle Optimizations**:
  - Pre-renders initial HTML directly into static files (`build/web/index.html`).
  - Preloads critical fonts and stylesheets using `<link rel="preload">`.
  - Serves semantic textual headings immediately on first byte without waiting for Flutter Web engine initialization or font loading.

---

## 2. Cumulative Layout Shift (CLS)

- **Target**: `< 0.1`
- **MetaMantle Optimizations**:
  - `ImageSeoAnalyzer` and `MantleImage` enforce explicit integer `width` and `height` attributes to preserve layout geometry before images download.
  - `#mantle-prerender-root` mirrors the layout footprint of the eventual Flutter Web view, eliminating layout jumps when transitioning between static HTML and the interactive canvas.

---

## 3. Interaction to Next Paint (INP)

- **Target**: `< 200 milliseconds`
- **MetaMantle Optimizations**:
  - Engine B uses atomic DOM reconciliations rather than large innerHTML rewrites.
  - Event listeners are bound cleanly with direct JS callbacks, avoiding heavy polyfills.
  - WebAssembly (WasmGC) compilation reduces JavaScript garbage collection pause times.
