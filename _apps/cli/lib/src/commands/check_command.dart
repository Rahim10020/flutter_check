import 'dart:io';

import 'package:fluttercheck_core/fluttercheck_core.dart';

import '../outputs/text_report_writer.dart';
import '../services/project_loader.dart';
import '../services/pub_process_runner.dart';

/// Implements `fluttercheck check`: loads a project, analyzes it, and
/// asks a real `pub` process whether its dependencies actually
/// resolve — then reports everything found. Read-only: never writes
/// to pubspec.yaml or pubspec.lock.
class CheckCommand {
  final ProjectLoader _loader;
  final PubRunner _pubRunner;

  CheckCommand({ProjectLoader? loader, PubRunner? pubRunner})
    : _loader = loader ?? const ProjectLoader(),
      _pubRunner = pubRunner ?? PubProcessRunner();

  /// Runs the check for the project at [rootPath]. Returns the
  /// process exit code: 0 if no error-severity issue was found or
  /// the resolution otherwise succeeded, 1 otherwise.
  Future<int> run(String rootPath) async {
    final Project project;
    try {
      project = await _loader.load(rootPath);
    } on ProjectLoadException catch (e) {
      stderr.writeln(e.message);
      return 1;
    }

    final analyzerIssues = ProjectAnalyzer.analyze(project);

    final ResolutionOutcome resolution;
    try {
      resolution = await DependencyResolver(
        pubRunner: _pubRunner,
      ).resolve(project);
    } on PubRunnerException catch (e) {
      stderr.writeln('Could not run pub: ${e.message}');
      return 1;
    }

    final allIssues = [...analyzerIssues, ...resolution.issues];
    final recommendations = [
      ...IssueRecommender.recommend(project, analyzerIssues),
      ...resolution.recommendations,
    ];

    stdout.writeln(
      const TextReportWriter().write(
        project: project,
        issues: allIssues,
        recommendations: recommendations,
      ),
    );

    final hasError = allIssues.any((i) => i.severity == IssueSeverity.error);
    return hasError ? 1 : 0;
  }
}
