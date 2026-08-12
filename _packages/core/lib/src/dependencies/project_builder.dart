import '../models/project.dart';
import '../parsers/pubspec_lock_parser.dart';
import '../parsers/pubspec_parser.dart';
import 'dependency_merger.dart';

/// Assembles a complete [Project] from already-parsed pubspec data.
///
/// This is the seam between the pure, I/O-free `parsers`/`dependencies`
/// layers and whatever reads files from disk (CLI, API) — this class
/// takes parsed data in, not file paths, so it stays trivially
/// testable with in-memory fixtures.
class ProjectBuilder {
  const ProjectBuilder._();

  /// Builds a [Project] for the project rooted at [rootPath].
  ///
  /// [lockData] is optional: pass null when no `pubspec.lock` is
  /// available (see [DependencyMerger.merge] for what that means for
  /// the resulting dependency list).
  static Project build({
    required String rootPath,
    required PubspecData pubspecData,
    PubspecLockData? lockData,
  }) {
    return Project(
      name: pubspecData.name,
      rootPath: rootPath,
      environment: pubspecData.environment,
      dependencies: DependencyMerger.merge(pubspecData, lockData),
    );
  }
}
