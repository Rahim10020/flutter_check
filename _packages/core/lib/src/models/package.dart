/// Where a package comes from.
enum PackageSource {
  /// Published on pub.dev (or another pub-compatible hosted repository).
  hosted,

  /// Referenced directly from a Git repository.
  git,

  /// Referenced from a local path on disk.
  path,

  /// Provided by an SDK (e.g. "flutter", "flutter_test") rather than pub.
  sdk,

  /// A synthetic source representing the project itself, used as the
  /// origin of dependency-graph edges for directly declared
  /// dependencies. Never represents a real, resolvable package.
  project,
}

/// Identifies a single Dart/Flutter package, independent of any
/// specific version or constraint.
class Package {
  /// The package name as declared in `pubspec.yaml` (e.g. "http",
  /// "flutter", "provider").
  final String name;

  /// Where this package is sourced from.
  final PackageSource source;

  /// For [PackageSource.git]: the repository URL. Null otherwise.
  final String? gitUrl;

  /// For [PackageSource.path]: the local path. Null otherwise.
  final String? path;

  /// For [PackageSource.sdk]: the SDK name (e.g. "flutter"). Null otherwise.
  final String? sdk;

  const Package({
    required this.name,
    required this.source,
    this.gitUrl,
    this.path,
    this.sdk,
  });

  /// Convenience constructor for a package hosted on pub.dev.
  const Package.hosted(String name)
    : this(name: name, source: PackageSource.hosted);

  /// Convenience constructor for an SDK-provided package such as "flutter".
  const Package.sdkPackage(String name)
    : this(name: name, source: PackageSource.sdk, sdk: name);

  /// A synthetic node representing the project itself, used as the
  /// `from` endpoint of edges to directly declared dependencies.
  const Package.project(String name)
    : this(name: name, source: PackageSource.project);

  @override
  bool operator ==(Object other) =>
      other is Package && name == other.name && source == other.source;

  @override
  int get hashCode => Object.hash(name, source);

  @override
  String toString() => '$name (${source.name})';
}
