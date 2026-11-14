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
    this.manifestPath,
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
  final String? manifestPath;

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
    String? manifestPath,
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
      manifestPath: manifestPath ?? this.manifestPath,
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
    this.routesDiscovered = 0,
    this.routesRendered = 0,
    this.componentsSerialized = 0,
    this.dynamicRoutes = 0,
    this.metadataErrors = 0,
    this.unsupportedComponents = 0,
    this.missingRouteContent = 0,
  });

  final bool success;
  final BuildMode mode;
  final List<String> routes;
  final List<String> generatedFiles;
  final List<String> warnings;
  final int durationMs;
  final String? reportPath;

  final int routesDiscovered;
  final int routesRendered;
  final int componentsSerialized;
  final int dynamicRoutes;
  final int metadataErrors;
  final int unsupportedComponents;
  final int missingRouteContent;

  String toReportSummary() {
    final status = success ? 'SUCCESS' : 'FAILED';
    final buffer = StringBuffer();
    buffer.writeln('MetaMantle Build Report\n');
    buffer.writeln('Routes discovered:       $routesDiscovered');
    buffer.writeln('Routes rendered:         $routesRendered');
    buffer.writeln('Components serialized:   $componentsSerialized');
    buffer.writeln('Dynamic routes:          $dynamicRoutes');
    buffer.writeln('Metadata errors:         $metadataErrors');
    buffer.writeln('Unsupported components:  $unsupportedComponents');
    buffer.writeln('Missing route content:   $missingRouteContent\n');
    buffer.write('Status: $status');
    return buffer.toString();
  }

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
      'routesDiscovered': routesDiscovered,
      'routesRendered': routesRendered,
      'componentsSerialized': componentsSerialized,
      'dynamicRoutes': dynamicRoutes,
      'metadataErrors': metadataErrors,
      'unsupportedComponents': unsupportedComponents,
      'missingRouteContent': missingRouteContent,
    };
  }
}
