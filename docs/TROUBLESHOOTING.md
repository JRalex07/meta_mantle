# Troubleshooting Guide

Common questions, integration pitfalls, and solutions when working with `meta_mantle`.

---

## 1. Metadata not updating on tab navigation (`IndexedStack` / `TabBarView`)

### Symptom:
When switching between tabs in an `IndexedStack` or bottom navigation bar, the browser `<title>` and `<meta>` tags remain stuck on the first tab.

### Cause:
`IndexedStack` keeps all child widgets mounted simultaneously. Because each tab's widget remains in the tree, their `dispose()` callbacks do not fire. The first mounted widget or the most recently updated tab retains ownership of the metadata scope.

### Solution:
Pass the active status to `MetaHead`:
```dart
MetaHead(
  active: _selectedTabIndex == 0,
  metadata: const WebMetadata(title: 'Home Tab'),
  child: HomeTab(),
);
```

---

## 2. Social scrapers (Twitter, Facebook, WhatsApp) not displaying link previews

### Symptom:
When sharing a URL on social networks or messaging apps, the link preview is blank or shows the generic title from `web/index.html`.

### Cause:
Most social bots (Twitterbot, Facebook Crawler, Slackbot) do not execute Flutter's compiled JavaScript. They perform a simple HTTP GET request and inspect the initial HTML document payload.

### Solution:
Use MetaMantle's static generation engine:
1. Compile your web release: `flutter build web --release`
2. Run the generator:
   ```bash
   dart run meta_mantle build --config meta_mantle.config.json --strict
   ```
3. Deploy the resulting `build/web` directory containing pre-rendered route files (`about/index.html`, etc.).

---

## 3. Server rewrite rules serving root `index.html` instead of static route HTML

### Symptom:
You ran `meta_mantle build` and generated `about/index.html`, but visiting `https://example.com/about` still returns the root metadata.

### Cause:
Your hosting provider (Firebase, Netlify, Vercel, Nginx) is configured with a catch-all rewrite rule that sends all requests to `/index.html` without checking if a static file exists on disk first.

### Solution:
Ensure filesystem checks precede rewrites:
- **Firebase:** Ensure `"cleanUrls": true` is set in `firebase.json`.
- **Vercel:** Add `{"handle": "filesystem"}` before your rewrite rules in `vercel.json`.
- **Nginx:** Use `try_files $uri $uri/ /index.html;`.

---

## 4. Root `index.html` overwritten during static generation

### Symptom:
Running `dart run meta_mantle build --input build/web --output build/web` overwrites `build/web/index.html`.

### Explanation:
The generator injects root route (`/`) metadata directly into the entrypoint `index.html`. To re-generate fresh templates:
1. Re-run `flutter build web --release` to emit a pristine `index.html`.
2. Run `dart run meta_mantle build`.

---

## 5. "Missing Flutter bootstrap script" error during build

### Symptom:
The builder halts with:
`FAIL: Missing Flutter bootstrap initialization script in template index.html.`

### Cause:
MetaMantle requires a recognizable Flutter initialization marker to ensure generated HTML shells correctly boot the Flutter engine. Supported markers include:
- `<script src="flutter_bootstrap.js" ...>`
- `{{flutter_bootstrap_js}}`
- `{{flutter_js}}`
- `{{flutter_build_config}}`

### Solution:
Ensure your `web/index.html` contains the standard Flutter Web bootstrap script or template placeholders before running `flutter build web`.
