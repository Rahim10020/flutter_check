import '../models/fix.dart';
import '../models/recommendation.dart';

/// Turns [Recommendation]s into concrete, mechanical [Fix]es.
///
/// Only recommendations that name both a [Recommendation.package] and
/// a [Recommendation.suggestedVersion] can become a [Fix] — anything
/// else (e.g. "install a matching Dart SDK", which isn't a pubspec
/// edit at all) stays informational and is simply skipped here.
class FixGenerator {
  const FixGenerator._();

  static List<Fix> generate(Iterable<Recommendation> recommendations) {
    final fixes = <Fix>[];

    for (final r in recommendations) {
      final package = r.package;
      final version = r.suggestedVersion;
      if (package == null || version == null) continue;

      fixes.add(
        Fix(
          action: FixAction.updateConstraint,
          package: package,
          // A caret constraint anchored to the resolved version, matching
          // the convention `pub upgrade --tighten` itself uses — it keeps
          // the dependency's normal upgrade range open above this version
          // rather than pinning it exactly.
          newConstraint: '^$version',
          recommendation: r,
        ),
      );
    }

    return fixes;
  }
}
