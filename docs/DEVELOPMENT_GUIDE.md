# MetaMantle Development & Contribution Guide

This guide details local development workflows, code quality guidelines, and testing procedures for contributors working on the MetaMantle repository.

---

## Prerequisites

- **Dart SDK**: `>=3.6.0 <4.0.0`
- **Flutter SDK**: `>=3.27.0`
- Git

---

## Local Workflow

1. Clone and fetch dependencies:
   ```bash
   git clone https://github.com/JRalex07/meta_mantle.git
   cd meta_mantle
   flutter pub get
   ```

2. Format source code:
   ```bash
   dart format .
   ```

3. Run static analyzer:
   ```bash
   flutter analyze
   flutter analyze example
   ```

4. Run unit and integration tests:
   ```bash
   flutter test
   ```

5. Verify package publication dry-run:
   ```bash
   dart pub publish --dry-run
   ```

---

## Architecture Conventions

- **Clean Imports**: Core and universal exports in `lib/meta_mantle_universal.dart` must NEVER depend on `dart:ui` or Flutter material/widgets to preserve portability across web, server, and non-Flutter environments.
- **Async State Safety**: Always check `if (!_mounted) return;` before executing state mutations in asynchronous callbacks.
- **Path Traversal Guard**: Always validate route paths against `..` and backslash directory traversal sequences before writing static HTML files to disk.
- **Resource Cleanup**: Always detach event listeners and dispose state registries when unmounting components to ensure zero memory leaks.
