import 'seo_policy.dart';

/// Diagnostic provenance record tracking where resolved metadata properties originated.
class PolicyProvenance {
  PolicyProvenance({
    required this.fieldOrigins,
    this.conflicts = const [],
    this.appliedPolicies = const [],
  });

  /// Map of field name (e.g. 'title', 'description', 'robots') to the policy tier that decided it.
  final Map<String, PolicyTier> fieldOrigins;

  /// Any policy conflicts or overridden directives detected during resolution.
  final List<String> conflicts;

  /// Ordered list of policies that participated in resolution.
  final List<SeoPolicy> appliedPolicies;

  PolicyTier? originOf(String field) => fieldOrigins[field];

  Map<String, dynamic> toDiagnosticMap() => {
    'fieldOrigins': fieldOrigins.map((k, v) => MapEntry(k, v.name)),
    'conflicts': conflicts,
    'appliedPolicies': appliedPolicies
        .map((p) => p.name ?? p.tier.name)
        .toList(),
  };
}
