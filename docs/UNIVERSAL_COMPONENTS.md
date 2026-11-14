# MetaMantle Universal Component System

MetaMantle's universal component library (`package:meta_mantle/meta_mantle_universal.dart`) enables building UI and state logic once, targeting Flutter widgets, Browser DOM elements, and server HTML.

---

## Component Catalog

### 1. Layout & Structure
- `MantleColumn`: Vertical flex layout. Maps to Flutter `Column` / HTML `<div class="column">`.
- `MantleRow`: Horizontal flex layout. Maps to Flutter `Row` / HTML `<div class="row">`.
- `MantleBox`: Generic container with padding, margin, width, and height. Maps to Flutter `Container` / HTML `<div>`.
- `MantleFragment`: Virtual grouping container that renders children without creating wrapper DOM nodes.

### 2. Semantic & Content Elements
- `MantleHeading`: Semantic headings with level constraints (`1` through `6`). Maps to Flutter `Text` with headline typography / HTML `<h1>`..`<h6>`.
- `MantleText`: Paragraph text. Maps to Flutter `Text` / HTML `<p>`.
- `MantleArticle`: Independent self-contained composition. Maps to Flutter `Semantics` / HTML `<article>`.
- `MantleSection`: Generic standalone section of a document. Maps to Flutter `Semantics` / HTML `<section>`.
- `MantleNav`: Navigation links container. Maps to Flutter `Semantics(nav: true)` / HTML `<nav>`.
- `MantleDetails` & `MantleSummary`: Interactive disclosure widget. Maps to Flutter `ExpansionTile` / HTML `<details>` and `<summary>`.

### 3. Media & Forms
- `MantleImage`: Image with CLS-prevention dimensions, lazy loading, and alt attributes. Maps to Flutter `Image.network` / HTML `<img>`.
- `MantleButton`: Clickable button with state callbacks. Maps to Flutter `ElevatedButton` / HTML `<button>`.
- `MantleInput`: Text input field with two-way data binding. Maps to Flutter `TextField` / HTML `<input type="text">`.
- `MantleCheckbox`: Boolean toggle. Maps to Flutter `Checkbox` / HTML `<input type="checkbox">`.

---

## State Management (`MantleStatefulComponent`)

Components maintain local reactive state through `MantleState`:

```dart
class CounterComponent extends MantleStatefulComponent {
  const CounterComponent({super.key});

  @override
  MantleState createState() => _CounterComponentState();
}

class _CounterComponentState extends MantleState<CounterComponent> {
  int _count = 0;

  @override
  MantleNode build(MantleContext context) {
    return MantleBox(
      children: [
        MantleText('Count: $_count'),
        MantleButton(
          label: 'Increment',
          onPressed: () {
            setState(() {
              _count++;
            });
          },
        ),
      ],
    );
  }
}
```

### Async State Safety
`MantleState.setState()` includes an active mount guard:
```dart
void setState(void Function() fn) {
  if (!_mounted) return;
  fn();
  _notifyStateChanged();
}
```
If an asynchronous operation completes after the component has unmounted, `setState()` is safely ignored without throwing unhandled exceptions.
