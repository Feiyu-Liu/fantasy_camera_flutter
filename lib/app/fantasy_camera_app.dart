import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_providers.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'app_router.dart';

class FantasyCameraApp extends StatelessWidget {
  const FantasyCameraApp({this.overrides = const <Override>[], super.key});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: CupertinoApp.router(
        title: appLocalizationsFor(defaultAppLocale).appTitle,
        debugShowCheckedModeBanner: false,
        locale: defaultAppLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return ProviderScope(
            overrides: <Override>[
              appLocalizationsProvider.overrideWithValue(context.l10n),
            ],
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.black,
          primaryColor: AppColors.white,
        ),
        routerConfig: createAppRouter(),
      ),
    );
  }
}
