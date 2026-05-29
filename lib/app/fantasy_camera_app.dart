import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_gate.dart';
import '../l10n/l10n.dart';

class FantasyCameraApp extends StatelessWidget {
  const FantasyCameraApp({this.overrides = const <Override>[], super.key});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: CupertinoApp(
        title: appLocalizationsFor(defaultAppLocale).appTitle,
        debugShowCheckedModeBanner: false,
        locale: defaultAppLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: CupertinoColors.black,
          primaryColor: CupertinoColors.white,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
