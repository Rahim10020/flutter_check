import '../models/pub_solve_result.dart';
import '../models/project.dart';

/// Abstract access to the real `pub` tool (via `dart pub` or
/// `flutter pub`, depending on the project) — the contract the
/// `resolver` layer depends on to get an actual, trustworthy solve
/// result, without the Core running subprocesses itself.
///
/// The Core deliberately does not reimplement PubGrub: doing so would
/// risk diverging from pub's real behavior, which is precisely the
/// kind of unreliable guess this project's principles rule out.
/// Instead, the Core asks a real `pub` process for the answer and
/// interprets it. Concrete implementations (spawning a process,
/// choosing between `dart pub` and `flutter pub` based on the
/// project, parsing pub's JSON/text output into these Core models)
/// belong to the apps that use the Core — the same pattern as
/// [PackageMetadataSource].
abstract class PubRunner {
  /// Runs `pub get --dry-run` for [project]: does the current set of
  /// declared constraints have any solution at all?
  Future<PubSolveResult> getDryRun(Project project);

  /// Runs `pub upgrade --dry-run` for [project]: is there a solution
  /// that upgrades within the currently declared constraints?
  Future<PubSolveResult> upgradeDryRun(Project project);

  /// Runs `pub upgrade --major-versions --dry-run` for [project]: is
  /// there a solution if declared constraints are allowed to widen?
  Future<PubSolveResult> upgradeMajorVersionsDryRun(Project project);

  /// Runs `pub outdated` for [project] and returns structured
  /// per-package results.
  Future<List<OutdatedPackageInfo>> outdated(Project project);
}

/// Thrown by a [PubRunner] implementation when the underlying `pub`
/// process could not be run at all (not installed, not found on
/// PATH, process launch failure) — distinct from a normal
/// [PubSolveOutcome.failed], which means pub ran successfully but
/// found no solution.
class PubRunnerException implements Exception {
  final String message;
  const PubRunnerException(this.message);

  @override
  String toString() => 'PubRunnerException: $message';
}
