import 'dart:convert';
import 'dart:math' as math;

/// Core Web Vital metric names standardized by the W3C and Google Chrome UX Report (CrUX).
enum WebVitalName {
  /// Largest Contentful Paint (ms)
  lcp,

  /// Interaction to Next Paint (ms)
  inp,

  /// Cumulative Layout Shift (score)
  cls,

  /// First Contentful Paint (ms)
  fcp,

  /// Time to First Byte (ms)
  ttfb,
}

/// Google performance threshold rating.
enum MetricRating { good, needsImprovement, poor }

/// A privacy-preserving observation of a single Web Vital metric.
class WebVitalSample {
  const WebVitalSample({
    required this.name,
    required this.value,
    required this.path,
    required this.timestamp,
    this.connectionType,
  });

  final WebVitalName name;
  final double value;
  final String path;
  final DateTime timestamp;
  final String? connectionType;

  /// Sanitizes incoming URL path to ensure zero PII or sensitive query tokens are stored.
  static String sanitizePath(String rawUrlOrPath) {
    try {
      final uri = Uri.parse(rawUrlOrPath);
      return uri.path.isEmpty ? '/' : uri.path;
    } catch (_) {
      return rawUrlOrPath.split('?').first.split('#').first;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name.name.toUpperCase(),
    'value': value,
    'path': path,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (connectionType != null) 'connectionType': connectionType,
  };
}

/// Statistical summary for a specific Web Vital metric across recorded samples.
class MetricSummary {
  const MetricSummary({
    required this.name,
    required this.sampleCount,
    required this.p75,
    required this.p90,
    required this.p95,
    required this.min,
    required this.max,
    required this.rating,
  });

  final WebVitalName name;
  final int sampleCount;
  final double p75;
  final double p90;
  final double p95;
  final double min;
  final double max;
  final MetricRating rating;

  Map<String, dynamic> toJson() => {
    'metric': name.name.toUpperCase(),
    'sampleCount': sampleCount,
    'p75': double.parse(p75.toStringAsFixed(3)),
    'p90': double.parse(p90.toStringAsFixed(3)),
    'p95': double.parse(p95.toStringAsFixed(3)),
    'min': double.parse(min.toStringAsFixed(3)),
    'max': double.parse(max.toStringAsFixed(3)),
    'rating': rating.name,
  };
}

/// Aggregates and calculates Core Web Vitals percentiles according to Google standards.
class CoreWebVitalsCollector {
  CoreWebVitalsCollector({this.maxSamplesPerMetric = 10000});

  final int maxSamplesPerMetric;
  final Map<WebVitalName, List<WebVitalSample>> _samples = {
    for (final name in WebVitalName.values) name: [],
  };

  /// Records a new performance observation. Automatically strips any URL query parameters.
  void record({
    required WebVitalName name,
    required double value,
    required String path,
    DateTime? timestamp,
    String? connectionType,
  }) {
    final list = _samples[name]!;
    if (list.length >= maxSamplesPerMetric) {
      list.removeAt(0); // Bounded ring-buffer retention
    }
    list.add(
      WebVitalSample(
        name: name,
        value: value,
        path: WebVitalSample.sanitizePath(path),
        timestamp: timestamp ?? DateTime.now().toUtc(),
        connectionType: connectionType,
      ),
    );
  }

  /// Evaluates Google Chrome CrUX rating thresholds.
  static MetricRating rate(WebVitalName name, double p75Value) {
    switch (name) {
      case WebVitalName.lcp:
        if (p75Value <= 2500) return MetricRating.good;
        if (p75Value <= 4000) return MetricRating.needsImprovement;
        return MetricRating.poor;

      case WebVitalName.inp:
        if (p75Value <= 200) return MetricRating.good;
        if (p75Value <= 500) return MetricRating.needsImprovement;
        return MetricRating.poor;

      case WebVitalName.cls:
        if (p75Value <= 0.1) return MetricRating.good;
        if (p75Value <= 0.25) return MetricRating.needsImprovement;
        return MetricRating.poor;

      case WebVitalName.fcp:
        if (p75Value <= 1800) return MetricRating.good;
        if (p75Value <= 3000) return MetricRating.needsImprovement;
        return MetricRating.poor;

      case WebVitalName.ttfb:
        if (p75Value <= 800) return MetricRating.good;
        if (p75Value <= 1800) return MetricRating.needsImprovement;
        return MetricRating.poor;
    }
  }

  /// Calculates statistical summaries and CrUX ratings across all collected metrics.
  Map<WebVitalName, MetricSummary> summarize() {
    final report = <WebVitalName, MetricSummary>{};

    for (final entry in _samples.entries) {
      final metricName = entry.key;
      final samples = entry.value;

      if (samples.isEmpty) {
        report[metricName] = MetricSummary(
          name: metricName,
          sampleCount: 0,
          p75: 0.0,
          p90: 0.0,
          p95: 0.0,
          min: 0.0,
          max: 0.0,
          rating: MetricRating.good,
        );
        continue;
      }

      final values = samples.map((s) => s.value).toList()..sort();
      final count = values.length;

      final p75 = _percentile(values, 0.75);
      final p90 = _percentile(values, 0.90);
      final p95 = _percentile(values, 0.95);
      final minVal = values.first;
      final maxVal = values.last;

      report[metricName] = MetricSummary(
        name: metricName,
        sampleCount: count,
        p75: p75,
        p90: p90,
        p95: p95,
        min: minVal,
        max: maxVal,
        rating: rate(metricName, p75),
      );
    }

    return report;
  }

  /// Generates a standardized JSON report suitable for CI/CD checks and monitoring dashboards.
  String toJsonReport() {
    final summaries = summarize();
    final jsonMap = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'metrics': summaries.map(
        (k, v) => MapEntry(k.name.toUpperCase(), v.toJson()),
      ),
    };
    return const JsonEncoder.withIndent('  ').convert(jsonMap);
  }

  /// Clears all stored observations.
  void clear() {
    for (final list in _samples.values) {
      list.clear();
    }
  }

  static double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0.0;
    if (sortedValues.length == 1) return sortedValues.first;
    final index = (percentile * (sortedValues.length - 1)).round();
    return sortedValues[math.min(index, sortedValues.length - 1)];
  }
}
