import 'constraint.dart';
import 'version.dart';

/// The SDK environment of a Flutter/Dart project: what versions the
/// project declares it supports, and — when available — what versions
/// are actually installed on the machine running the analysis.
class Environment {
  /// The Dart SDK constraint declared under `environment: sdk:` in
  /// `pubspec.yaml`.
  final Constraint? dartSdkConstraint;

  /// The Flutter SDK constraint declared under `environment: flutter:`,
  /// if present — not every package declares one.
  final Constraint? flutterSdkConstraint;

  /// The Dart SDK version actually installed and used to run the
  /// analysis, if known.
  final Version? installedDartVersion;

  /// The Flutter SDK version actually installed, if known.
  final Version? installedFlutterVersion;

  const Environment({
    this.dartSdkConstraint,
    this.flutterSdkConstraint,
    this.installedDartVersion,
    this.installedFlutterVersion,
  });

  /// Null if either piece of information is missing.
  bool? get dartSdkSatisfied {
    if (dartSdkConstraint == null || installedDartVersion == null) return null;
    return dartSdkConstraint!.allows(installedDartVersion!);
  }

  /// Null if either piece of information is missing.
  bool? get flutterSdkSatisfied {
    if (flutterSdkConstraint == null || installedFlutterVersion == null) {
      return null;
    }
    return flutterSdkConstraint!.allows(installedFlutterVersion!);
  }

  @override
  String toString() =>
      'Environment(dart: $dartSdkConstraint, flutter: $flutterSdkConstraint)';
}
