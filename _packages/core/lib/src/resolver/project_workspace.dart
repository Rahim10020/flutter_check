import '../models/project.dart';

/// Abstract access to a temporary, disposable copy of a project's
/// `pubspec.yaml` (and `pubspec.lock`, if present) — the minimum
/// needed for `pub` to resolve dependencies without touching the
/// user's real project.
///
/// Only these two files are copied — not `lib/`, not build artifacts.
/// A real `pub get`/`pub upgrade` only needs them to resolve; nothing
/// else in the project affects dependency resolution.
///
/// Concrete implementations (creating the temp directory, copying
/// files, guaranteeing cleanup even on exception) belong to the apps
/// that use the Core — same pattern as [PubRunner] and
/// [PackageMetadataSource]. The Core never touches the filesystem
/// itself.
abstract class ProjectWorkspace {
  /// Copies [project]'s `pubspec.yaml` (and `pubspec.lock`, if it
  /// exists) into a fresh temporary directory, runs [action] with
  /// that directory's path, and guarantees the directory is removed
  /// afterward — including if [action] throws.
  Future<T> withTemporaryCopy<T>(
    Project project,
    Future<T> Function(String tempPath) action,
  );
}

/// Thrown by a [ProjectWorkspace] implementation when the temporary
/// copy could not be created (disk I/O failure, permissions, etc.) —
/// distinct from a failure inside the caller's [action] callback.
class ProjectWorkspaceException implements Exception {
  final String message;
  const ProjectWorkspaceException(this.message);

  @override
  String toString() => 'ProjectWorkspaceException: $message';
}
