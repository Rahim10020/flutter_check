import '../models/dependency.dart';
import '../parsers/pubspec_lock_parser.dart';
import '../parsers/pubspec_parser.dart';

/// Merges what was declared in `pubspec.yaml` with what was resolved
/// in `pubspec.lock` into a single, complete list of [Dependency].
///
/// When a lockfile is available, it is the authoritative source for
/// *which* packages exist (including transitive ones — something
/// `pubspec.yaml` alone can never reveal) and for their resolved
/// [DependencyKind]. `pubspec.yaml` remains the authoritative source
/// for the *declared constraint* on direct dependencies.
class DependencyMerger {
  const DependencyMerger._();

  /// Produces the merged dependency list for a project.
  ///
  /// If [lockData] is null (no `pubspec.lock` present, e.g. `pub get`
  /// was never run), only the directly declared dependencies from
  /// [pubspecData] are returned — transitive dependencies and resolved
  /// versions are simply unknowable without a lockfile.
  static List<Dependency> merge(
    PubspecData pubspecData,
    PubspecLockData? lockData,
  ) {
    if (lockData == null) {
      return pubspecData.dependencies;
    }

    final declared = {
      for (final d in pubspecData.dependencies) d.package.name: d,
    };

    final result = <Dependency>[];
    final handled = <String>{};

    for (final entry in lockData.packages.entries) {
      final name = entry.key;
      final locked = entry.value;
      final declaredDep = declared[name];

      result.add(
        Dependency(
          // Prefer the pubspec's own package description (e.g. its git
          // URL as the developer wrote it) when available; fall back to
          // what the lockfile recorded otherwise.
          package: declaredDep?.package ?? locked.package,
          kind: locked.kind,
          constraint: declaredDep?.constraint,
          resolvedVersion: locked.version,
        ),
      );
      handled.add(name);
    }

    // Declared in pubspec.yaml but absent from the lockfile entirely
    // — typically means `pub get` hasn't been run since the
    // dependency was added. Surfacing it (with no resolved version)
    // lets the analyzer flag it rather than silently dropping it.
    for (final entry in declared.entries) {
      if (handled.contains(entry.key)) continue;
      result.add(entry.value);
    }

    return result;
  }
}
