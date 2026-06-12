import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_gate.dart';
import '../billing/presentation/credit_purchase_page.dart';
import '../features/generation_submission/presentation/generation_submission_modal.dart';
import '../settings/presentation/settings_page.dart';

const String appHomeRoute = '/';
const String generationGalleryRoute = '/generation-gallery';
const String settingsRoute = '/settings';
const String creditPurchaseRoute = '/credits/purchase';

GoRouter createAppRouter() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: appHomeRoute,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const CupertinoPage<void>(child: AuthGate());
        },
      ),
      GoRoute(
        path: generationGalleryRoute,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const CupertinoPage<void>(
            child: GenerationSubmissionGalleryPage(),
          );
        },
      ),
      GoRoute(
        path: settingsRoute,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const CupertinoPage<void>(child: SettingsPage());
        },
      ),
      GoRoute(
        path: creditPurchaseRoute,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const CupertinoPage<void>(child: CreditPurchasePage());
        },
      ),
    ],
  );
}
