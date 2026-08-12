import 'issue.dart';
import 'package.dart';
import 'version.dart';

/// How confident FlutterCheck is in a [Recommendation]. Reflects the
/// project's rule that recommendations must be grounded in real data
/// — "I can't determine a reliable solution" is preferable to a
/// confident wrong answer.
enum RecommendationConfidence {
  /// Backed directly by verifiable data (e.g. a version that
  /// definitively satisfies all known constraints).
  high,

  /// Likely correct but with some uncertainty (e.g. based on partial
  /// metadata).
  medium,

  /// FlutterCheck cannot determine a reliable solution and surfaces
  /// this only as a possibility for the developer to evaluate.
  low,
}

/// A course of action FlutterCheck suggests to resolve one or more
/// [Issue]s. Describes *what* should change and *why* — see [Fix] for
/// the mechanical edit that carries it out.
class Recommendation {
  final String summary;
  final String rationale;
  final List<Issue> addresses;

  /// If this recommends a specific version for a package. Null for
  /// recommendations that aren't a simple version bump (e.g. "remove
  /// this dependency").
  final Package? package;
  final Version? suggestedVersion;

  final RecommendationConfidence confidence;

  const Recommendation({
    required this.summary,
    required this.rationale,
    required this.addresses,
    required this.confidence,
    this.package,
    this.suggestedVersion,
  });

  @override
  String toString() => summary;
}
