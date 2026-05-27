// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get cameraNoCameraFound => '未找到相机。';

  @override
  String get cameraStartingCamera => '正在启动相机...';

  @override
  String cameraErrorMessage(Object message) {
    return '相机错误：$message';
  }
}
