# Security Policy

MetaMantle treats software security and data protection as critical engineering priorities. This framework operates across client-side Flutter Web browsers, static build pipelines, and production server environments (SSR), making layered security defenses essential.

---

## 1. Supported Versions

Security updates are provided for the following versions:

| Version | Supported | Notes |
| :--- | :--- | :--- |
| `0.1.x` | :white_check_mark: | Current active release branch (`main`) |
| `< 0.1.0` | :x: | Unsupported pre-release tags |

---

## 2. Reporting a Vulnerability

If you discover a potential security vulnerability in MetaMantle, please report it responsibly.

### Responsible Disclosure Process:
1. **Do NOT open a public GitHub issue.** Public issues expose the vulnerability before a patch can be developed and validated.
2. **Submit via GitHub Private Vulnerability Reporting:**
   - Navigate to the repository: [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
   - Click the **Security** tab.
   - Click **Report a vulnerability** to open an encrypted advisory draft.
3. **Information to Include:**
   - Type of vulnerability (e.g., SSRF, XSS, Host Injection, Cache Poisoning, Denial of Service).
   - Component affected (`MetaMantleServerEngine`, `SsrfGuard`, `MetadataRenderer`, `TenantHostValidator`, etc.).
   - Minimal reproduction script, test case, or HTTP request payload.
   - Potential impact and mitigation recommendations if known.

### Response Timeline:
- **Initial Response:** Within 48 hours of report submission.
- **Triage & Assessment:** Within 5 business days.
- **Fix & Advisory Release:** Scheduled promptly based on severity (Critical/High issues prioritized).

---

## 3. Core Security Guarantees & Built-In Defenses

MetaMantle is engineered with several native security boundaries:

### 1. In-Line SSRF Protection (`SsrfGuard`)
Outbound HTTP requests executed by `RestDataProvider` and `GraphQLDataProvider` pass through `SsrfGuard.validateUri()` before socket connections are established:
- Loopback addresses (`127.0.0.1`, `::1`) are blocked.
- Private RFC 1918 subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) are blocked by default.
- Cloud instance metadata addresses (`169.254.169.254`, AWS/GCP/Azure endpoints) are blocked.
- DNS resolution checks prevent DNS rebinding attacks.

### 2. Host Header Injection Defense (`TenantHostValidator`)
`MetaMantleServerEngine` validates incoming HTTP `Host` headers against an explicit tenant registry and root domain allowlists:
- Missing or unauthorized `Host` headers immediately produce `400 Bad Request`.
- Untrusted `x-tenant-id` request headers are ignored.
- Cache keys are strictly partitioned by validated tenant context to prevent cross-tenant cache poisoning.

### 3. Response Stream Memory Bounds
- `RestDataProvider` and `GraphQLDataProvider` accumulate response bytes chunk-by-chunk using `BytesBuilder`.
- Streams exceeding `maxResponseSizeBytes` (default 2MB) abort immediately with a `StateError` before consuming heap memory.

### 4. Context-Aware HTML & JSON-LD Escaping
- `MetadataRenderer` escapes attribute values and text content using HTML entity encoding (`&`, `<`, `>`, `"`, `'`).
- Structured data in `<script type="application/ld+json">` is serialized with Unicode character escaping (`\u003c`, `\u003e`, `\u0026`) to neutralize script tag breakout attacks (`</script><script>...`).

### 5. Path Traversal Guards
- Static site generators validate routes and file targets against directory traversal attacks (`..`).

---

## 4. Secret Handling & Credentials

- **Zero Secrets in Repository:** The MetaMantle codebase, examples, tests, and documentation do not contain live private API keys, cloud tokens, database passwords, or private certificates.
- **Testing with Mocks:** All tests must use `MockClient`, `MemoryDataProvider`, or clearly designated dummy test strings (`test-token-xyz`).
- **Template Configuration:** Developers requiring local environment secrets should copy `.env.example` to `.env` (which is excluded by `.gitignore`).
