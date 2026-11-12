# Architecture Decision Record 0002: DOM Reconciliation and Hydration

## Status
Accepted

## Context
When a component updates its local or observable state (e.g., via `setState` or a state store mutation), destroying and re-mounting the container DOM tree causes:
1. Significant layout and reflow recalculations in the browser.
2. Loss of text input focus, cursor position, and user scroll state.
3. Flash of unstyled content or stuttering animations.

Similarly, when a page is pre-rendered on the server via SSR or SSG, tearing down the server-generated HTML and rendering from scratch defeats the performance purpose of server pre-rendering and causes noticeable visual flashes.

## Decision

### 1. Incremental DOM Reconciliation
MetaMantle implements a tree diffing reconciler in `MantleDomRenderer`:
- **Node Identity Matching**: Nodes are matched first by `key` (if provided) and second by position and tag name.
- **Node Replacement**: If node tags or keys differ, the old DOM node is replaced (`replaceChild`).
- **In-place Patching**: If the node tag and key match:
  - **Text Nodes**: If text content changes, only `node.textContent` is updated.
  - **Attributes**: New or updated attributes are set via `setAttribute`; deleted attributes are removed via `removeAttribute`.
  - **CSS Styles**: Changed style declarations are updated via `element.style.setProperty`; removed declarations are cleared via `removeProperty`.
  - **Event Listeners**: Listeners are attached dynamically to dispatch normalized `MantleEvent`s to component callbacks.
  - **Children Reconciliation**: Children lists are reconciled with minimal insertions, removals, and replacements.

### 2. Selective Hydration
The server renderer emits deterministic hydration metadata:
- `data-mantle-node`: Element tag name.
- `data-mantle-key`: Explicit component key string (if present).
- `data-mantle-interactive`: Indicates interactive element with registered event listeners.

When client initialization executes (`runMantleApp(hydrate: true)`):
1. The hydrator inspects the target container.
2. If server-rendered HTML elements exist, the hydrator walks the DOM tree concurrently with the initial client `MantleNode` tree.
3. Matching DOM elements receive event listeners (`click`, `input`, `change`, `submit`) without modifying DOM nodes.
4. If a mismatch is detected (e.g. dynamic content difference), the reconciler patches only the differing subtree rather than destroying the document.

## Consequences
- Zero layout thrashing during state updates.
- Preserved user focus and input state during typing.
- Instant page interaction after server pre-rendering.

