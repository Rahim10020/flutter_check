import 'package:pub_semver/pub_semver.dart' as semver;

/// Represents a single package or SDK version, following Semantic
/// Versioning as interpreted by Pub.
///
/// This is a thin wrapper around `pub_semver`'s `Version` class so the
/// rest of the Core depends only on this model, never directly on
/// `pub_semver`'s API. If the underlying implementation ever needs to
/// change, only this file is affected.
class Version {
  final semver.Version _value;

  Version._(this._value);

  /// Parses a version string such as "3.19.2" or "1.0.0-beta.1".
  ///
  /// Throws a [FormatException] if [input] is not a valid version.
  factory Version.parse(String input) => Version._(semver.Version.parse(input));

  /// Attempts to parse [input], returning null instead of throwing.
  static Version? tryParse(String input) {
    try {
      return Version.parse(input);
    } on FormatException {
      return null;
    }
  }

  int get major => _value.major;
  int get minor => _value.minor;
  int get patch => _value.patch;

  /// True for versions like "1.0.0-beta.1".
  bool get isPreRelease => _value.isPreRelease;

  /// The underlying pub_semver value. Exposed (not hidden) so the
  /// `constraints`/`resolver` layers can interoperate with pub_semver's
  /// own constraint-evaluation logic without this model reimplementing it.
  semver.Version get raw => _value;

  int compareTo(Version other) => _value.compareTo(other._value);

  bool operator <(Version other) => _value < other._value;
  bool operator <=(Version other) => _value <= other._value;
  bool operator >(Version other) => _value > other._value;
  bool operator >=(Version other) => _value >= other._value;

  @override
  bool operator ==(Object other) => other is Version && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => _value.toString();
}