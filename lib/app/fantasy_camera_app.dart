import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/camera/domain/camera_choice.dart';
import '../features/camera/presentation/camera_providers.dart';
import '../features/camera/presentation/camera_screen.dart';
import '../l10n/l10n.dart';

class FantasyCameraApp extends StatelessWidget {
  const FantasyCameraApp({required this.cameraChoices, super.key});

  final List<CameraChoice> cameraChoices;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        cameraChoicesProvider.overrideWithValue(cameraChoices),
      ],
      child: MaterialApp(
        title: appLocalizationsFor(defaultAppLocale).appTitle,
        debugShowCheckedModeBanner: false,
        locale: defaultAppLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CameraScreen(),
      ),
    );
  }
}
