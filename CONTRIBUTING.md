# Contributing to MetaMantle

Thank you for your interest in contributing to **MetaMantle**!

MetaMantle is an open-source framework designed to provide universal typed metadata management, native server-side rendering (SSR), and automated SEO infrastructure for Flutter Web and Dart applications.

To ensure stability, security, and developer ergonomics across the tripartite architecture (Runtime Web, Static Pre-rendering, and Native Dart SSR), please follow these guidelines.

---

## 1. Development Setup

### Prerequisites
- **Flutter SDK:** Version `>=3.27.0`
- **Dart SDK:** Version `>=3.6.0 <4.0.0`
- **Git**

### Clone and Install Dependencies
```bash
# Clone the repository
git clone https://github.com/JRalex07/meta_mantle.git
cd meta_mantle

# Install root dependencies
flutter pub get

# Install example dependencies
cd example
flutter pub get
cd ..
```

---

## 2. Quality Verification Workflow

Before submitting a pull request, you **must** run and pass the standard verification suite:

```bash
# 1. Verify Dart formatting (Must exit with code 0)
dart format --output=none --set-exit-if-changed .

# 2. Run static analysis on root package (Must report 0 issues)
flutter analyze

# 3. Run static analysis on example package
flutter analyze example

# 4. Run the complete automated test suite (Must pass 100%)
flutter test

# 5. Verify package dry-run publication
dart pub publish --dry-run
```

If formatting issues are detected, format the codebase using:
```bash
dart format .
```

---

## 3. Architecture & Code Quality Standards

Contributions must adhere to the core architectural principles of MetaMantle:

### 1. Tripartite Layer Isolation
- **Pure Dart Core (`lib/meta_mantle_core.dart`):** Must **never** import `package:flutter`, `dart:io`, or `package:web`. Contains universal data models, policy resolution, JSON-LD builders, and tag models.
- **Server Engine (`lib/meta_mantle_server.dart`):** Depends strictly on pure Dart VM capabilities and standard HTTP abstractions. Must **never** import `package:flutter` or `package:web`.
- **Runtime Flutter (`lib/meta_mantle.dart`):** Contains Flutter widgets (`MetaHead`, `WebHead`) and runtime web DOM mutators using `package:web` and `dart:js_interop`. Non-web platforms must compile safely using conditional import stubs (`src/runtime/web_dom_stub.dart`).

### 2. Dependency Discipline
- Avoid introducing heavy third-party dependencies into the core package.
- Prefer standard library algorithms and lightweight Dart packages.
- Keep optional framework integrations (Shelf, Jaspr, etc.) decoupled via adapters.

### 3. Security Requirements
- **Context-Aware Escaping:** All user-supplied metadata strings injected into HTML must be escaped using `HtmlSanitizer` or `MetadataRenderer`.
- **JSON-LD Script Safety:** Structured data serialized into `<script type="application/ld+json">` must encode `<`, `>`, `&`, and `"` to prevent script tag breakout attacks (`</script><script>...`).
- **SSRF Prevention:** Any outbound HTTP requests in data providers must be validated against `SsrfGuard` to prevent access to private IP ranges, loopback (`127.0.0.1`), and cloud instance metadata (`169.254.169.254`).
- **Response Size Limits:** Outbound data streaming must use chunk-by-chunk counting (`BytesBuilder`) and abort before memory exhaustion.
- **Host Header Validation:** Server requests must validate `Host` headers against registered domains using `TenantHostValidator`.

### 4. Public API & Documentation
- All public classes, constructors, methods, and typedefs must have descriptive Dart doc comments (`///`).
- Avoid breaking changes to existing public APIs without prior deprecation notice (see [API Stability Policy](docs/API_STABILITY.md)).

---

## 4. Pull Request Process

1. **Fork the Repository:** Create a feature branch off `main` (e.g. `feature/my-improvement` or `fix/issue-description`).
2. **Implement & Test:** Add corresponding unit or integration tests in `test/`. New features without test coverage will not be merged.
3. **Update Documentation:** Update relevant Markdown files in `docs/` and add an entry in `CHANGELOG.md` under `Unreleased` or the current milestone.
4. **Commit:** Write clear, conventional commit messages:
   - `feat: add support for XYZ`
   - `fix: resolve ETag matching bug`
   - `docs: improve SSR setup instructions`
   - `test: add regression test for faceted nav`
5. **Open Pull Request:** Describe the problem solved, list testing performed, and link to any relevant GitHub issues.

---

## 5. Community & Conduct

All participants in the MetaMantle project are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

For vulnerability disclosures, please review our [Security Policy](SECURITY.md).
