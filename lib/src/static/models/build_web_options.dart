/// Operational mode for the Flutter Web build engine.
enum BuildMode {
  /// Mode A: Injects route-specific metadata and SEO assets into index.html copies.
  /// Preserves standard Flutter Web client-side rendering without static HTML body.
  metadata,

  /// Mode B: Generates semantic HTML snapshots from supported MantleComponent trees
  /// alongside complete metadata and structured data. Flutter mounts over the static HTML.
  prerender,

  /// Mode C: Generates static semantic HTML snapshots and coordinates with Flutter's
  /// bootstrap system via an explicit client-ready handshake to prevent blank screens
  /// and duplicate content.
  hybrid;

  static BuildMode fromString(String? name) {
    switch (name?.toLowerCase()) {
      case 'metadata':
      case 'meta':
        return BuildMode.metadata;
      case 'prerender':
      case 'pre-render':
      case 'ssg':
        return BuildMode.prerender;
      case 'hybrid':
      case 'coordinated':
        return BuildMode.hybrid;
      default:
        return BuildMode.prerender;
    }
  }
}

/// Options configuring the [FlutterWebBuildEngine] build process.
class BuildWebOptions {
  const BuildWebOptions({
    this.mode = BuildMode.prerender,
    this.release = true,
    this.debug = false,
    this.output = 'build/web',
    this.baseHref = '/',
    this.wasm = false,
    this.verbose = false,
    this.dryRun = false,
    this.clean = false,
    this.strict = false,
    this.configPath = 'meta_mantle.config.json',
    this.projectDir = '.',
  });

  final BuildMode mode;
  final bool release;
  final bool debug;
  final String output;
  final String baseHref;
  final bool wasm;
  final bool verbose;
  final bool dryRun;
  final bool clean;
  final bool strict;
  final String configPath;
  final String projectDir;

  BuildWebOptions copyWith({
    BuildMode? mode,
    bool? release,
    bool? debug,
    String? output,
    String? baseHref,
    bool? wasm,
    bool? verbose,
    bool? dryRun,
    bool? clean,
    bool? strict,
    String? configPath,
    String? projectDir,
  }) {
    return BuildWebOptions(
      mode: mode ?? this.mode,
      release: release ?? this.release,
      debug: debug ?? this.debug,
      output: output ?? this.output,
      baseHref: baseHref ?? this.baseHref,
      wasm: wasm ?? this.wasm,
      verbose: verbose ?? this.verbose,
      dryRun: dryRun ?? this.dryRun,
      clean: clean ?? this.clean,
      strict: strict ?? this.strict,
      configPath: configPath ?? this.configPath,
      projectDir: projectDir ?? this.projectDir,
    );
  }
}

/// Result of executing [FlutterWebBuildEngine.build].
class FlutterWebBuildResult {
  const FlutterWebBuildResult({
    required this.success,
    required this.mode,
    required this.routes,
    required this.generatedFiles,
    required this.warnings,
    required this.durationMs,
    this.reportPath,
  });

  final bool success;
  final BuildMode mode;
  final List<String> routes;
  final List<String> generatedFiles;
  final List<String> warnings;
  final int durationMs;
  final String? reportPath;

  Map<String, Object?> toJson() {
    return {
      'success': success,
      'mode': mode.name,
      'routesCount': routes.length,
      'routes': routes,
      'generatedFilesCount': generatedFiles.length,
      'generatedFiles': generatedFiles,
      'warningsCount': warnings.length,
      'warnings': warnings,
      'durationMs': durationMs,
      if (reportPath != null) 'reportPath': reportPath,
    };
  }
}
