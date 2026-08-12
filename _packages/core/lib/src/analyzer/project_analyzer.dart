import '../models/issue.dart';
import '../models/project.dart';
import 'compatibility_analyzer.dart';
import 'dependency_analyzer.dart';

/// Entry point for analyzing a [Project]: runs every available
/// analyzer and combines their findings.
///
/// Returns only [Issue]s, not a full [AnalysisResult] — the
/// `recommendations` and `fixes` layers don't exist yet (steps 10 and
/// 11), so assembling a complete `AnalysisResult` is premature at
/// this stage. The CLI/API will build the full result once those
/// layers exist.
///
/// TODO(resolver-step): once transitive requirement edges are
/// available (via a pub.dev or package-cache metadata source, see the
/// project's research step), add detection for
/// [IssueType.versionConflict] and [IssueType.incompatibleSdkConstraint]
/// here. Both need to compare constraints from more than one source
/// per package, which the Core doesn't have data for yet.
class ProjectAnalyzer {
  const ProjectAnalyzer._();

  static List<Issue> analyze(Project project) {
    return [
      ...CompatibilityAnalyzer.analyze(project.environment),
      ...DependencyAnalyzer.analyze(project.dependencies),
    ];
  }
}
