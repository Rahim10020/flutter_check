import '../models/issue.dart';
import '../models/package.dart';
import '../models/project.dart';
import '../models/recommendation.dart';

/// Turns [Issue]s into actionable [Recommendation]s, for issue types
/// that can be recommended deterministically from data already known
/// (declared constraints, environment) — no `pub` process, no network
/// call needed.
///
/// [IssueType.versionConflict] is deliberately *not* handled here:
/// those recommendations come from [DependencyResolver] (see the
/// `resolver` layer), which grounds them in a real `pub` solve rather
/// than a static rule. Producing a competing, rule-based guess for
/// the same issue type here would undermine that grounding.
/// [IssueType.incompatibleSdkConstraint] isn't handled yet either —
/// detecting it at all still depends on transitive package metadata
/// not yet wired into the analyzer (see the `analyzer` step's TODO).
class IssueRecommender {
  const IssueRecommender._();

  static List<Recommendation> recommend(Project project, List<Issue> issues) {
    final recommendations = <Recommendation>[];

    for (final issue in issues) {
      switch (issue.type) {
        case IssueType.outOfSyncLockfile:
          recommendations.add(_lockfileOutOfSync(issue));
          break;
        case IssueType.missingPackage:
          recommendations.add(_missingPackage(issue));
          break;
        case IssueType.sdkMismatch:
          recommendations.addAll(_sdkMismatch(project, issue));
          break;
        case IssueType.versionConflict:
        case IssueType.incompatibleSdkConstraint:
          break;
      }
    }

    return recommendations;
  }

  static Recommendation _lockfileOutOfSync(Issue issue) => Recommendation(
    summary: 'Run `pub get` to re-resolve dependencies.',
    rationale: issue.description,
    addresses: [issue],
    confidence: RecommendationConfidence.high,
  );

  static Recommendation _missingPackage(Issue issue) => Recommendation(
    summary: 'Run `pub get`, or verify the package name is correct.',
    rationale: issue.description,
    addresses: [issue],
    package: issue.relatedPackages.isNotEmpty
        ? issue.relatedPackages.first
        : null,
    // Medium, not high: the analyzer itself already flags this as
    // ambiguous between "pub get not run yet" and "typo/removed
    // package" — see DependencyAnalyzer's own description text.
    confidence: RecommendationConfidence.medium,
  );

  static List<Recommendation> _sdkMismatch(Project project, Issue issue) {
    final env = project.environment;
    final recommendations = <Recommendation>[];

    if (env.dartSdkSatisfied == false) {
      recommendations.add(
        Recommendation(
          summary:
              'Install a Dart SDK version satisfying ${env.dartSdkConstraint}.',
          rationale: issue.description,
          addresses: [issue],
          package: const Package.sdkPackage('dart'),
          confidence: RecommendationConfidence.high,
        ),
      );
    }

    if (env.flutterSdkSatisfied == false) {
      recommendations.add(
        Recommendation(
          summary:
              'Install a Flutter SDK version satisfying ${env.flutterSdkConstraint}.',
          rationale: issue.description,
          addresses: [issue],
          package: const Package.sdkPackage('flutter'),
          confidence: RecommendationConfidence.high,
        ),
      );
    }

    return recommendations;
  }
}
