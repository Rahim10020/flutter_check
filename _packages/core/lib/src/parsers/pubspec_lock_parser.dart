import 'package:yaml/yaml.dart';

import '../models/dependency.dart';
import '../models/package.dart';
import '../models/version.dart';

/// A single package entry as locked in `pubspec.lock`: the exact
/// version pub resolved to, and where it came from.
class LockedPackage {
  final Package package;
  final Version version;
  final DependencyKind kind;

  const LockedPackage({
    required this.package,
    required this.version,
    required this.kind,
  });
}

/// The result of parsing a `pubspec.lock` file: every package pub
/// actually resolved to a version, keyed by name.
class PubspecLockData {
  final Map<String, LockedPackage> packages;

  const PubspecLockData({required this.packages});
}

/// Parses the content of a `pubspec.lock` file into [PubspecLockData].
///
/// `pubspec.lock` records what Pub actually resolved — this is the
/// ground truth for "what version is installed right now", as
/// opposed to `pubspec.yaml`, which only records what's allowed.
class PubspecLockParser {
  const PubspecLockParser._();

  /// Parses [yamlContent], the raw text of a `pubspec.lock` file.
  ///
  /// Throws a [FormatException] if the content isn't valid YAML, or a
  /// [PubspecLockParseException] if it's valid YAML but doesn't have
  /// the shape expected of a lockfile.
  static PubspecLockData parse(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc is! Map) {
      throw const PubspecLockParseException('pubspec.lock must be a YAML map');
    }

    final packagesNode = doc['packages'];
    if (packagesNode is! Map) {
      return const PubspecLockData(packages: {});
    }

    final packages = <String, LockedPackage>{};
    for (final entry in packagesNode.entries) {
      final name = entry.key.toString();
      final data = entry.value;
      if (data is! Map) continue;

      final versionString = data['version']?.toString();
      final version = versionString != null
          ? Version.tryParse(versionString)
          : null;
      if (version == null) continue;

      packages[name] = LockedPackage(
        package: _parsePackage(name, data),
        version: version,
        kind: _parseKind(data['dependency']?.toString()),
      );
    }

    return PubspecLockData(packages: packages);
  }

  static Package _parsePackage(String name, Map data) {
    final sourceString = data['source']?.toString();
    switch (sourceString) {
      case 'git':
        final description = data['description'];
        final url = description is Map ? description['url']?.toString() : null;
        return Package(name: name, source: PackageSource.git, gitUrl: url);
      case 'path':
        final description = data['description'];
        final path = description is Map
            ? description['path']?.toString()
            : null;
        return Package(name: name, source: PackageSource.path, path: path);
      case 'sdk':
        return Package.sdkPackage(name);
      case 'hosted':
      default:
        return Package.hosted(name);
    }
  }

  static DependencyKind _parseKind(String? raw) {
    switch (raw) {
      case 'direct main':
        return DependencyKind.directMain;
      case 'direct dev':
        return DependencyKind.directDev;
      case 'direct overridden':
        return DependencyKind.directOverridden;
      case 'transitive':
      default:
        return DependencyKind.transitive;
    }
  }
}

/// Thrown when a `pubspec.lock` file is valid YAML but doesn't have
/// the structure expected of a lockfile.
class PubspecLockParseException implements Exception {
  final String message;
  const PubspecLockParseException(this.message);

  @override
  String toString() => 'PubspecLockParseException: $message';
}
