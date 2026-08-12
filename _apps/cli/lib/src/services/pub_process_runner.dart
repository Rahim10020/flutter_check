import 'dart:convert';
import 'dart:io';

import 'package:fluttercheck_core/fluttercheck_core.dart';

/// Implements [PubRunner] by invoking a real `dart pub` or
/// `flutter pub` subprocess against the project's own directory.
///
/// Change-by-change parsing of `pub get`/`pub upgrade --dry-run`
/// output is intentionally not attempted: no stable, documented
/// format for those lines was found during research (unlike
/// `pub add --dry-run --json`, which is documented). Only the
/// process's exit code (solved / failed — both reliably documented)
/// and its full raw output are used. [PubSolveResult.changes] is
/// always empty from this implementation for now.
class PubProcessRunner implements PubRunner {
  @override
  Future<PubSolveResult> getDryRun(Project project) =>
      _runSolve(project, const ['get', '--dry-run'], PubCommand.getDryRun);

  @override
  Future<PubSolveResult> upgradeDryRun(Project project) => _runSolve(
    project,
    const ['upgrade', '--dry-run'],
    PubCommand.upgradeDryRun,
  );

  @override
  Future<PubSolveResult> upgradeMajorVersionsDryRun(Project project) =>
      _runSolve(project, const [
        'upgrade',
        '--major-versions',
        '--dry-run',
      ], PubCommand.upgradeMajorVersionsDryRun);

  Future<PubSolveResult> _runSolve(
    Project project,
    List<String> pubArgs,
    PubCommand command,
  ) async {
    final result = await _run(project, pubArgs);
    final output = _combinedOutput(result);

    return PubSolveResult(
      command: command,
      outcome: result.exitCode == 0
          ? PubSolveOutcome.solved
          : PubSolveOutcome.failed,
      rawOutput: output,
    );
  }

  @override
  Future<List<OutdatedPackageInfo>> outdated(Project project) async {
    final result = await _run(project, const ['outdated', '--json']);

    // Unlike the dry-run solve commands, `pub outdated --json` is
    // documented to emit machine-readable JSON regardless of outcome,
    // so a non-zero exit here (which `pub outdated` can return even
    // on success, depending on findings) doesn't by itself mean parsing
    // should be skipped — only a genuinely unparsable body does.
    Map<String, dynamic> body;
    try {
      body = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    } catch (e) {
      throw PubRunnerException(
        'Could not parse `pub outdated --json` output for ${project.name}: $e\n'
        'Raw output: ${_combinedOutput(result)}',
      );
    }

    final packagesJson = body['packages'] as List<dynamic>? ?? const [];
    final infos = <OutdatedPackageInfo>[];

    for (final entry in packagesJson) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['package'] as String?;
      if (name == null) continue;

      infos.add(
        OutdatedPackageInfo(
          package: Package.hosted(name),
          current: _versionField(entry, 'current'),
          upgradable: _versionField(entry, 'upgradable'),
          resolvable: _versionField(entry, 'resolvable'),
          latest: _versionField(entry, 'latest'),
        ),
      );
    }

    return infos;
  }

  Version? _versionField(Map<String, dynamic> entry, String key) {
    final field = entry[key] as Map<String, dynamic>?;
    final versionString = field?['version'] as String?;
    return versionString != null ? Version.tryParse(versionString) : null;
  }

  Future<ProcessResult> _run(Project project, List<String> pubArgs) async {
    final executable = _executableFor(project);
    try {
      return await Process.run(executable, [
        'pub',
        ...pubArgs,
      ], workingDirectory: project.rootPath);
    } catch (e) {
      throw PubRunnerException(
        'Failed to run "$executable pub ${pubArgs.join(' ')}" in '
        '${project.rootPath}: $e',
      );
    }
  }

  String _combinedOutput(ProcessResult result) {
    final stdout = result.stdout?.toString() ?? '';
    final stderr = result.stderr?.toString() ?? '';
    return [stdout, stderr].where((s) => s.trim().isNotEmpty).join('\n').trim();
  }

  /// Whether [project] is a Flutter project (needs `flutter pub`) or a
  /// plain Dart project (`dart pub` suffices). Flutter projects must
  /// use `flutter pub` because the Flutter SDK provides the `flutter`
  /// package itself — `dart pub` alone cannot resolve it.
  String _executableFor(Project project) {
    final declaresFlutterSdk = project.environment.flutterSdkConstraint != null;
    final dependsOnFlutterSdk = project.dependencies.any(
      (d) =>
          d.package.source == PackageSource.sdk && d.package.sdk == 'flutter',
    );
    return (declaresFlutterSdk || dependsOnFlutterSdk) ? 'flutter' : 'dart';
  }
}
