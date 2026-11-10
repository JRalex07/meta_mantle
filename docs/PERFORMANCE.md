# Performance & Benchmark Profile

MetaMantle is engineered for high throughput, predictable memory consumption, and zero runtime overhead in production.

---

## 1. Verified Benchmarks

The benchmark suite (`test/large_catalogue_benchmark_test.dart`) evaluates MetaMantle across three core dimensions:

### 1. 1,000 Dynamic SSR Routes
- **Sequential Cache Misses**:
  - Full HTML document rendering + SHA-256 ETag calculation + Tag cache storage.
  - Throughput: **>100 pages/second** in unoptimized debug JIT; **>1,500 pages/second** in AOT compiled native executable (`dart compile exe`).
- **Sequential Cache Hits**:
  - Direct memory lookup + ETag matching + 304 evaluation.
  - Throughput: **>2,000 pages/second** in debug mode; **>25,000 pages/second** in native AOT execution.

### 2. 10,000 Route Sitemap Scaling
- Full XML generation of 10,000 URLs with `<loc>`, `<lastmod>`, `<priority>`, and `<changefreq>`.
- Payload: **>500 KB** valid XML.
- Processing Duration: **<1,000 ms** (typically ~180 ms).

### 3. 50,000 Route Chunked Index
- Parsing and chunking 50,000 entries into 5 sub-sitemaps (10,000 entries each) + 1 master `sitemap_index.xml`.
- Total generated files: **6 XML files**.
- Processing Duration: **<2,000 ms** (typically ~620 ms).

---

## 2. Memory Bounds & LRU Eviction

`MemoryCacheStore` enforces strict boundary rules:
- Maximum entry cap (`maxEntries: 2000`).
- Pruning strategy: Removes least-recently-used records when capacity is reached.
- Heap impact: ~20MB for 5,000 fully hydrated HTML document entries.

