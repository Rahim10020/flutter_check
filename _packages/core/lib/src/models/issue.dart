import 'package.dart';

/// How severe an [Issue] is.
enum IssueSeverity {
  /// Prevents `pub get`/`pub upgrade` from succeeding, or otherwise
  /// breaks the project outright.
  error,

  /// Doesn't break the project today but is worth attention (e.g. an
  /// outdated constraint, a soon-to-be-unsupported SDK range).
  warning,

  /// Purely informational.
  info,
}

/// The category of problem an [Issue] represents.
enum IssueType {
  /// Two or more constraints on the same package cannot all be
  /// satisfied by any single version.
  versionConflict,

  /// The declared Dart or Flutter SDK constraint isn't satisfied by
  /// the SDK actually installed.
  sdkMismatch,

  /// A dependency's own SDK constraint is incompatible with the
  /// project's SDK environment.
  incompatibleSdkConstraint,

  /// A package referenced in the project couldn't be found (typo,
  /// unpublished, removed from pub.dev).
  missingPackage,

  /// The lockfile's resolved version no longer satisfies the
  /// constraint declared in pubspec.yaml.
  outOfSyncLockfile,
}

/// A single problem detected while analyzing a project.
class Issue {
  final IssueType type;
  final IssueSeverity severity;

  /// Human-readable explanation, written to be read directly by a
  /// developer — FlutterCheck's job is to explain, not just flag.
  final String description;

  final List<Package> relatedPackages;

  const Issue({
    required this.type,
    required this.severity,
    required this.description,
    this.relatedPackages = const [],
  });

  @override
  String toString() => '[${severity.name}] ${type.name}: $description';
}
