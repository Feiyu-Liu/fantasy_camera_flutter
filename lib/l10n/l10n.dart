import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

const Locale defaultAppLocale = Locale('zh');

AppLocalizations appLocalizationsFor(Locale locale) {
  return lookupAppLocalizations(locale);
}

abstract interface class AppLocalizationsAware {
  void bindLocalizations(AppLocalizations localizations);
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      appLocalizationsFor(defaultAppLocale);
}
