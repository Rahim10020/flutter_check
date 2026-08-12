import 'package:pub_semver/pub_semver.dart' as semver;

import 'version.dart';

/// Represents a version constraint as found in a `pubspec.yaml`, e.g.
/// `^1.2.3`, `>=1.0.0 <2.0.0`, `any`, or a compound constraint such as
/// `>=2.0.0 <3.0.0 || >=4.0.0 <5.0.0`.
///
/// Backed by `pub_semver`'s `VersionConstraint`, which implements the
/// exact same constraint semantics `pub` itself uses when resolving
/// dependencies — this is what keeps our interpretation of constraints
/// faithful to the real tool (see the project's reliability principle).
class Constraint {
  final semver.VersionConstraint _value;

  Constraint._(this._value);

  /// Parses a constraint string such as "^1.2.3" or ">=1.0.0 <2.0.0".
  ///
  /// Throws a [FormatException] if [input] is not a valid constraint.
  factory Constraint.parse(String input) =>
      Constraint._(semver.VersionConstraint.parse(input));

  /// Attempts to parse [input], returning null instead of throwing.
  static Constraint? tryParse(String input) {
    try {
      return Constraint.parse(input);
    } on FormatException {
      return null;
    }
  }

  /// A constraint that allows any version.
  factory Constraint.any() => Constraint._(semver.VersionConstraint.any);

  /// A constraint that can never be satisfied — typically the result of
  /// intersecting two incompatible constraints during resolution.
  factory Constraint.empty() => Constraint._(semver.VersionConstraint.empty);

  /// Whether [version] satisfies this constraint.
  bool allows(Version version) => _value.allows(version.raw);

  /// Whether this constraint can never be satisfied by any version.
  bool get isEmpty => _value.isEmpty;

  /// Whether this constraint allows every version.
  bool get isAny => _value == semver.VersionConstraint.any;

  /// The underlying pub_semver value, exposed for the `resolver` layer,
  /// which will need to intersect and union constraints.
  semver.VersionConstraint get raw => _value;

  @override
  bool operator ==(Object other) =>
      other is Constraint && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => _value.toString();
}
