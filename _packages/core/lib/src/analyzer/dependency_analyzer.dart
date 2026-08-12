import '../models/dependency.dart';
import '../models/issue.dart';

/// Detects issues in a project's individual dependencies: constraints
/// no longer satisfied by the locked version, and dependencies that
/// couldn't be resolved at all.
class DependencyAnalyzer {
  const DependencyAnalyzer._();

  static List<Issue> analyze(Iterable<Dependency> dependencies) {
    final deps = dependencies.toList();
    final issues = <Issue>[];

    // If not a single dependency has a resolved version, `pubspec.lock`
    // was most likely never read (missing, or `pub get` never run) —
    // that's one project-wide fact, not N individual missing-package
    // issues. Flagging every dependency in that case would be noise,
    // not signal.
    final noLockDataAtAll =
        deps.isNotEmpty && deps.every((d) => d.resolvedVersion == null);

    for (final dep in deps) {
      if (dep.isSatisfied == false) {
        issues.add(
          Issue(
            type: IssueType.outOfSyncLockfile,
            severity: IssueSeverity.error,
            description:
                'pubspec.lock has ${dep.package.name} at ${dep.resolvedVersion}, which no '
                'longer satisfies the constraint ${dep.constraint} declared in pubspec.yaml. '
                'Run `pub get` (or `pub upgrade` if that fails) to re-resolve.',
            relatedPackages: [dep.package],
          ),
        );
        continue;
      }

      if (!noLockDataAtAll && dep.isDirect && dep.resolvedVersion == null) {
        issues.add(
          Issue(
            type: IssueType.missingPackage,
            severity: IssueSeverity.warning,
            description:
                '${dep.package.name} is declared in pubspec.yaml but has no resolved '
                'version in pubspec.lock. This usually means `pub get` hasn\'t been run '
                'since it was added — but it can also mean the package name is misspelled '
                'or no longer available.',
            relatedPackages: [dep.package],
          ),
        );
      }
    }

    return issues;
  }
}
