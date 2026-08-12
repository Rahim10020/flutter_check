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
  /// be widened).
  upgradeMajorVersionsDryRun,
}

/// Whether a dry-run solve succeeded or failed.
enum PubSolveOutcome {
  /// Pub found a set of versions satisfying every constraint.
  solved,

  /// Pub could not find any solution — a genuine version conflict.
  failed,
}

/// A single version change pub would make as part of a solve.
class PubDependencyChange {
  final Package package;

  /// Null if this is a new dependency being added rather than an
  /// existing one changing version.
  final Version? from;
  final Version to;

  const PubDependencyChange({
    required this.package,
    required this.to,
    this.from,
  });

  @override
  String toString() => from != null
      ? '${package.name}: $from → $to'
      : '${package.name}: → $to (new)';
}

/// The result of running a dry-run pub command against a project.
///
/// This is produced by a [PubRunner] implementation (outside the
/// Core) that actually invoked `dart pub` or `flutter pub` as a
/// subprocess — the Core never guesses at this outcome, it only
/// interprets a result that real pub already computed.
class PubSolveResult {
  final PubCommand command;
  final PubSolveOutcome outcome;

  /// The exact, unmodified text pub printed. When [outcome] is
  /// [PubSolveOutcome.failed], this is pub's own PubGrub-generated
  /// explanation — already written to be human-readable, and the
  /// most reliable explanation available for *why* no solution
  /// exists.
  final String rawOutput;

  /// The version changes pub would make. Empty when [outcome] is
  /// [PubSolveOutcome.failed].
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
///
/// Field names deliberately don't mirror `dart pub outdated --json`'s
/// own schema — that mapping is the responsibility of whatever
/// implements [PubRunner] outside the Core. This model only commits
/// to the concepts that schema exposes, not its exact shape, so a
/// future change to pub's JSON format doesn't ripple into the Core.
class OutdatedPackageInfo {
  final Package package;

  /// The version currently locked in pubspec.lock, if any.
  final Version? current;

  /// The highest version obtainable by `pub upgrade` without
  /// changing any declared constraint.
  final Version? upgradable;

  /// The highest version obtainable by `pub upgrade --major-versions`
  /// (may require widening a declared constraint).
  final Version? resolvable;

  /// The latest version published for this package, regardless of
  /// whether it's currently reachable under any constraint.
  final Version? latest;

  const OutdatedPackageInfo({
    required this.package,
    this.current,
    this.upgradable,
    this.resolvable,
    this.latest,
  });
}
