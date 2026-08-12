import 'package:yaml/yaml.dart';

import '../models/constraint.dart';
import '../models/dependency.dart';
import '../models/environment.dart';
import '../models/package.dart';

/// The result of parsing a `pubspec.yaml` file: the project's declared
/// name, SDK environment, and dependencies as written by the
/// developer (constraints only — no resolved versions; those come
/// from [PubspecLockParser]).
class PubspecData {
  final String name;
  final Environment environment;
  final List<Dependency> dependencies;

  const PubspecData({
    required this.name,
    required this.environment,
    required this.dependencies,
  });
}

/// Parses the content of a `pubspec.yaml` file into [PubspecData].
///
/// This only interprets the structure of the file — it does not
/// contact pub.dev, does not resolve versions, and does not know
/// whether the declared constraints are actually satisfiable.
class PubspecParser {
  const PubspecParser._();

  /// Parses [yamlContent], the raw text of a `pubspec.yaml` file.
  ///
  /// Throws a [FormatException] if the content isn't valid YAML, or a
  /// [PubspecParseException] if it's valid YAML but doesn't have the
  /// shape expected of a pubspec (e.g. missing `name`).
  static PubspecData parse(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc is! Map) {
      throw const PubspecParseException('pubspec.yaml must be a YAML map');
    }

    final name = doc['name'];
    if (name is! String || name.isEmpty) {
      throw const PubspecParseException(
        'pubspec.yaml is missing a valid "name"',
      );
    }

    final environment = _parseEnvironment(doc['environment']);

    final dependencies = <Dependency>[
      ..._parseSection(doc['dependencies'], DependencyKind.directMain),
      ..._parseSection(doc['dev_dependencies'], DependencyKind.directDev),
      ..._parseSection(
        doc['dependency_overrides'],
        DependencyKind.directOverridden,
      ),
    ];

    return PubspecData(
      name: name,
      environment: environment,
      dependencies: dependencies,
    );
  }

  static Environment _parseEnvironment(dynamic node) {
    if (node is! Map) return const Environment();

    final sdk = node['sdk'];
    final flutter = node['flutter'];

    return Environment(
      dartSdkConstraint: sdk is String ? Constraint.tryParse(sdk) : null,
      flutterSdkConstraint: flutter is String
          ? Constraint.tryParse(flutter)
          : null,
    );
  }

  static List<Dependency> _parseSection(dynamic node, DependencyKind kind) {
    if (node is! Map) return const [];

    final result = <Dependency>[];
    for (final entry in node.entries) {
      final packageName = entry.key.toString();
      final spec = entry.value;
      result.add(_parseDependency(packageName, spec, kind));
    }
    return result;
  }

  static Dependency _parseDependency(
    String name,
    dynamic spec,
    DependencyKind kind,
  ) {
    // A bare version string: `http: ^1.2.0`, or `any`/null for no constraint.
    if (spec == null || spec is String) {
      final constraint = (spec is String) ? Constraint.tryParse(spec) : null;
      return Dependency(
        package: Package.hosted(name),
        kind: kind,
        constraint: constraint,
      );
    }

    // A map: sdk / git / path / hosted dependency.
    if (spec is Map) {
      if (spec.containsKey('sdk')) {
        final sdkName = spec['sdk']?.toString() ?? name;
        return Dependency(
          package: Package(name: name, source: PackageSource.sdk, sdk: sdkName),
          kind: kind,
        );
      }

      if (spec.containsKey('git')) {
        final git = spec['git'];
        final url = git is Map ? git['url']?.toString() : git?.toString();
        return Dependency(
          package: Package(name: name, source: PackageSource.git, gitUrl: url),
          kind: kind,
        );
      }

      if (spec.containsKey('path')) {
        return Dependency(
          package: Package(
            name: name,
            source: PackageSource.path,
            path: spec['path']?.toString(),
          ),
          kind: kind,
        );
      }

      // Hosted dependency with an explicit version key, e.g.
      // `http: {version: ^1.2.0, hosted: ...}`.
      final version = spec['version'];
      return Dependency(
        package: Package.hosted(name),
        kind: kind,
        constraint: version is String ? Constraint.tryParse(version) : null,
      );
    }

    // Unrecognized shape — treat as an unconstrained hosted dependency
    // rather than throwing, so one odd entry doesn't block the whole
    // analysis. Downstream layers can flag it as missing information.
    return Dependency(package: Package.hosted(name), kind: kind);
  }
}

/// Thrown when a `pubspec.yaml` file is valid YAML but doesn't have
/// the structure expected of a pubspec.
class PubspecParseException implements Exception {
  final String message;
  const PubspecParseException(this.message);

  @override
  String toString() => 'PubspecParseException: $message';
}
