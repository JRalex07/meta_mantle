# MetaMantle Universal Component Compatibility Matrix

This matrix documents the runtime rendering capabilities and level of support for each portable component across MetaMantle's three official rendering targets:
1. **Flutter Mobile/Desktop/Web Canvas**: Native widgets on Android, iOS, Windows, macOS, Linux, and Flutter CanvasKit.
2. **Native Browser DOM**: Real HTML5 elements, CSS3 flex/grid layouts, and native DOM event listeners via modern Dart Web interoperability (`package:web` and `dart:js_interop`).
3. **Semantic Server HTML**: Accessible, SEO-optimized HTML strings and documents with hydration markers for pre-rendering, SSG, and ISR.

---

## 1. Application Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleApp` | `MaterialApp` / Scaffold | App root mount / Router | Root document wrapper | Full cross-target support |
| `MantlePage` | `SafeArea` / Container | `<main class="mantle-page">` | `<main>` document body | Full cross-target support |
| `MantleFragment` | `Column` / multi-child | `DocumentFragment` | `<div class="mantle-fragment">` | Full cross-target support |

---

## 2. Layout Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleContainer` | `Container` / `BoxDecoration` | `<div style="...">` | `<div>` inline CSS | Full cross-target support |
| `MantleRow` | `Row` (flex direction row) | `<div style="display:flex; flex-direction:row">` | `<div>` flex row | Full cross-target support |
| `MantleColumn` | `Column` (flex direction col) | `<div style="display:flex; flex-direction:column">` | `<div>` flex column | Full cross-target support |
| `MantleStack` | `Stack` (absolute positioning) | `<div style="position:relative">` | `<div>` relative/absolute | Full cross-target support |
| `MantleWrap` | `Wrap` (flex-wrap) | `<div style="display:flex; flex-wrap:wrap">` | `<div>` flex-wrap | Full cross-target support |
| `MantleGrid` | `GridView.count` | `<div style="display:grid">` | `<div>` CSS grid | Full cross-target support |
| `MantlePadding` | `Padding` (`EdgeInsets`) | `<div style="padding:...">` | `<div>` CSS padding | Full cross-target support |
| `MantleCenter` | `Center` | `<div style="display:flex; justify-content:center; align-items:center">` | `<div>` flex center | Full cross-target support |
| `MantleSpacer` | `Spacer` | `<div style="flex:1">` | `<div>` flex:1 | Full cross-target support |
| `MantleSizedBox` | `SizedBox` | `<div style="width:...; height:...">` | `<div>` width/height | Full cross-target support |

---

## 3. Text Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleText` | `Text` | Text node / `<span>` | Text node / `<span>` | Full cross-target support |
| `MantleHeading` | `Text` (styled h1-h6) | `<h1>` .. `<h6>` | `<h1>` .. `<h6>` | Full semantic heading hierarchy |
| `MantleRichText` | `RichText` / `TextSpan` | `<span>` with inline formatting | `<span>` with inline formatting | Full cross-target support |
| `MantleTextStyle`| `TextStyle` | CSS font/color properties | CSS inline style properties | Full cross-target support |

---

## 4. Media Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleImage` | `Image.network` | `<img src="..." alt="...">` | `<img src="..." alt="...">` | Full self-closing semantic tag |
| `MantleIcon` | `Icon` | `<i>` / SVG icon wrapper | `<i>` / SVG icon wrapper | Full cross-target support |

---

## 5. Interaction Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleButton` | `ElevatedButton` | `<button>` + `addEventListener` | `<button data-mantle-interactive>` | Fully interactive with click events |
| `MantleIconButton` | `IconButton` | `<button class="icon-btn">` | `<button class="icon-btn">` | Full cross-target support |
| `MantleLink` | `InkWell` | `<a href="...">` | `<a href="...">` | Native hyperlink with href |
| `MantleGestureDetector`| `GestureDetector` | `<div class="clickable">` + listeners | `<div>` interactive marker | Tap, click, hover bindings |

---

## 6. Form Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :---: |
| `MantleTextField` | `TextFormField` | `<input type="text">` | `<input type="text">` | Supports input/change/submit |
| `MantleTextArea` | `TextFormField(maxLines: rows)` | `<textarea rows="..." cols="...">` | `<textarea rows="..." cols="...">` | Multi-line text input |
| `MantleCheckbox` | `Checkbox` | `<input type="checkbox">` | `<input type="checkbox">` | Checked attribute & change event |
| `MantleSwitch` | `Switch` | `<input type="checkbox" role="switch">`| `<input type="checkbox">` | Boolean toggle |
| `MantleSelect` | `DropdownButton` | `<select>` + `<option>` | `<select>` + `<option>` | Single selection dropdown |
| `MantleForm` | `Form` | `<form>` + submit event | `<form>` | Submit callback & prevention |

---

## 7. Navigation Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleAppBar` | `AppBar` / Row | `<header class="mantle-app-bar">` | `<header>` semantic bar | Full cross-target support |
| `MantleNavigation` | Bottom/Top nav row | `<nav role="navigation">` | `<nav>` semantic nav | Tab selection and active index |
| `MantleDrawer` | `Drawer` / side container | `<aside class="mantle-drawer">` | `<aside>` drawer | Collapsible with backdrop |
| `MantleTabs` | TabBar + TabBarView | `<div role="tablist">` + tabpanel | Tablist & panel | Tab switching and active view |
| `MantleRouteLink` | `InkWell` with context.go | `<a href="...">` with SPA click | `<a href="...">` clean URL | Full client and server routing |

---

## 8. Content & Commerce Components

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleArticle` | `Column` with styled header | `<article class="mantle-article">` | `<article itemprop="articleBody">` | Semantic article container with title, author, and date metadata |
| `MantleList` | `Column` (bullet padding) | `<ul>` or `<ol class="mantle-list">` | `<ul>` or `<ol class="mantle-list">` | Ordered and unordered list container |
| `MantleListItem`| Row with bullet point | `<li class="mantle-list-item">` | `<li class="mantle-list-item">` | Standard list item |
| `MantleDetails` | `ExpansionTile` | `<details open="...">` + `<summary>` | `<details open="...">` + `<summary>` | Accessible collapsible disclosure |
| `MantleProduct` | Card with Column & Price | `<div itemscope itemtype="Product">` | `<div itemscope itemtype="Product">` | Embedded Schema.org Product microdata with price, currency, availability |

---

## 9. Accessibility Semantics

| Component | Flutter Target | Browser DOM Target | Server HTML Target | Status / Notes |
| :--- | :---: | :---: | :---: | :--- |
| `MantleSemantics` | `Semantics(label, ...)` | `aria-label`, `role`, `aria-live` | `aria-label`, `role` attributes | Accessible screen-reader support |
| `MantleLabel` | `Text` | `<label for="...">` | `<label for="...">` | Associates input with text |
| `MantleLandmark` | Semantics container | `<main>`, `<nav>`, `<aside>`, etc. | Semantic HTML5 landmark tags | WAI-ARIA & HTML5 standards |
