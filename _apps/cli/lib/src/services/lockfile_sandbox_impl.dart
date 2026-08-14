import 'dart:io';

import 'package:fluttercheck_core/fluttercheck_core.dart';

/// Implements [LockfileSandbox] using [ProjectWorkspace] for the
/// temporary copy and a direct `dart pub`/`flutter pub` process
/// invocation for the real resolution — same executable-selection
/// logic as [PubProcessRunner], since the sandboxed copy must resolve
/// the same way the real project would.
class LockfileSandboxImpl implements LockfileSandbox {
  final ProjectWorkspace workspace;

  LockfileSandboxImpl({required this.workspace});

  @override
  Future<List<PubDependencyChange>> resolveChanges(
    Project project,
    PubCommand command,
  ) async {
    // Throws UnsupportedError for upgradeMajorVersionsDryRun — by
    // design, propagates directly to the caller.
    final realCommand = RealPubCommand.forDryRun(command);

    final beforeLock = await _readLockedVersions(
      '${project.rootPath}/pubspec.lock',
    );

    return workspace.withTemporaryCopy(project, (tempPath) async {
      final executable = _executableFor(project);
      final result = await Process.run(executable, [
        'pub',
        ...realCommand.pubArgs,
      ], workingDirectory: tempPath);

      if (result.exitCode != 0) {
        throw ProjectWorkspaceException(
          'Sandbox pub resolution failed unexpectedly for '
          '${project.rootPath} (command: ${realCommand.pubArgs.join(' ')}), '
          'despite a prior dry-run reporting success.\n'
          'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
      }

      final afterLock = await _readLockedVersions('$tempPath/pubspec.lock');
      return _diff(beforeLock, afterLock);
    });
  }

  Future<Map<String, Version>> _readLockedVersions(String lockPath) async {
    final file = File(lockPath);
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    final lockData = PubspecLockParser.parse(content);
    return {
      for (final entry in lockData.packages.entries)
        entry.key: entry.value.version,
    };
  }

  List<PubDependencyChange> _diff(
    Map<String, Version> before,
    Map<String, Version> after,
  ) {
    final changes = <PubDependencyChange>[];
    final allNames = {...before.keys, ...after.keys};

    for (final name in allNames) {
      final fromVersion = before[name];
      final toVersion = after[name];
      final package = Package.hosted(name);

      if (fromVersion == null && toVersion != null) {
        changes.add(PubDependencyChange.added(package: package, to: toVersion));
      } else if (fromVersion != null && toVersion == null) {
        changes.add(
          PubDependencyChange.removed(package: package, from: fromVersion),
        );
      } else if (fromVersion != null &&
          toVersion != null &&
          fromVersion != toVersion) {
        changes.add(
          PubDependencyChange.changed(
            package: package,
            from: fromVersion,
            to: toVersion,
          ),
        );
      }
    }

    return changes;
  }

  String _executableFor(Project project) {
    final declaresFlutterSdk = project.environment.flutterSdkConstraint != null;
    final dependsOnFlutterSdk = project.dependencies.any(
      (d) =>
          d.package.source == PackageSource.sdk && d.package.sdk == 'flutter',
    );
    return (declaresFlutterSdk || dependsOnFlutterSdk) ? 'flutter' : 'dart';
  }
}
