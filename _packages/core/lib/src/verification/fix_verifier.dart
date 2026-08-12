import '../models/fix.dart';
import '../models/project.dart';
import '../models/verification_result.dart';
import '../resolver/pub_runner.dart';

/// Verifies that a set of applied [Fix]es actually resolves a
/// project's dependencies, by asking a real `pub` process (via
/// [PubRunner]) the same question the [DependencyResolver] asked
/// before the fixes existed.
///
/// [projectAfterFix] must reflect the project's state *after* the
/// fixes were written to disk — building that updated [Project] (by
/// re-parsing the edited pubspec.yaml, e.g. via
/// [PubspecEditor.apply] followed by [PubspecParser]/[ProjectBuilder])
/// and actually writing it to the path `pubRunner` will read from are
/// both the caller's responsibility (CLI/API); the Core has no
/// filesystem access.
class FixVerifier {
  final PubRunner pubRunner;

  const FixVerifier({required this.pubRunner});

  Future<VerificationResult> verify({
    required Project projectAfterFix,
    required List<Fix> appliedFixes,
  }) async {
    final result = await pubRunner.getDryRun(projectAfterFix);
    return VerificationResult(appliedFixes: appliedFixes, afterResult: result);
  }
}
