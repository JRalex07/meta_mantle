# MetaMantle Deployment Guide

MetaMantle's static pre-rendering outputs standard HTML, CSS, JavaScript, and WebAssembly assets that deploy effortlessly to any static hosting provider or container platform.

---

## 1. Firebase Hosting

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "headers": [
      {
        "source": "**/*.@(wasm)",
        "headers": [
          {
            "key": "Content-Type",
            "value": "application/wasm"
          }
        ]
      }
    ]
  }
}
```

Deploy:
```bash
firebase deploy --only hosting
```

---

## 2. Vercel

Place `vercel.json` in your repository root:

```json
{
  "outputDirectory": "build/web",
  "cleanUrls": true,
  "trailingSlash": false
}
```

---

## 3. Cloudflare Pages & Netlify

Set build settings:
- **Build Command**: `flutter build web --release && dart run meta_mantle build-web --mode=hybrid`
- **Publish Directory**: `build/web`
