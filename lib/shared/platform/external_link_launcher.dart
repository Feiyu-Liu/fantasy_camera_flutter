import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

final externalLinkLauncherProvider = Provider<ExternalLinkLauncher>((Ref ref) {
  return (Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  };
}, dependencies: const <ProviderOrFamily>[]);
