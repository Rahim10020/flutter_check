import '../models/version.dart';

/// Comparator for sorting [Version]s in ascending order. Usable
/// directly as `list.sort(compareVersions)`.
int compareVersions(Version a, Version b) => a.compareTo(b);

/// Utility functions for working with collections of [Version]s.
///
/// This layer only reasons about versions in isolation — it knows
/// nothing about constraints, and nothing about which versions
/// actually exist on pub.dev for a given package. Callers supply the
/// versions to consider (e.g. extracted from `pubspec.lock`, or later
/// from a pub.dev metadata source once that layer is designed).
class Versions {
  const Versions._();

  /// Returns a new list of [versions], sorted ascending.
  static List<Version> sorted(Iterable<Version> versions) {
    final result = versions.toList()..sort(compareVersions);
    return result;
  }

  /// The highest version in [versions], or null if empty.
  static Version? latest(Iterable<Version> versions) {
    if (versions.isEmpty) return null;
    return sorted(versions).last;
  }

  /// The highest non-pre-release version in [versions], or null if
  /// none exist. Pre-release versions (e.g. "2.0.0-beta.1") are
  /// excluded because pub only selects them when a constraint
  /// explicitly allows it.
  static Version? latestStable(Iterable<Version> versions) =>
      latest(stable(versions));

  /// Only the stable (non-pre-release) versions from [versions].
  static Iterable<Version> stable(Iterable<Version> versions) =>
      versions.where((v) => !v.isPreRelease);

  /// Only the pre-release versions from [versions].
  static Iterable<Version> preRelease(Iterable<Version> versions) =>
      versions.where((v) => v.isPreRelease);
}
