import 'package:fluttercheck_core/fluttercheck_core.dart';

/// Formats analysis results as plain text for the terminal.
///
/// Deliberately a single, simple format for now — no color, no JSON.
/// The CLI's full output contract hasn't been decided yet (per the
/// project doc's rule against fixing command contracts prematurely),
/// so this stays minimal until that's designed.
class TextReportWriter {
  const TextReportWriter();

  String write({
    required Project project,
    required List<Issue> issues,
    required List<Recommendation> recommendations,
  }) {
    final buffer = StringBuffer();

    final env = project.environment;
    buffer.writeln('FlutterCheck report — ${project.name}');
    buffer.writeln(
      'Dart SDK: ${env.dartSdkConstraint ?? 'not declared'}'
      '${env.installedDartVersion != null ? ' (installed: ${env.installedDartVersion})' : ''}',
    );
    if (env.flutterSdkConstraint != null ||
        env.installedFlutterVersion != null) {
      buffer.writeln(
        'Flutter SDK: ${env.flutterSdkConstraint ?? 'not declared'}'
        '${env.installedFlutterVersion != null ? ' (installed: ${env.installedFlutterVersion})' : ''}',
      );
    }
    buffer.writeln();

    if (issues.isEmpty) {
      buffer.writeln('No issues found.');
      return buffer.toString();
    }

    buffer.writeln('Issues (${issues.length}):');
    for (final issue in issues) {
      buffer.writeln(
        '  [${issue.severity.name.toUpperCase()}] ${issue.description}',
      );
    }

    if (recommendations.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Recommendations (${recommendations.length}):');
      for (final r in recommendations) {
        buffer.writeln('  - ${r.summary}');
      }
    }

    return buffer.toString();
  }
}
