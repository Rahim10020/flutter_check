import '../models/pub_solve_result.dart';
import '../models/project.dart';

/// Determines which real `pub` command corresponds to a given dry-run
/// [PubCommand] — the single source of truth for this mapping, so no
/// other part of the codebase needs to know or re-derive it.
///
/// [PubCommand.upgradeMajorVersionsDryRun] is deliberately excluded:
/// it represents a more aggressive update intent than `get`/`upgrade`,
/// and is out of scope until the Resolver's core get/upgrade behavior
/// is stable. Callers must not guess a behavior for it.
class RealPubCommand {
  final List<String> pubArgs;
  const RealPubCommand._(this.pubArgs);

  static const get = RealPubCommand._(['get']);
  static const upgrade = RealPubCommand._(['upgrade']);

  /// Maps a dry-run [PubCommand] to the real command that proved (via
  /// a prior dry-run) it can succeed. Throws [UnsupportedError] for
  /// [PubCommand.upgradeMajorVersionsDryRun] — not supported as of V1.
  static RealPubCommand forDryRun(PubCommand command) {
    switch (command) {
      case PubCommand.getDryRun:
        return get;
      case PubCommand.upgradeDryRun:
        return upgrade;
      case PubCommand.upgradeMajorVersionsDryRun:
        throw UnsupportedError(
          'LockfileSandbox does not support PubCommand.upgradeMajorVersionsDryRun '
          'in V1 — this is a deliberately deferred scope decision, not a bug.',
        );
    }
  }
}

/// Replays, for real, the pub command whose dry-run counterpart has
/// already been shown (by [PubRunner]) to succeed — inside a
/// temporary, disposable copy of the project (via [ProjectWorkspace])
/// — and reports the structured lockfile changes that resulted.
///
/// This exists because dry-run output cannot be reliably parsed for
/// per-package changes (see [PubSolveResult.changes] docs), while
/// `pubspec.lock` is a stable, documented, already-parseable format.
/// Diffing two real lockfiles gives real data, without reimplementing
/// any part of pub's own resolution — the resolution itself is still
/// done entirely by a real `pub` process.
///
/// [LockfileSandbox] never chooses which command to run based on its
/// own judgment — it only ever replays the exact command the caller
/// specifies, which must be one already proven to succeed by a
/// dry-run. See [RealPubCommand.forDryRun].
abstract class LockfileSandbox {
  /// Resolves [project] for real, using the real command corresponding
  /// to [command] (see [RealPubCommand.forDryRun]), and returns the
  /// structured differences between the project's current
  /// `pubspec.lock` and the one produced by that resolution.
  ///
  /// Throws [UnsupportedError] if [command] is
  /// [PubCommand.upgradeMajorVersionsDryRun].
  Future<List<PubDependencyChange>> resolveChanges(
    Project project,
    PubCommand command,
  );
}
