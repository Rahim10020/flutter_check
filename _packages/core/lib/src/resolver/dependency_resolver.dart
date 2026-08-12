import '../models/issue.dart';
import '../models/pub_solve_result.dart';
import '../models/project.dart';
import '../models/recommendation.dart';
import 'pub_runner.dart';

/// The outcome of resolving a project's dependencies: whether a
/// solution exists today, and — if not — the [Issue] explaining why,
/// plus whatever [Recommendation]s can be made from it.
class ResolutionOutcome {
  final PubSolveResult getResult;

  /// Present only if a dry-run upgrade was also attempted (see
  /// [DependencyResolver.resolve]'s `attemptUpgrade` parameter).
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
/// source of truth, and turns the result into this project's own
/// [Issue]/[Recommendation] vocabulary.
///
/// This does not reimplement version solving — see [PubRunner]'s
/// documentation for why.
class DependencyResolver {
  final PubRunner pubRunner;

  const DependencyResolver({required this.pubRunner});

  /// Resolves [project]. If [attemptUpgrade] is true and the current
  /// constraints have no solution, also asks whether upgrading within
  /// those constraints would fix it — this is what turns a bare
  /// "conflict detected" into an actionable recommendation.
  Future<ResolutionOutcome> resolve(
    Project project, {
    bool attemptUpgrade = true,
  }) async {
    final getResult = await pubRunner.getDryRun(project);

    if (getResult.succeeded) {
      return ResolutionOutcome(
        getResult: getResult,
        issues: const [],
        recommendations: _recommendationsForChanges(
          getResult,
          summary: 'Dependencies resolve as declared.',
        ),
      );
    }

    // No solution under current constraints — this is a genuine
    // version conflict. Pub's own explanation is the most reliable
    // one available (see PubSolveResult.rawOutput docs), so it
    // becomes the Issue description directly rather than us
    // attempting to re-derive or rephrase the reasoning.
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

    final recommendations = upgradeResult.succeeded
        ? _recommendationsForChanges(
            upgradeResult,
            summary:
                'Running an upgrade within existing constraints '
                'resolves the conflict.',
            addresses: [conflictIssue],
          )
        : <Recommendation>[
            Recommendation(
              summary:
                  'No solution found even when upgrading within '
                  'declared constraints.',
              rationale: upgradeResult.rawOutput.trim(),
              addresses: [conflictIssue],
              confidence: RecommendationConfidence.low,
            ),
          ];

    return ResolutionOutcome(
      getResult: getResult,
      upgradeResult: upgradeResult,
      issues: [conflictIssue],
      recommendations: recommendations,
    );
  }

  static List<Recommendation> _recommendationsForChanges(
    PubSolveResult result, {
    required String summary,
    List<Issue> addresses = const [],
  }) {
    if (result.changes.isEmpty) return const [];

    return [
      for (final change in result.changes)
        Recommendation(
          summary: summary,
          rationale:
              'pub resolved ${change.package.name} to '
              '${change.to}${change.from != null ? ' (from ${change.from})' : ''}.',
          addresses: addresses,
          package: change.package,
          suggestedVersion: change.to,
          // High confidence: this is pub's own real solve, not a guess.
          confidence: RecommendationConfidence.high,
        ),
    ];
  }
}
