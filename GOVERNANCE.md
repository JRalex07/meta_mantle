# MetaMantle Project Governance

This document describes the governance model, decision-making processes, release management, and maintenance responsibilities for the **MetaMantle** open-source project.

---

## 1. Project Roles & Responsibilities

### Maintainers
Maintainers are responsible for the technical direction, code quality, security posture, and lifecycle of MetaMantle.
Responsibilities include:
- Reviewing and merging pull requests.
- Enforcing test coverage, code formatting, and strict static analysis standards.
- Managing releases, version increments, and changelog accuracy.
- Triaging and patching security vulnerabilities.
- Upholding the [Code of Conduct](CODE_OF_CONDUCT.md).

### Contributors
Contributors are community members who submit pull requests, author documentation, report issues, or propose architectural improvements.

---

## 2. Decision-Making & Architectural Consensus

MetaMantle adheres to a consensus-driven technical model guided by the following principles:

1. **Verification-First Engineering:** Features must be backed by working, executable automated tests. Unverified integrations or speculative abstractions are rejected.
2. **Tripartite Boundary Integrity:** Modifications must preserve clean architectural isolation between:
   - Pure Dart Core (`meta_mantle_core.dart`)
   - Native Dart Server Engine (`meta_mantle_server.dart`)
   - Flutter Runtime Widgets (`meta_mantle.dart`)
3. **Backward Compatibility & Semantic Versioning:** All public API additions, deprecations, and modifications follow [Semantic Versioning 2.0.0](https://semver.org/) and the [API Stability Policy](docs/API_STABILITY.md).

---

## 3. Pull Request Review & Merge Criteria

Before any pull request can be merged into the `main` branch, it must satisfy all of the following requirements:

1. **Automated CI Validation:**
   - `dart format --output=none --set-exit-if-changed .` passes with 0 modifications.
   - `flutter analyze` reports 0 issues across all workspaces.
   - `flutter test` passes 100% of all unit and integration tests.
   - `dart pub publish --dry-run` reports 0 errors.
2. **Review & Approval:** At least one maintainer must review and approve the changes.
3. **Documentation:** Any modified or added public APIs must be documented with Dart doc comments and reflected in relevant guides in `docs/`.
4. **No Secrets or Credentials:** Pull requests must be completely free of private API tokens, passwords, or live credentials.

---

## 4. Release Process & Versioning

- **Semantic Versioning:**
  - **MAJOR (X.0.0):** Incompatible public API changes.
  - **MINOR (0.X.0):** Backward-compatible feature additions or substantial enhancements.
  - **PATCH (0.0.X):** Backward-compatible bug fixes and security patches.
- **Pre-Release Checklist:** Releases must satisfy the formal verification criteria documented in [docs/RELEASE_READINESS.md](docs/RELEASE_READINESS.md).
- **Decoupled Deployments:** Official package releases on GitHub are independent of the separate marketing and documentation website deployment.
