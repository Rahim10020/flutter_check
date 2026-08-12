import 'package.dart';
import 'recommendation.dart';

/// The kind of mechanical edit a [Fix] performs.
enum FixAction {
  /// Change the version constraint for a dependency in `pubspec.yaml`.
  updateConstraint,

  /// Remove a dependency entirely.
  removeDependency,

  /// Add a `dependency_overrides` entry.
  addOverride,
}

/// A concrete, mechanical edit FlutterCheck can apply to carry out a
/// [Recommendation].
///
/// Unlike [Recommendation], which explains *what* and *why* in human
/// terms, a [Fix] is precise enough to be applied automatically (e.g.
/// by rewriting `pubspec.yaml`) and then checked by `verification`.
class Fix {
  final FixAction action;
  final Package package;

  /// The new constraint string to write, for [FixAction.updateConstraint]
  /// or [FixAction.addOverride].
  final String? newConstraint;

  final Recommendation recommendation;

  const Fix({
    required this.action,
    required this.package,
    required this.recommendation,
    this.newConstraint,
  });

  @override
  String toString() =>
      '${action.name} ${package.name}${newConstraint != null ? ' → $newConstraint' : ''}';
}
