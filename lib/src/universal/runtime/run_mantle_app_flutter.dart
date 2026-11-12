import 'package:material_ui/material_ui.dart';

import '../../runtime/meta_mantle.dart';
import '../rendering/flutter_renderer.dart';
import '../routing/mantle_route.dart';

/// Launches a [MantleApp] using the Flutter rendering engine.
/// Used on Android, iOS, Desktop, and Flutter Web compatibility mode.
void runMantleApp(MantleApp app) {
  runApp(MantleFlutterAppWidget(app: app));
}

class MantleFlutterAppWidget extends StatefulWidget {
  const MantleFlutterAppWidget({required this.app, super.key});

  final MantleApp app;

  @override
  State<MantleFlutterAppWidget> createState() => _MantleFlutterAppWidgetState();
}

class _MantleFlutterAppWidgetState extends State<MantleFlutterAppWidget> {
  late String _currentPath;
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.app.initialPath;
    _history.add(_currentPath);

    // Coordinate transition from static HTML snapshot to interactive Flutter view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MetaMantle.markReady();
    });
  }

  void _navigateTo(String path, {Map<String, String>? queryParameters}) {
    setState(() {
      _currentPath = path;
      _history.add(path);
    });
  }

  void _navigateBack() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _currentPath = _history.last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.app.router.match(_currentPath);

    final navContext = MantleNavigationContext(
      currentPath: _currentPath,
      pathParameters: match?.pathParameters ?? const {},
      queryParameters: match?.queryParameters ?? const {},
      onGo: _navigateTo,
      onBack: _navigateBack,
    );

    Widget contentWidget;
    if (match != null) {
      final component = match.build(navContext);
      final mantleNode = component.toNode(navContext);
      contentWidget = const MantleFlutterRenderer().render(mantleNode);
    } else {
      contentWidget = const Center(
        child: Text('404 - Page Not Found', style: TextStyle(fontSize: 20)),
      );
    }

    return MaterialApp(
      title: widget.app.title,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SafeArea(child: contentWidget)),
    );
  }
}
