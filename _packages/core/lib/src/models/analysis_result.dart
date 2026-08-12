import 'dependency_graph.dart';
import 'fix.dart';
import 'issue.dart';
import 'project.dart';
import 'recommendation.dart';

/// The complete output of analyzing a [Project]: what was found, what's
/// wrong, and what can be done about it.
///
/// This is the top-level object the CLI, API, and Web all consume —
/// none of them should need to re-derive this information themselves.
class AnalysisResult {
  final Project project;
  final DependencyGraph graph;
  final List<Issue> issues;
  final List<Recommendation> recommendations;

  /// Concrete fixes, once the resolver/fixes layers have run. Empty if
  /// only analysis (not fix-generation) was requested.
  final List<Fix> fixes;

  final DateTime analyzedAt;

  const AnalysisResult({
    required this.project,
    required this.graph,
    required this.issues,
    required this.recommendations,
    required this.analyzedAt,
    this.fixes = const [],
  });

  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);

  bool get isClean => issues.isEmpty;

  @override
  String toString() =>
      'AnalysisResult(${project.name}: ${issues.length} issues, ${recommendations.length} recommendations)';
}
