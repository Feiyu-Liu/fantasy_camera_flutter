import 'dart:convert';
import 'dart:io';

const List<ConfigKey> requiredKeys = <ConfigKey>[
  ConfigKey(
    'SUPABASE_URL',
    description: 'Supabase project URL',
    validator: validateHttpsUrl,
  ),
  ConfigKey(
    'SUPABASE_PUBLISHABLE_KEY',
    description: 'Supabase publishable client key',
    validator: validateSupabasePublishableKey,
  ),
  ConfigKey(
    'GOOGLE_IOS_CLIENT_ID',
    description: 'Google Sign-In iOS OAuth client ID',
    validator: validateGoogleClientId,
  ),
  ConfigKey(
    'GOOGLE_WEB_CLIENT_ID',
    description: 'Google Sign-In web OAuth client ID',
    validator: validateGoogleClientId,
  ),
  ConfigKey(
    'WORKER_API_BASE_URL',
    description: 'Cloudflare Worker API base URL',
    validator: validateHttpsUrl,
  ),
  ConfigKey(
    'REVENUECAT_IOS_PUBLIC_SDK_KEY',
    description: 'RevenueCat iOS public SDK key',
    validator: validateRevenueCatPublicKey,
  ),
  ConfigKey(
    'REVENUECAT_OFFERING_ID',
    description: 'RevenueCat offering ID for credit packs',
    validator: validateNonEmpty,
  ),
  ConfigKey(
    'PUSH_NOTIFICATION_TOPIC',
    description: 'APNs topic matching the iOS bundle identifier',
    validator: validatePushTopic,
  ),
];

void main(List<String> args) {
  final ParsedArgs parsedArgs = parseArgs(args);
  if (parsedArgs.showHelp) {
    printUsage();
    return;
  }

  final Map<String, String> values = <String, String>{...Platform.environment};
  if (parsedArgs.envFilePath != null) {
    values.addAll(readDefineFile(parsedArgs.envFilePath!));
  }

  final List<String> failures = <String>[];
  final List<String> warnings = <String>[];
  final List<String> dartDefines = <String>[];

  stdout.writeln('Release dart-define smoke check');
  stdout.writeln('Source: ${parsedArgs.envFilePath ?? 'process environment'}');
  stdout.writeln('');

  for (final ConfigKey key in requiredKeys) {
    final String value = values[key.name]?.trim() ?? '';
    final ValidationResult result = key.validator(value);
    if (!result.ok) {
      failures.add('${key.name}: ${result.message}');
    }
    if (result.warning != null) {
      warnings.add('${key.name}: ${result.warning}');
    }
    if (value.isNotEmpty) {
      dartDefines.add('--dart-define=${key.name}=$value');
    }
    stdout.writeln(
      '${key.name.padRight(32)} ${value.isEmpty ? '(missing)' : maskValue(value)}'
      '  ${key.description}',
    );
  }

  if (warnings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Warnings:');
    for (final String warning in warnings) {
      stdout.writeln('- $warning');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('');
    stderr.writeln('Release config smoke failed:');
    for (final String failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('');
  stdout.writeln('OK: all required release dart-defines are present.');
  if (parsedArgs.emitDartDefines) {
    stdout.writeln('');
    stdout.writeln('Dart define flags:');
    for (final String dartDefine in dartDefines) {
      stdout.writeln(dartDefine);
    }
  }
}

ParsedArgs parseArgs(List<String> args) {
  String? envFilePath;
  bool emitDartDefines = false;
  bool showHelp = false;

  for (int i = 0; i < args.length; i += 1) {
    final String arg = args[i];
    switch (arg) {
      case '--env-file':
        if (i + 1 >= args.length) {
          usageError('--env-file requires a path.');
        }
        envFilePath = args[++i];
      case '--emit-dart-defines':
        emitDartDefines = true;
      case '-h':
      case '--help':
        showHelp = true;
      default:
        usageError('Unknown argument: $arg');
    }
  }

  return ParsedArgs(
    envFilePath: envFilePath,
    emitDartDefines: emitDartDefines,
    showHelp: showHelp,
  );
}

Map<String, String> readDefineFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Env file not found: $path');
    exit(1);
  }

  final String content = file.readAsStringSync().trim();
  if (content.startsWith('{')) {
    return readJsonDefineFile(content, path);
  }
  return readEnvFile(content, path);
}

Map<String, String> readJsonDefineFile(String content, String path) {
  final Object? decoded;
  try {
    decoded = json.decode(content);
  } on FormatException catch (error) {
    stderr.writeln('Invalid JSON define file $path: ${error.message}');
    exit(1);
  }

  if (decoded is! Map<String, Object?>) {
    stderr.writeln('JSON define file must contain an object: $path');
    exit(1);
  }

  final Map<String, String> values = <String, String>{};
  for (final MapEntry<String, Object?> entry in decoded.entries) {
    final Object? value = entry.value;
    if (value is String) {
      values[entry.key] = value;
    } else if (value == null) {
      values[entry.key] = '';
    } else {
      values[entry.key] = value.toString();
    }
  }
  return values;
}

Map<String, String> readEnvFile(String content, String path) {
  final Map<String, String> values = <String, String>{};
  final List<String> lines = const LineSplitter().convert(content);
  for (int i = 0; i < lines.length; i += 1) {
    String line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line.startsWith('export ')) {
      line = line.substring('export '.length).trim();
    }
    final int separator = line.indexOf('=');
    if (separator <= 0) {
      stderr.writeln('Invalid env line ${i + 1} in $path: ${lines[i]}');
      exit(1);
    }
    final String key = line.substring(0, separator).trim();
    final String value = unquote(line.substring(separator + 1).trim());
    values[key] = value;
  }
  return values;
}

