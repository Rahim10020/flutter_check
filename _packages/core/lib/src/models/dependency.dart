import 'constraint.dart';
import 'package.dart';
import 'version.dart';

/// How a dependency relates to the project that declares it, mirroring
/// the `dependency:` field found in `pubspec.lock`.
enum DependencyKind {
  /// Declared directly under `dependencies:` in pubspec.yaml.
  directMain,

  /// Declared directly under `dev_dependencies:` in pubspec.yaml.
  directDev,

  /// Declared directly under `dependency_overrides:` in pubspec.yaml.
  directOverridden,

  /// Pulled in indirectly, as a dependency of another package.
  transitive,
}

/// A single dependency relationship between the project and a [Package].
///
/// Depending on where this was extracted from, either [constraint]
/// (declared in `pubspec.yaml`) or [resolvedVersion] (locked in
/// `pubspec.lock`) may be null. A fully resolved project will
/// typically have both.
class Dependency {
  final Package package;

  /// The version constraint declared in `pubspec.yaml`, if known.
  final Constraint? constraint;

  /// The exact version locked in `pubspec.lock`, if known.
  final Version? resolvedVersion;

  final DependencyKind kind;

  const Dependency({
    required this.package,
    required this.kind,
    this.constraint,
    this.resolvedVersion,
  });

  bool get isDirect =>
      kind == DependencyKind.directMain ||
      kind == DependencyKind.directDev ||
      kind == DependencyKind.directOverridden;

  bool get isTransitive => kind == DependencyKind.transitive;

  /// Whether the locked [resolvedVersion] satisfies the declared
  /// [constraint]. Null if either piece of information is missing —
  /// this is how `outOfSyncLockfile` issues get detected upstream.
  bool? get isSatisfied {
    if (constraint == null || resolvedVersion == null) return null;
    return constraint!.allows(resolvedVersion!);
  }

  @override
  String toString() {
    final c = constraint != null ? ' $constraint' : '';
    final r = resolvedVersion != null ? ' → $resolvedVersion' : '';
    return '${package.name}$c$r';
  }
}
