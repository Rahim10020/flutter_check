import 'dart:convert';

import 'package:fluttercheck_core/fluttercheck_core.dart';
import 'package:http/http.dart' as http;

/// Implements [PackageMetadataSource] by calling the official pub.dev
/// "list all versions of a package" endpoint
/// (`GET https://pub.dev/api/packages/<package>`), documented in the
/// Hosted Pub Repository Specification V2. Each returned version
/// includes its own full pubspec, which is what makes transitive
/// dependency resolution possible.
class PubDevMetadataSource implements PackageMetadataSource {
  final Uri hostedUrl;
  final http.Client _client;

  PubDevMetadataSource({Uri? hostedUrl, http.Client? client})
    : hostedUrl = hostedUrl ?? Uri.parse('https://pub.dev'),
      _client = client ?? http.Client();

  @override
  Future<PackageMetadata> fetch(String packageName) async {
    final uri = hostedUrl.resolve('/api/packages/$packageName');

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {'Accept': 'application/vnd.pub.v2+json'},
      );
    } catch (e) {
      throw PackageMetadataException(packageName, 'Request to $uri failed: $e');
    }

    if (response.statusCode == 404) {
      throw PackageMetadataException(
        packageName,
        'Package not found on $hostedUrl.',
      );
    }
    if (response.statusCode != 200) {
      throw PackageMetadataException(
        packageName,
        'Unexpected status ${response.statusCode} from $uri.',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw PackageMetadataException(
        packageName,
        'Response from $uri was not valid JSON: $e',
      );
    }

    return _parse(packageName, body);
  }

  PackageMetadata _parse(String packageName, Map<String, dynamic> body) {
    final latestVersionString =
        (body['latest'] as Map<String, dynamic>?)?['version'] as String?;
    final versionsJson = body['versions'] as List<dynamic>? ?? const [];

    final versions = <PackageVersionMetadata>[];
    for (final entry in versionsJson) {
      if (entry is! Map<String, dynamic>) continue;

      final versionString = entry['version'] as String?;
      final version = versionString != null
          ? Version.tryParse(versionString)
          : null;
      final pubspecJson = entry['pubspec'] as Map<String, dynamic>?;
      if (version == null || pubspecJson == null) continue;

      final PubspecData pubspecData;
      try {
        pubspecData = PubspecParser.parseMap(pubspecJson);
      } on PubspecParseException {
        // A malformed pubspec for one specific version shouldn't take
        // down metadata for every other version of the package.
        continue;
      }

      versions.add(
        PackageVersionMetadata(
          version: version,
          pubspec: pubspecData,
          isRetracted: entry['retracted'] as bool? ?? false,
        ),
      );
    }

    return PackageMetadata(
      name: packageName,
      latestVersion: latestVersionString != null
          ? Version.tryParse(latestVersionString)
          : null,
      versions: versions,
    );
  }
}
