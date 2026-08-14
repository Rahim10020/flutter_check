import 'package.dart';
import 'version.dart';

/// Which pub command produced a [PubSolveResult].
enum PubCommand {
  /// `dart/flutter pub get --dry-run` — resolves within existing
  /// constraints, without upgrading anything.
  getDryRun,

  /// `dart/flutter pub upgrade --dry-run` — resolves allowing upgrades
  /// within declared constraints.
  upgradeDryRun,

  /// `dart/flutter pub upgrade --major-versions --dry-run` — resolves
  /// allowing upgrades beyond declared constraints (constraints would
  /// be widened). Not supported by [LockfileSandbox] as of V1 — see
  /// that contract's documentation.
  upgradeMajorVersionsDryRun,
}

/// Whether a dry-run solve succeeded or failed.
enum PubSolveOutcome { solved, failed }

/// What kind of change a [PubDependencyChange] represents.
enum ChangeKind {
  /// The package is newly present in the lockfile (was absent before).
  added,

  /// The package is no longer present in the lockfile.
  removed,

  /// The package's locked version changed.
  changed,
}

/// A single, structured change between two lockfile states for one
/// package.
///
/// Invariants, enforced by the named constructors — never construct
/// this any other way:
/// - [ChangeKind.added]: [from] is null, [to] is non-null.
/// - [ChangeKind.removed]: [from] is non-null, [to] is null.
/// - [ChangeKind.changed]: both [from] and [to] are non-null.
class PubDependencyChange {
  final Package package;
  final ChangeKind kind;
  final Version? from;
  final Version? to;

  const PubDependencyChange._({
    required this.package,
    required this.kind,
    required this.from,
    required this.to,
  });

  factory PubDependencyChange.added({
    required Package package,
    required Version to,
  }) => PubDependencyChange._(
    package: package,
    kind: ChangeKind.added,
    from: null,
    to: to,
  );

  factory PubDependencyChange.removed({
    required Package package,
    required Version from,
  }) => PubDependencyChange._(
    package: package,
    kind: ChangeKind.removed,
    from: from,
    to: null,
  );

  factory PubDependencyChange.changed({
    required Package package,
    required Version from,
    required Version to,
  }) => PubDependencyChange._(
    package: package,
    kind: ChangeKind.changed,
    from: from,
    to: to,
  );

  @override
  String toString() {
    switch (kind) {
      case ChangeKind.added:
        return '${package.name}: → $to (added)';
      case ChangeKind.removed:
        return '${package.name}: $from → (removed)';
      case ChangeKind.changed:
        return '${package.name}: $from → $to';
    }
  }
}

/// The result of running a dry-run pub command against a project.
class PubSolveResult {
  final PubCommand command;
  final PubSolveOutcome outcome;
  final String rawOutput;

  /// Always empty as produced by [PubRunner] implementations directly
  /// (dry-run output isn't reliably parseable — see [PubProcessRunner]'s
  /// documentation). Populated only via [LockfileSandbox], which is a
  /// separate, explicit step — see [DependencyResolver].
  final List<PubDependencyChange> changes;

  const PubSolveResult({
    required this.command,
    required this.outcome,
    required this.rawOutput,
    this.changes = const [],
  });

  bool get succeeded => outcome == PubSolveOutcome.solved;
}

/// A single package's outdated-ness, as reported by `pub outdated`.
class OutdatedPackageInfo {
  final Package package;
  final Version? current;
  final Version? upgradable;
  final Version? resolvable;
  final Version? latest;

  const OutdatedPackageInfo({
    required this.package,
    this.current,
    this.upgradable,
    this.resolvable,
    this.latest,
  });
}
