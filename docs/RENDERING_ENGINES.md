# MetaMantle Rendering Engines Architecture

MetaMantle's tripartite rendering architecture provides portable Dart UI components across three distinct execution targets.

```
                  ┌──────────────────────────────┐
                  │       MantleComponent        │
                  │   (Universal UI & State)     │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │       MantleNode (IR)        │
                  │   (Intermediate AST Tree)    │
                  └──────┬───────┼───────────────┘
                         │       │
       ┌─────────────────┘       │               └─────────────────┐
       ▼                         ▼                                 ▼
┌──────────────┐         ┌──────────────┐                  ┌──────────────┐
│   Engine A   │         │   Engine B   │                  │   Engine C   │
│ Flutter UI   │         │ Browser DOM  │                  │  Server HTML │
│ (Mobile/Web) │         │ (Lightweight)│                  │  (SSR/Static)│
└──────────────┘         └──────────────┘                  └──────────────┘
```

---

## Engine A: Flutter Widget Target (`flutter_renderer.dart`)

Converts `MantleNode` trees into standard Flutter `Widget` hierarchies.

- **Use Cases**: Full-featured mobile applications (iOS/Android), desktop (macOS/Windows/Linux), and heavy client-side Flutter Web (CanvasKit/Skwasm/WasmGC).
- **Element Mapping**:
  - `MantleColumn` / `MantleRow` ➔ `Flex` (`Column` / `Row`)
  - `MantleText` ➔ `Text`
  - `MantleHeading` ➔ Styled `Text` matching standard typography scales
  - `MantleButton` ➔ `ElevatedButton`
  - `MantleArticle`, `MantleSection`, `MantleNav` ➔ `Semantics` widgets with semantic container tags
- **Performance**: Zero runtime reflection; directly instantiates native Flutter render objects.

---

## Engine B: Browser DOM Target (`dom_renderer_web.dart`)

Mounts and reconciles `MantleNode` trees directly against standard browser `package:web` DOM elements.

- **Use Cases**: Ultra-fast web landing pages, documentation portals, and content-first web applications requiring 0kb CanvasKit/Skwasm downloads.
- **Diffing & Reconciliation**:
  - `MantleDiff` compares old and new `MantleNode` trees to generate minimal atomic DOM patches (`InsertChild`, `RemoveChild`, `UpdateText`, `SetAttribute`, `RemoveAttribute`).
  - Active JS event listeners are managed via an internal `Expando<Map<String, JSFunction>>` table. When components unmount or update, listeners are safely detached to prevent memory leaks.
- **Client Hydration**: `MantleHydrator` attaches listeners and state registries to pre-existing server-rendered HTML elements without recreating DOM nodes.

---

## Engine C: Server HTML Target (`server_renderer.dart`)

Renders `MantleNode` trees into deterministic, sanitized, semantic HTML strings.

- **Use Cases**: Static site pre-rendering (`build-web`), dynamic Server-Side Rendering (SSR) via Shelf, and search engine crawler responses.
- **Hydration Marker Support**: Optionally emits `data-mm-id` and `data-mm-state` attributes to enable seamless client hydration.
- **Security**: Automatically sanitizes attribute values, encodes special characters (`<`, `>`, `&`, `"`, `'`), and strips dangerous event handlers (`javascript:` URLs, unescaped raw markup).
