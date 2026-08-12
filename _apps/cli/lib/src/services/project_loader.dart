import 'dart:convert';
import 'dart:io';

import 'package:fluttercheck_core/fluttercheck_core.dart';

/// Reads a Flutter/Dart project from disk — `pubspec.yaml`,
/// `pubspec.lock` (if present), and the actually-installed Dart/Flutter
/// SDK versions — and assembles it into a [Project] via the Core's
/// pure parsing/building layers.
///
/// This is the seam between the filesystem and the Core: everything
/// below this class (parsers, [ProjectBuilder]) takes already-read
/// text, never file paths — see the Core's own docs on why.
class ProjectLoader {
  const ProjectLoader();

  /// Loads the project rooted at [rootPath].
  ///
  /// Throws a [ProjectLoadException] if `pubspec.yaml` is missing or
  /// invalid. A missing `pubspec.lock` is not an error — it's a
  /// meaningful state (`pub get` was never run) that [DependencyMerger]
  /// already knows how to represent.
  Future<Project> load(String rootPath) async {
    final pubspecFile = File('$rootPath/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw ProjectLoadException('No pubspec.yaml found in $rootPath.');
    }

    final PubspecData pubspecData;
    try {
      pubspecData = PubspecParser.parse(await pubspecFile.readAsString());
    } on PubspecParseException catch (e) {
      throw ProjectLoadException(
        'Invalid pubspec.yaml in $rootPath: ${e.message}',
      );
    }

    final lockFile = File('$rootPath/pubspec.lock');
    PubspecLockData? lockData;
    if (await lockFile.exists()) {
      try {
        lockData = PubspecLockParser.parse(await lockFile.readAsString());
      } on PubspecLockParseException catch (e) {
        throw ProjectLoadException(
          'Invalid pubspec.lock in $rootPath: ${e.message}',
        );
      }
    }

    final project = ProjectBuilder.build(
      rootPath: rootPath,
      pubspecData: pubspecData,
      lockData: lockData,
    );

    final installedDart = await _installedDartVersion();
    final installedFlutter = await _installedFlutterVersion();

    if (installedDart == null && installedFlutter == null) {
      return project;
    }

    return Project(
      name: project.name,
      rootPath: project.rootPath,
      dependencies: project.dependencies,
      environment: project.environment.copyWith(
        installedDartVersion: installedDart,
        installedFlutterVersion: installedFlutter,
      ),
    );
  }

  /// The Dart SDK actually running this CLI. [Platform.version] looks
  /// like "3.4.0 (stable) (...) on ...\n" — only the leading semver
  /// token is meaningful here.
  Future<Version?> _installedDartVersion() async {
    final token = Platform.version.split(' ').first;
    return Version.tryParse(token);
  }

  /// The installed Flutter SDK version, obtained by running
  /// `flutter --version --machine`. Returns null (not an error) if
  /// `flutter` isn't on PATH — a pure Dart project legitimately has
  /// no Flutter SDK installed.
  Future<Version?> _installedFlutterVersion() async {
    ProcessResult result;
    try {
      result = await Process.run('flutter', ['--version', '--machine']);
    } catch (_) {
      return null;
    }

    if (result.exitCode != 0) return null;

    try {
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final versionString = json['frameworkVersion'] as String?;
      return versionString != null ? Version.tryParse(versionString) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Thrown when a project on disk can't be loaded — missing or invalid
/// `pubspec.yaml`/`pubspec.lock`.
class ProjectLoadException implements Exception {
  final String message;
  const ProjectLoadException(this.message);

  @override
  String toString() => 'ProjectLoadException: $message';
}
