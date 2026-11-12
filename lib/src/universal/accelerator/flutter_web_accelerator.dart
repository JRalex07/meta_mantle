import 'dart:io';

/// Diagnostic issue or optimization recommendation for Flutter Web.
class WebOptimizationFinding {
  const WebOptimizationFinding({
    required this.severity, // info, warning, recommendation
    required this.category, // wasm, bundle, font, bootstrap, headers
    required this.title,
    required this.description,
    this.suggestedFix,
  });

  final String severity;
  final String category;
  final String title;
  final String description;
  final String? suggestedFix;

  Map<String, String?> toMap() => {
    'severity': severity,
    'category': category,
    'title': title,
    'description': description,
    'suggestedFix': suggestedFix,
  };
}

/// Comprehensive analysis report for Flutter Web applications.
class FlutterWebAnalysisReport {
  const FlutterWebAnalysisReport({
    required this.isFlutterProject,
    required this.supportsWasm,
    required this.usesModernBootstrap,
    required this.hasCrossOriginIsolationHeaders,
    required this.findings,
    required this.bundleMetrics,
  });

  final bool isFlutterProject;
  final bool supportsWasm;
  final bool usesModernBootstrap;
  final bool hasCrossOriginIsolationHeaders;
  final List<WebOptimizationFinding> findings;
  final Map<String, int> bundleMetrics; // file sizes in bytes

  Map<String, Object?> toMap() => {
    'isFlutterProject': isFlutterProject,
    'supportsWasm': supportsWasm,
    'usesModernBootstrap': usesModernBootstrap,
    'hasCrossOriginIsolationHeaders': hasCrossOriginIsolationHeaders,
    'findings': findings.map((f) => f.toMap()).toList(),
    'bundleMetrics': bundleMetrics,
  };

  String toSummaryText() {
    final buf = StringBuffer();
    buf.writeln('=== MetaMantle Flutter Web Analysis Report ===');
    buf.writeln(
      'Project: ${isFlutterProject ? "Valid Flutter Project" : "Not a Flutter Project"}',
    );
    buf.writeln('WebAssembly (Wasm) Ready: ${supportsWasm ? "YES" : "NO"}');
    buf.writeln(
      'Modern Bootstrap (flutter_bootstrap.js): ${usesModernBootstrap ? "YES" : "NO"}',
    );
    buf.writeln(
      'Cross-Origin Isolation (COOP/COEP): ${hasCrossOriginIsolationHeaders ? "Configured" : "Missing"}',
    );
    buf.writeln('');
    if (bundleMetrics.isNotEmpty) {
      buf.writeln('--- Bundle Metrics (build/web) ---');
      for (final e in bundleMetrics.entries) {
        final kb = (e.value / 1024).toStringAsFixed(1);
        buf.writeln('  - ${e.key}: $kb KB (${e.value} bytes)');
      }
      buf.writeln('');
    }
    buf.writeln('--- Optimization Recommendations (${findings.length}) ---');
    for (final f in findings) {
      buf.writeln('[${f.severity.toUpperCase()}] [${f.category}] ${f.title}');
      buf.writeln('  ${f.description}');
      if (f.suggestedFix != null) {
        buf.writeln('  Fix: ${f.suggestedFix}');
      }
    }
    return buf.toString();
  }
}

/// Accelerator and diagnostic toolkit for Flutter Web (Mode A).
/// Analyzes Flutter web builds, diagnoses Wasm compatibility, font/bundle weights,
/// and recommends multi-threaded Skwasm headers and bootstrap optimizations.
class FlutterWebAccelerator {
  const FlutterWebAccelerator();

