# Hosting & Deployment Architecture

MetaMantle supports multiple hosting targets depending on the deployment strategy (Static Pre-rendering vs. Dynamic SSR).

---

## 1. Static Deployments (Engine B)

Pre-rendered static builds (`build/web`) can be deployed to any static host:

### GitHub Pages:
- Static HTML is generated with `--output=build/web`.
- A custom 404 handler (`404.html`) and `.nojekyll` are included.
- Automated via GitHub Actions (`.github/workflows/deploy.yml`).

### Firebase Hosting:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Cloudflare Pages / Vercel / Netlify:
Serve `build/web` with standard static routing rules and cache headers.

---

## 2. Dynamic SSR Deployments (Engine C)

For dynamic server-rendered sites, package the Dart application into a lightweight Docker container:

### `Dockerfile`:
```dockerfile
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/build/web /app/build/web

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
```

### Cloud Run / AWS Fargate / Fly.io:
Deploy the container with horizontal autoscaling. With in-memory or Redis caching, single container instances handle thousands of requests per second with negligible memory footprints (~25MB RSS).

