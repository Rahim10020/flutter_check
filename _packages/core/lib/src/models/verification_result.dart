import 'fix.dart';
import 'pub_solve_result.dart';

/// The result of re-running a real `pub` solve after applying one or
/// more [Fix]es, to confirm whether they actually resolved the
/// project's dependency problems.
///
/// This checks overall solve success, not issue-by-issue: pub itself
/// doesn't report "issue X is now fixed, issue Y isn't" — only
/// "a solution exists" or not, plus an explanation when it doesn't.
/// Claiming more granular certainty than that would be an unfounded
/// guess.
class VerificationResult {
  final List<Fix> appliedFixes;

  /// The dry-run solve result obtained after the fixes were applied.
  final PubSolveResult afterResult;

  const VerificationResult({
    required this.appliedFixes,
    required this.afterResult,
  });

  /// Whether the project resolves cleanly after the fixes were applied.
  bool get resolved => afterResult.succeeded;
}
