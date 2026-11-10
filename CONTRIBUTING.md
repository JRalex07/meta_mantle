# Contributing to MetaMantle

Thank you for contributing to MetaMantle! Please follow these development guidelines:

1. Open an issue on GitHub describing the problem or proposed API change.
2. Keep the metadata core independent of Flutter and browser APIs where possible.
3. Do not use regular expressions to rewrite HTML documents; update a parsed DOM using `package:html`.
4. Do not use legacy `dart:html`; use modern `package:web` in browser-only adapters.
5. Add automated tests for runtime lifecycle, static generation, and security-sensitive serialization.
6. Verify your changes before submitting:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
7. Document behavior changes, limitations, and update the API reference accordingly.