  /// Analyzes a Flutter project at [projectDir].
  Future<FlutterWebAnalysisReport> analyze({
    required Directory projectDir,
    Directory? webBuildDir,
  }) async {
    final pubspec = File('${projectDir.path}/pubspec.yaml');
    final isFlutter = await pubspec.exists();

    final findings = <WebOptimizationFinding>[];
    final bundleMetrics = <String, int>{};

    var supportsWasm = true;
    var usesModernBootstrap = false;
    final hasIsolation = false;

    if (!isFlutter) {
      findings.add(
        const WebOptimizationFinding(
          severity: 'error',
          category: 'project',
          title: 'Missing pubspec.yaml',
          description: 'No pubspec.yaml found in the target directory.',
        ),
      );
      return FlutterWebAnalysisReport(
        isFlutterProject: false,
        supportsWasm: false,
        usesModernBootstrap: false,
        hasCrossOriginIsolationHeaders: false,
        findings: findings,
        bundleMetrics: bundleMetrics,
      );
    }

    // 1. Inspect pubspec for legacy web dependencies
    final pubspecContent = await pubspec.readAsString();
    if (pubspecContent.contains('dart:html') ||
        pubspecContent.contains('package:js')) {
      supportsWasm = false;
      findings.add(
        const WebOptimizationFinding(
          severity: 'warning',
          category: 'wasm',
          title: 'Legacy Web Dependencies Detected',
          description: 'Dependencies using legacy dart:html or package:js prevent dart2wasm compilation.',
          suggestedFix: 'Migrate to package:web and dart:js_interop for Wasm compatibility.',
        ),
      );
    }

    // 2. Inspect web/index.html
    final indexHtml = File('${projectDir.path}/web/index.html');
    if (await indexHtml.exists()) {
      final htmlContent = await indexHtml.readAsString();
      if (htmlContent.contains('flutter_bootstrap.js')) {
        usesModernBootstrap = true;
      } else {
        findings.add(
          const WebOptimizationFinding(
            severity: 'recommendation',
            category: 'bootstrap',
            title: 'Legacy Flutter Web Initialization',
            description: 'web/index.html uses legacy flutter.js initialization instead of modern flutter_bootstrap.js.',
            suggestedFix: 'Update web/index.html to use {{flutter_bootstrap_js}} for faster engine startup.',
          ),
        );
      }

      if (!htmlContent.contains('rel="preconnect"') &&
          !htmlContent.contains('rel="preload"')) {
        findings.add(
          const WebOptimizationFinding(
            severity: 'info',
            category: 'bootstrap',
            title: 'Resource Hints Recommended',
            description: 'web/index.html lacks preconnect or preload resource hints for CanvasKit or fonts.',
            suggestedFix: 'Add <link rel="preconnect" href="https://fonts.gstatic.com"> for font acceleration.',
          ),
        );
      }
    }

    // 3. Inspect build/web if present
    final buildWeb = webBuildDir ?? Directory('${projectDir.path}/build/web');
    if (await buildWeb.exists()) {
      var totalSize = 0;
      final basePath = buildWeb.path.replaceAll('\\', '/');
      await for (final entity in buildWeb.list(recursive: true)) {
        if (entity is File) {
          final size = await entity.length();
          final normEntityPath = entity.path.replaceAll('\\', '/');
          final relPath = normEntityPath.startsWith('$basePath/')
              ? normEntityPath.substring(basePath.length + 1)
              : normEntityPath;
          totalSize += size;

          if (relPath.endsWith('.js') ||
              relPath.endsWith('.wasm') ||
              relPath.endsWith('.ttf') ||
              relPath.endsWith('.otf') ||
              relPath.endsWith('.png') ||
              relPath == 'index.html') {
            bundleMetrics[relPath] = size;
          }
        }
      }
      bundleMetrics['total_bundle_size'] = totalSize;

      // Check for large main.dart.js
      final mainJsSize = bundleMetrics['main.dart.js'];
      if (mainJsSize != null && mainJsSize > 2 * 1024 * 1024) {
        findings.add(
          WebOptimizationFinding(
            severity: 'warning',
            category: 'bundle',
            title: 'Large JavaScript Bundle',
            description:
                'main.dart.js is ${(mainJsSize / (1024 * 1024)).toStringAsFixed(1)} MB. This impacts initial mobile download time.',
            suggestedFix: 'Compile with "flutter build web --wasm" to leverage compact WebAssembly binaries.',
          ),
        );
      }

      // Check for wasm binary
      if (bundleMetrics.keys.any((k) => k.endsWith('.wasm'))) {
        findings.add(
          const WebOptimizationFinding(
            severity: 'info',
            category: 'wasm',
            title: 'WebAssembly Binary Available',
            description: 'Native Wasm artifacts found in build/web. Ensure server emits COOP/COEP headers.',
            suggestedFix: 'Serve with Cross-Origin-Embedder-Policy: require-corp and Cross-Origin-Opener-Policy: same-origin.',
          ),
        );
      }
    }

    return FlutterWebAnalysisReport(
      isFlutterProject: true,
      supportsWasm: supportsWasm,
      usesModernBootstrap: usesModernBootstrap,
      hasCrossOriginIsolationHeaders: hasIsolation,
      findings: findings,
      bundleMetrics: bundleMetrics,
    );
  }

  /// Generates recommended server headers (e.g. for Shelf, Nginx, or Firebase Hosting)
  /// required for high-performance multi-threaded Skwasm WebAssembly execution.
  Map<String, String> getRecommendedServerHeaders() => {
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cache-Control': 'public, max-age=3600',
    'X-Content-Type-Options': 'nosniff',
  };

  /// Suggests the optimized Flutter CLI build command.
  String suggestOptimizedBuildCommand({
    bool wasm = true,
    bool stripUnusedFonts = true,
  }) {
    final buffer = StringBuffer('flutter build web');
    if (wasm) {
      buffer.write(' --wasm');
    }
    if (stripUnusedFonts) {
      buffer.write(' --tree-shake-icons');
    }
    return buffer.toString();
  }
}
