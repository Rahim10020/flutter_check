import 'dependency.dart';
import 'environment.dart';

/// A parsed Flutter/Dart project: its identity, declared SDK
/// environment, and the dependencies extracted from its
/// `pubspec.yaml` and (when available) `pubspec.lock`.
class Project {
  /// The project name, as declared in `pubspec.yaml`.
  final String name;

  /// Absolute path to the project's root directory on disk.
  final String rootPath;

  final Environment environment;

  /// All dependencies found, merging what was declared in
  /// `pubspec.yaml` with what was locked in `pubspec.lock`, when both
  /// are available.
  final List<Dependency> dependencies;

  const Project({
    required this.name,
    required this.rootPath,
    required this.environment,
    required this.dependencies,
  });

  Iterable<Dependency> get directDependencies =>
      dependencies.where((d) => d.isDirect);

  Iterable<Dependency> get transitiveDependencies =>
      dependencies.where((d) => d.isTransitive);

  /// Finds the dependency for a package by name, if present.
  Dependency? dependencyNamed(String packageName) {
    for (final d in dependencies) {
      if (d.package.name == packageName) return d;
    }
    return null;
  }

  @override
  String toString() => 'Project($name, ${dependencies.length} dependencies)';
}
