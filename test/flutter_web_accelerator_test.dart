import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('FlutterWebAccelerator Tests', () {
    const accelerator = FlutterWebAccelerator();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('accelerator_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('analyzes non-Flutter project gracefully', () async {
      final report = await accelerator.analyze(projectDir: tempDir);
      expect(report.isFlutterProject, isFalse);
      expect(report.supportsWasm, isFalse);
      expect(report.findings.length, equals(1));
      expect(report.findings.first.category, equals('project'));
    });

    test(
      'analyzes Flutter project with modern bootstrap and Wasm readiness',
      () async {
        // 1. Create pubspec.yaml
        final pubspec = File('${tempDir.path}/pubspec.yaml');
        await pubspec.writeAsString('''
name: sample_web_app
dependencies:
  flutter:
    sdk: flutter
  web: ^1.0.0
''');

        // 2. Create web/index.html with modern bootstrap and resource hints
        final webDir = Directory('${tempDir.path}/web');
        await webDir.create();
        final indexHtml = File('${webDir.path}/index.html');
        await indexHtml.writeAsString('''
<!DOCTYPE html>
<html>
<head>
  <link rel="preconnect" href="https://fonts.gstatic.com">
  <script src="flutter_bootstrap.js" async></script>
</head>
<body>
</body>
</html>
''');

        // 3. Create build/web with sample wasm binary
        final buildWebDir = Directory('${tempDir.path}/build/web');
        await buildWebDir.create(recursive: true);
        final wasmFile = File('${buildWebDir.path}/main.dart.wasm');
        await wasmFile.writeAsBytes(List.filled(1024, 0)); // 1 KB

        final report = await accelerator.analyze(
          projectDir: tempDir,
          webBuildDir: buildWebDir,
        );

        expect(report.isFlutterProject, isTrue);
        expect(report.supportsWasm, isTrue);
        expect(report.usesModernBootstrap, isTrue);
        expect(report.bundleMetrics['main.dart.wasm'], equals(1024));

        // Should have info finding about Wasm availability
        expect(
          report.findings.any(
            (f) => f.title.contains('WebAssembly Binary Available'),
          ),
          isTrue,
        );
      },
    );

    test('detects legacy dart:html dependencies that block Wasm', () async {
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('''
name: legacy_web_app
dependencies:
  flutter:
    sdk: flutter
  legacy_pkg:
    # uses dart:html
    git: https://github.com/example/dart:html
''');

      final report = await accelerator.analyze(projectDir: tempDir);
      expect(report.isFlutterProject, isTrue);
      expect(report.supportsWasm, isFalse);
      expect(
        report.findings.any(
          (f) => f.title.contains('Legacy Web Dependencies Detected'),
        ),
        isTrue,
      );
    });

    test('detects oversized JavaScript bundle in build directory', () async {
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString(
        'name: large_app\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );

      final buildWebDir = Directory('${tempDir.path}/build/web');
      await buildWebDir.create(recursive: true);
      final largeJs = File('${buildWebDir.path}/main.dart.js');
      // Create 3MB file
      await largeJs.writeAsBytes(List.filled(3 * 1024 * 1024, 65));

      final report = await accelerator.analyze(
        projectDir: tempDir,
        webBuildDir: buildWebDir,
      );

      expect(
        report.findings.any((f) => f.title.contains('Large JavaScript Bundle')),
        isTrue,
      );
    });

    test(
      'provides COOP and COEP server headers for Skwasm multi-threading',
      () {
        final headers = accelerator.getRecommendedServerHeaders();
        expect(headers['Cross-Origin-Embedder-Policy'], equals('require-corp'));
        expect(headers['Cross-Origin-Opener-Policy'], equals('same-origin'));
        expect(headers['Cache-Control'], isNotNull);
      },
    );

    test(
      'suggests optimized build command with Wasm and icon tree shaking',
      () {
        final cmd = accelerator.suggestOptimizedBuildCommand(
          wasm: true,
          stripUnusedFonts: true,
        );
        expect(cmd, equals('flutter build web --wasm --tree-shake-icons'));

        final cmdNoWasm = accelerator.suggestOptimizedBuildCommand(
          wasm: false,
          stripUnusedFonts: false,
        );
        expect(cmdNoWasm, equals('flutter build web'));
      },
    );
  });
}
