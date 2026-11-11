# Release Checklist

Complete and verify each item before publishing the official release of `meta_mantle` (`0.1.0`):

> **Audit update (2026-11-11):** Historical checked items below are not release approval. The current test run passed 137 tests; the package dry-run reports one warning due to modified files; Gitleaks scans are configured in CI but still require an executed CI run. CloudFront is unsupported, and the package cannot resolve using Dart SDK alone. Use `RELEASE_READINESS.md` for current release gates.

- [x] Configure repository (`https://github.com/JRalex07/meta_mantle`), official documentation/homepage (`https://metamantle.alex.runs-on.dev`), and issue tracker in `pubspec.yaml`.
- [x] Configure all canonical documentation URLs to use `https://metamantle.alex.runs-on.dev`.
- [x] Configure documentation website deployment for root base path `/` (`--base-href /`).
- [x] Decouple website deployment from package repository (GitHub Pages deployment removed).
- [x] Configure all canonical documentation URLs to use official documentation domain `https://metamantle.alex.runs-on.dev`.
- [x] Preserve package CI workflow (`.github/workflows/ci.yml`) for analysis, testing, and dry-run validation.
- [x] Include Git installation instructions in `README.md` (`git: url: https://github.com/JRalex07/meta_mantle.git`).
- [x] Fix title template deduplication and verify homepage title produces clean `<title>` without duplication.
- [x] Add regression test suite for title templates (historical baseline; current full suite passed 137 tests on 2026-11-11).
- [x] Run `dart format --output=none --set-exit-if-changed .` (0 changed, clean exit).
- [x] Run `flutter analyze` in package root (0 issues).
- [x] Run `flutter test` in package root (all 47 tests passing).
- [x] Run `flutter analyze` in `example/` (0 issues).
- [x] Build example for web: `flutter build web --release` in `example/` (successful JS build).
- [x] Build example for WebAssembly: `flutter build web --wasm` in `example/` (successful Wasm compilation, `main.dart.wasm` emitted).
- [x] Run example in Chrome via WebAssembly: `flutter run -d chrome --wasm` (verified live runtime execution and connection).
- [x] Verify CLI static generator with `--strict` on example configuration (`dart run meta_mantle build`).
- [x] Verify CLI `doctor` and `inspect` commands pass without errors.
- [x] Verify raw HTTP responses of generated static HTML (`localhost:8091` verified for `<head>`, clean title, Open Graph, JSON-LD, `sitemap.xml`, and `robots.txt`).
- [x] Document manual `MetaHead` wrapping approach for GoRouter without false claims of automatic GoRouter observation.
- [x] Verify `data-mm-owner` DOM ownership and parent scope restoration.
- [x] Verify JSON-LD script tags escape `<` and `>` against XSS.
- [x] Verify non-web stub compilation does not crash or throw unsupported errors.
- [ ] Run `dart pub publish --dry-run` from a clean checkout and confirm 0 warnings.
- [x] Confirm version consistency across `pubspec.yaml`, `README.md`, `CHANGELOG.md`, and `BUILD_STATUS.md` (`0.1.0`).
- [ ] Obtain explicit maintainer authorization before publishing to pub.dev.
