import '../models/issue.dart';
import '../models/pub_solve_result.dart';
import '../models/project.dart';
import '../models/recommendation.dart';
import 'lockfile_sandbox.dart';
import 'pub_runner.dart';

class ResolutionOutcome {
  final PubSolveResult getResult;
  final PubSolveResult? upgradeResult;
  final List<Issue> issues;
  final List<Recommendation> recommendations;

  const ResolutionOutcome({
    required this.getResult,
    required this.issues,
    required this.recommendations,
    this.upgradeResult,
  });

  bool get hasSolutionToday => getResult.succeeded;
}

/// Determines whether a project's dependencies can actually be
/// resolved, using a real `pub` process (via [PubRunner]) as the
/// source of truth. When a dry-run confirms a fix exists but the
/// exact version changes are needed to produce actionable
/// [Recommendation]s, uses [LockfileSandbox] to obtain them from a
/// real (sandboxed) resolution — see that contract's documentation
/// for why.
class DependencyResolver {
  final PubRunner pubRunner;
  final LockfileSandbox lockfileSandbox;

  const DependencyResolver({
    required this.pubRunner,
    required this.lockfileSandbox,
  });

  Future<ResolutionOutcome> resolve(
    Project project, {
    bool attemptUpgrade = true,
  }) async {
    final getResult = await pubRunner.getDryRun(project);

    if (getResult.succeeded) {
      // Nothing to fix, nothing to recommend — the sandbox is never
      // needed here. See DependencyResolver's design discussion for
      // why this case is intentionally left as purely informational.
      return ResolutionOutcome(
        getResult: getResult,
        issues: const [],
        recommendations: const [
          Recommendation(
            summary: 'Dependencies resolve as declared.',
            rationale: 'pub get --dry-run succeeded with no changes needed.',
            addresses: [],
            confidence: RecommendationConfidence.high,
          ),
        ],
      );
    }

    final conflictIssue = Issue(
      type: IssueType.versionConflict,
      severity: IssueSeverity.error,
      description: getResult.rawOutput.trim(),
    );

    if (!attemptUpgrade) {
      return ResolutionOutcome(
        getResult: getResult,
        issues: [conflictIssue],
        recommendations: const [],
      );
    }

    final upgradeResult = await pubRunner.upgradeDryRun(project);

    if (!upgradeResult.succeeded) {
      return ResolutionOutcome(
        getResult: getResult,
        upgradeResult: upgradeResult,
        issues: [conflictIssue],
        recommendations: [
          Recommendation(
            summary:
                'No solution found even when upgrading within '
                'declared constraints.',
            rationale: upgradeResult.rawOutput.trim(),
            addresses: [conflictIssue],
            confidence: RecommendationConfidence.low,
          ),
        ],
      );
    }

    // upgradeDryRun proved a fix exists — get the real, structured
    // changes for it via the sandbox, so recommendations can name
    // exact package/version pairs instead of only saying "upgrade".
    final changes = await lockfileSandbox.resolveChanges(
      project,
      PubCommand.upgradeDryRun,
    );

    return ResolutionOutcome(
      getResult: getResult,
      upgradeResult: upgradeResult,
      issues: [conflictIssue],
      recommendations: _recommendationsForChanges(
        changes,
        summary:
            'Running an upgrade within existing constraints '
            'resolves the conflict.',
        addresses: [conflictIssue],
      ),
    );
  }

  static List<Recommendation> _recommendationsForChanges(
    List<PubDependencyChange> changes, {
    required String summary,
    List<Issue> addresses = const [],
  }) {
    final recommendations = <Recommendation>[];

    for (final change in changes) {
      switch (change.kind) {
        case ChangeKind.added:
        case ChangeKind.changed:
          // to is guaranteed non-null for both kinds by
          // PubDependencyChange's invariants.
          recommendations.add(
            Recommendation(
              summary: summary,
              rationale: change.kind == ChangeKind.added
                  ? 'pub would add ${change.package.name} at ${change.to}.'
                  : 'pub resolved ${change.package.name} to ${change.to} '
                        '(from ${change.from}).',
              addresses: addresses,
              package: change.package,
              suggestedVersion: change.to,
              confidence: RecommendationConfidence.high,
            ),
          );
          break;
        case ChangeKind.removed:
          // No suggestedVersion for a removal — FixGenerator already
          // skips recommendations without one, correctly: removing a
          // dependency isn't a version change to apply.
          recommendations.add(
            Recommendation(
              summary: summary,
              rationale:
                  'pub would remove ${change.package.name} '
                  '(was ${change.from}) — no longer needed by the resolved graph.',
              addresses: addresses,
              package: change.package,
              confidence: RecommendationConfidence.high,
            ),
          );
          break;
      }
    }

    return recommendations;
  }
}
