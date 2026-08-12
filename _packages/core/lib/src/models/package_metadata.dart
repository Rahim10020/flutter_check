import 'version.dart';
import '../parsers/pubspec_parser.dart';

/// A single published version of a package, as reported by a package
/// repository (pub.dev or a compatible mirror): its own declared
/// dependencies and SDK constraints, exactly as that version's own
/// pubspec.yaml states them.
///
/// This is what makes it possible to build real transitive edges in
/// the dependency graph — [pubspec.dependencies] tells us what *this*
/// version requires from other packages.
class PackageVersionMetadata {
  final Version version;

  /// True if this version was retracted by its publisher (pub will
  /// never select a retracted version unless it's already locked).
  final bool isRetracted;

  /// This version's own declared dependencies and SDK environment.
  final PubspecData pubspec;

  const PackageVersionMetadata({
    required this.version,
    required this.pubspec,
    this.isRetracted = false,
  });
}

/// All published version metadata for a single package, as needed by
/// the `graph` and `resolver` layers to reason about transitive
/// dependencies and candidate versions.
class PackageMetadata {
  final String name;

  /// The version pub.dev currently reports as "latest" for this
  /// package (typically its highest stable version).
  final Version? latestVersion;

  final List<PackageVersionMetadata> versions;

  const PackageMetadata({
    required this.name,
    required this.versions,
    this.latestVersion,
  });

  /// Versions ordered ascending, excluding retracted ones — the set a
  /// resolver should normally consider.
  List<PackageVersionMetadata> get selectable =>
      versions.where((v) => !v.isRetracted).toList()
        ..sort((a, b) => a.version.compareTo(b.version));
}
