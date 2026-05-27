// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get cameraNoCameraFound => 'No camera found.';

  @override
  String get cameraStartingCamera => 'Starting camera...';

  @override
  String cameraErrorMessage(Object message) {
    return 'Camera error: $message';
  }
}
