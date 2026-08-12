import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../models/fix.dart';

const _dependencySections = [
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// Applies [Fix]es to the raw text of a `pubspec.yaml` file, editing
/// only the nodes that change and leaving everything else — comments,
/// formatting, key order — untouched.
class PubspecEditor {
  const PubspecEditor._();

  /// Returns the edited `pubspec.yaml` text after applying every fix
  /// in [fixes] to [pubspecYamlContent], in order.
  ///
  /// Throws a [FixApplicationException] if a fix can't be safely
  /// applied (e.g. the target package isn't declared anywhere, or is
  /// declared with a non-version-string source like `git`/`path` that
  /// [FixAction.updateConstraint] can't sensibly rewrite).
  static String apply(String pubspecYamlContent, Iterable<Fix> fixes) {
    final editor = YamlEditor(pubspecYamlContent);
    for (final fix in fixes) {
      _applyOne(editor, fix);
    }
    return editor.toString();
  }

  static void _applyOne(YamlEditor editor, Fix fix) {
    switch (fix.action) {
      case FixAction.updateConstraint:
        _updateConstraint(editor, fix);
        break;
      case FixAction.removeDependency:
        _removeDependency(editor, fix);
        break;
      case FixAction.addOverride:
        _addOverride(editor, fix);
        break;
    }
  }

  static void _updateConstraint(YamlEditor editor, Fix fix) {
    final section = _sectionContaining(editor, fix.package.name);
    if (section == null) {
      throw FixApplicationException(
        '${fix.package.name} is not declared in any dependency section.',
      );
    }

    final currentValue =
        (editor.parseAt([]) as YamlMap)[section][fix.package.name];
    if (currentValue is! String && currentValue != null) {
      throw FixApplicationException(
        '${fix.package.name} is declared with a non-version source '
        '(git/path/sdk) in "$section" — cannot rewrite it to a version constraint.',
      );
    }

    editor.update([section, fix.package.name], fix.newConstraint);
  }

  static void _removeDependency(YamlEditor editor, Fix fix) {
    final section = _sectionContaining(editor, fix.package.name);
    if (section == null) {
      throw FixApplicationException(
        '${fix.package.name} is not declared in any dependency section.',
      );
    }
    editor.remove([section, fix.package.name]);
  }

  static void _addOverride(YamlEditor editor, Fix fix) {
    if (fix.newConstraint == null) {
      throw FixApplicationException(
        'addOverride fix for ${fix.package.name} has no constraint to write.',
      );
    }

    final doc = editor.parseAt([]) as YamlMap;
    if (!doc.containsKey('dependency_overrides')) {
      editor.update(
        ['dependency_overrides'],
        {fix.package.name: fix.newConstraint},
      );
      return;
    }

    editor.update([
      'dependency_overrides',
      fix.package.name,
    ], fix.newConstraint);
  }

  /// Finds which of `dependencies` / `dev_dependencies` /
  /// `dependency_overrides` currently declares [packageName], or null
  /// if it's declared in none of them.
  static String? _sectionContaining(YamlEditor editor, String packageName) {
    final doc = editor.parseAt([]);
    if (doc is! YamlMap) return null;

    for (final section in _dependencySections) {
      final node = doc[section];
      if (node is YamlMap && node.containsKey(packageName)) {
        return section;
      }
    }
    return null;
  }
}

/// Thrown when a [Fix] can't be safely applied to a given
/// `pubspec.yaml`'s current content.
class FixApplicationException implements Exception {
  final String message;
  const FixApplicationException(this.message);

  @override
  String toString() => 'FixApplicationException: $message';
}
