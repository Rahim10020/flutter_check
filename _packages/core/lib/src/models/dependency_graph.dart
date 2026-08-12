import 'constraint.dart';
import 'dependency.dart';
import 'package.dart';

/// A directed edge in a [DependencyGraph]: `from` requires `to` to
/// satisfy `constraint`.
class DependencyEdge {
  final Package from;
  final Package to;
  final Constraint constraint;

  const DependencyEdge({
    required this.from,
    required this.to,
    required this.constraint,
  });

  @override
  String toString() => '${from.name} → ${to.name} ($constraint)';
}

/// A directed graph of package dependency relationships for a project.
///
/// Nodes are keyed by package name. This is a plain data structure
/// produced by the `dependencies`/`graph` layer and consumed by the
/// `analyzer` and, later, the `resolver` — it doesn't perform any
/// resolution itself.
class DependencyGraph {
  /// All dependencies in the graph, keyed by package name.
  final Map<String, Dependency> nodes;

  /// All "requires" relationships between packages.
  final List<DependencyEdge> edges;

  const DependencyGraph({required this.nodes, required this.edges});

  /// What [packageName] directly requires.
  Iterable<DependencyEdge> requirementsOf(String packageName) =>
      edges.where((e) => e.from.name == packageName);

  /// What directly requires [packageName].
  Iterable<DependencyEdge> dependentsOf(String packageName) =>
      edges.where((e) => e.to.name == packageName);

  @override
  String toString() =>
      'DependencyGraph(${nodes.length} packages, ${edges.length} edges)';
}
