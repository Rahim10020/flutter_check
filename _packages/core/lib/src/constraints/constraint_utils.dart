import 'package:pub_semver/pub_semver.dart' as semver;

import '../models/constraint.dart';
import '../models/version.dart';

/// Utility functions for combining and evaluating [Constraint]s.
///
/// This layer answers questions like "can these constraints all be
/// satisfied at once?" — it does not know *which* versions actually
/// exist for a package (that's `versions/`), nor how to pick a winner
/// among several valid versions (that's `resolver/`, still pending
/// the Pub research step).
class Constraints {
  const Constraints._();

  /// The constraint that allows only versions allowed by *all* of
  /// [constraints]. Returns [Constraint.empty] if [constraints] is
  /// empty or if the intersection allows no version at all — this is
  /// exactly how a version conflict is detected: intersect every
  /// constraint declared on a package, and check [Constraint.isEmpty].
  static Constraint intersectAll(Iterable<Constraint> constraints) {
    if (constraints.isEmpty) return Constraint.any();
    semver.VersionConstraint result = semver.VersionConstraint.any;
    for (final c in constraints) {
      result = result.intersect(c.raw);
    }
    return Constraint.fromRaw(result);
  }

  /// The constraint that allows versions allowed by *any* of
  /// [constraints]. Rarely needed for conflict detection, but useful
  /// when the resolver later needs to know the full range a package
  /// could occupy across alternative dependency paths.
  static Constraint unionAll(Iterable<Constraint> constraints) {
    if (constraints.isEmpty) return Constraint.empty();
    semver.VersionConstraint result = semver.VersionConstraint.empty;
    for (final c in constraints) {
      result = result.union(c.raw);
    }
    return Constraint.fromRaw(result);
  }

  /// Whether every constraint in [constraints] can be satisfied by at
  /// least one common version. This is the core check behind
  /// [IssueType.versionConflict]: if false, no single version of the
  /// package can satisfy all the requirements placed on it.
  static bool areCompatible(Iterable<Constraint> constraints) =>
      !intersectAll(constraints).isEmpty;

  /// Filters [versions] down to those allowed by every constraint in
  /// [constraints]. Useful once a candidate list of published
  /// versions is available (from the future pub.dev metadata layer)
  /// to see which of them would actually satisfy all requirements.
  static List<Version> allowedVersions(
    Iterable<Constraint> constraints,
    Iterable<Version> versions,
  ) {
    final combined = intersectAll(constraints);
    return versions.where(combined.allows).toList();
  }
}