String unquote(String value) {
  if (value.length >= 2) {
    final String first = value[0];
    final String last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

ValidationResult validateHttpsUrl(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return const ValidationResult(false, 'must be an absolute URL.');
  }
  if (uri.scheme != 'https') {
    return const ValidationResult(false, 'must use https.');
  }
  return const ValidationResult(true, 'ok');
}

ValidationResult validateSupabasePublishableKey(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  if (value.startsWith('sb_secret_') || value.contains('service_role')) {
    return const ValidationResult(
      false,
      'must be a publishable client key, not a service role or secret key.',
    );
  }
  if (!value.startsWith('sb_publishable_') && !looksLikeJwt(value)) {
    return const ValidationResult(
      true,
      'ok',
      warning:
          'does not look like a modern sb_publishable key or legacy JWT anon key.',
    );
  }
  return const ValidationResult(true, 'ok');
}

ValidationResult validateGoogleClientId(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  if (!value.endsWith('.apps.googleusercontent.com')) {
    return const ValidationResult(
      false,
      'must end with .apps.googleusercontent.com.',
    );
  }
  return const ValidationResult(true, 'ok');
}

ValidationResult validateRevenueCatPublicKey(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  if (value.startsWith('sk_') || value.toLowerCase().contains('secret')) {
    return const ValidationResult(
      false,
      'must be the iOS public SDK key, not the secret API key.',
    );
  }
  if (!value.startsWith('appl_')) {
    return const ValidationResult(
      true,
      'ok',
      warning:
          'does not look like a RevenueCat iOS public key starting with appl_.',
    );
  }
  return const ValidationResult(true, 'ok');
}

ValidationResult validatePushTopic(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  if (!value.contains('.')) {
    return const ValidationResult(
      false,
      'must look like an iOS bundle identifier, for example host.eunoia.tessercam.',
    );
  }
  return const ValidationResult(true, 'ok');
}

ValidationResult validateNonEmpty(String value) {
  if (value.isEmpty) {
    return const ValidationResult(false, 'value is required.');
  }
  return const ValidationResult(true, 'ok');
}

bool looksLikeJwt(String value) => value.split('.').length == 3;

String maskValue(String value) {
  if (value.length <= 8) {
    return '*' * value.length;
  }
  final int headLength = value.startsWith('https://') ? 16 : 6;
  final int safeHeadLength = headLength.clamp(0, value.length ~/ 2);
  final int tailLength = 4.clamp(0, value.length - safeHeadLength);
  return '${value.substring(0, safeHeadLength)}...${value.substring(value.length - tailLength)}';
}

void printUsage() {
  stdout.writeln(
    'Usage: dart run tool/verify_release_dart_defines.dart [options]',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --env-file <path>       Read KEY=value pairs from a release env file.',
  );
  stdout.writeln(
    '  --emit-dart-defines     Print full --dart-define flags after validation.',
  );
  stdout.writeln('  -h, --help              Show this help.');
}

Never usageError(String message) {
  stderr.writeln(message);
  stderr.writeln('');
  printUsage();
  exit(64);
}

class ParsedArgs {
  const ParsedArgs({
    required this.envFilePath,
    required this.emitDartDefines,
    required this.showHelp,
  });

  final String? envFilePath;
  final bool emitDartDefines;
  final bool showHelp;
}

class ConfigKey {
  const ConfigKey(
    this.name, {
    required this.description,
    required this.validator,
  });

  final String name;
  final String description;
  final ValidationResult Function(String value) validator;
}

class ValidationResult {
  const ValidationResult(this.ok, this.message, {this.warning});

  final bool ok;
  final String message;
  final String? warning;
}
