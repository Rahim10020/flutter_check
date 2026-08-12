import '../models/environment.dart';
import '../models/issue.dart';

/// Detects issues in a project's declared SDK environment versus the
/// SDK(s) actually installed.
///
/// Does not (yet) check a dependency's own SDK constraints against
/// the project's environment ([IssueType.incompatibleSdkConstraint])
/// — that requires reading each dependency's own pubspec.yaml, which
/// needs a metadata source (pub.dev or the local package cache) not
/// yet built. See the project's research step before the resolver.
class CompatibilityAnalyzer {
  const CompatibilityAnalyzer._();

  static List<Issue> analyze(Environment environment) {
    final issues = <Issue>[];

    if (environment.dartSdkSatisfied == false) {
      issues.add(
        Issue(
          type: IssueType.sdkMismatch,
          severity: IssueSeverity.error,
          description:
              'The installed Dart SDK (${environment.installedDartVersion}) does not '
              'satisfy the constraint declared in pubspec.yaml (${environment.dartSdkConstraint}).',
        ),
      );
    }

    if (environment.flutterSdkSatisfied == false) {
      issues.add(
        Issue(
          type: IssueType.sdkMismatch,
          severity: IssueSeverity.error,
          description:
              'The installed Flutter SDK (${environment.installedFlutterVersion}) does not '
              'satisfy the constraint declared in pubspec.yaml (${environment.flutterSdkConstraint}).',
        ),
      );
    }

    return issues;
  }
}
