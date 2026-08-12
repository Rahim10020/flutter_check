import '../models/package_metadata.dart';

/// Abstract access to published package metadata (versions, and each
/// version's own pubspec) — the contract the `graph` and `resolver`
/// layers depend on, without knowing or caring how the data is
/// actually obtained.
///
/// The Core never implements this itself: doing so would require an
/// HTTP client (or filesystem access to the local pub cache), which
/// would make the Core impure and dependent on I/O. Concrete
/// implementations belong to the apps that use the Core — e.g. an
/// HTTP-backed implementation calling the pub.dev "list all versions"
/// endpoint (`GET /api/packages/<package>`), or one reading from the
/// local `$PUB_CACHE` for offline use.
abstract class PackageMetadataSource {
  /// Fetches all known published version metadata for [packageName].
  ///
  /// Implementations should throw a [PackageMetadataException] if the
  /// package cannot be found or the source is unreachable — callers
  /// should not have to guess between "no data" and "an error
  /// occurred" from a null return.
  Future<PackageMetadata> fetch(String packageName);
}

/// Thrown by a [PackageMetadataSource] implementation when metadata
/// for a package cannot be retrieved.
class PackageMetadataException implements Exception {
  final String packageName;
  final String message;

  const PackageMetadataException(this.packageName, this.message);

  @override
  String toString() => 'PackageMetadataException($packageName): $message';
}
