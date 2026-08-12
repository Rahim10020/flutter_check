import '../models/constraint.dart';
import '../models/dependency_graph.dart';
import '../models/package.dart';
import '../models/project.dart';

/// Builds a [DependencyGraph] from a [Project].
///
/// Only edges backed by actual declared data are included: the
/// project's own requirements on its direct dependencies. Transitive
/// packages are present as nodes (we know they exist, from
/// `pubspec.lock`) but have no incoming edges yet — knowing *which*
/// package requires a given transitive dependency requires reading
/// that package's own pubspec, which needs a metadata source (pub.dev
/// or the local package cache) not yet built. See the project's
/// research step before the resolver.
class GraphBuilder {
  const GraphBuilder._();

  static DependencyGraph build(Project project) {
    final nodes = {for (final d in project.dependencies) d.package.name: d};

    final edges = <DependencyEdge>[
      for (final d in project.directDependencies)
        DependencyEdge(
          from: Package.project(project.name),
          to: d.package,
          // No declared constraint (e.g. an SDK or path dependency
          // with no version) is represented as "any version
          // accepted", which is what it actually means.
          constraint: d.constraint ?? Constraint.any(),
        ),
    ];

    return DependencyGraph(nodes: nodes, edges: edges);
  }
}
