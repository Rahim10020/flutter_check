import 'dart:io';

import 'package:fluttercheck_core/fluttercheck_core.dart';

class ProjectWorkspaceImpl implements ProjectWorkspace {
  @override
  Future<T> withTemporaryCopy<T>(
    Project project,
    Future<T> Function(String tempPath) action,
  ) async {
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('fluttercheck_');

      final pubspecSource = File('${project.rootPath}/pubspec.yaml');
      if (!await pubspecSource.exists()) {
        throw ProjectWorkspaceException(
          'No pubspec.yaml found in ${project.rootPath}.',
        );
      }
      await pubspecSource.copy('${tempDir.path}/pubspec.yaml');

      final lockSource = File('${project.rootPath}/pubspec.lock');
      if (await lockSource.exists()) {
        await lockSource.copy('${tempDir.path}/pubspec.lock');
      }

      return await action(tempDir.path);
    } on ProjectWorkspaceException {
      rethrow;
    } catch (e) {
      throw ProjectWorkspaceException(
        'Failed to prepare temporary workspace for ${project.rootPath}: $e',
      );
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
