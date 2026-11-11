# Getting Support for MetaMantle

Thank you for building with **MetaMantle**!

This document outlines how to get assistance, ask questions, report bugs, and request new capabilities.

---

## 1. Where to Get Help

### GitHub Issues (Bugs & Defects)
If you encounter a defect, unexpected behavior, or an exception in MetaMantle:
- **Repository Issues:** [https://github.com/JRalex07/meta_mantle/issues](https://github.com/JRalex07/meta_mantle/issues)
- Before filing, please search existing open and closed issues to check if the issue has already been reported or resolved.
- Include the following details in bug reports:
  - MetaMantle version (e.g. `0.1.0` or Git commit ref).
  - Flutter & Dart SDK version (`flutter --version`).
  - Target environment (Flutter Web Wasm, Flutter Web JS, Static generation CLI, or Native Dart SSR).
  - Minimal reproducible example code.
  - Expected vs actual behavior with full stack traces.

### GitHub Discussions / Community Questions
For architectural questions, general inquiries, or design advice on using MetaMantle:
- Open a discussion topic in the repository's **Discussions** tab.
- Browse the extensive technical guides in [`docs/`](docs/).

### Security Inquiries
For sensitive security issues, do **not** post publicly. Follow the instructions in [SECURITY.md](SECURITY.md).

---

## 2. Scope of Support

### What MetaMantle Maintains & Supports:
- Bugs and issues within the `meta_mantle` core library, server engine, runtime DOM widgets, static builder CLI, and official adapters.
- Guidance on integrating `MetaHead`, `WebHead`, `MetaMantleServerEngine`, and `StaticHeadBuilder`.
- Verification of metadata generation, JSON-LD compliance, HTTP conditional requests, and cache policy behavior.

### What Is Out of Scope:
- General debugging of unrelated Flutter or Dart application code.
- Custom backend or third-party cloud infrastructure debugging (e.g. configuring AWS CloudFront distributions, custom Nginx configurations, or DNS propagation outside package interfaces).
- Third-party packages not maintained as part of MetaMantle.

