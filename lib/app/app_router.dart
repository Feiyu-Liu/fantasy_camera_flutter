import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_gate.dart';
import '../billing/presentation/credit_purchase_page.dart';
import '../features/generation_submission/presentation/generation_submission_modal.dart';
import '../features/notifications/presentation/notification_providers.dart';
import '../settings/presentation/settings_page.dart';

const String appHomeRoute = '/';
const String generationGalleryRoute = '/generation-gallery';
const String settingsRoute = '/settings';
const String creditPurchaseRoute = '/credits/purchase';

String generationGalleryRouteForTask(String taskId) {
  return Uri(
    path: generationGalleryRoute,
    queryParameters: <String, String>{'taskId': taskId},
  ).toString();
}

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: notificationNavigationDelegate.navigatorKey,
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
          return CupertinoPage<void>(
            child: GenerationSubmissionGalleryPage(
              focusedTaskId: state.uri.queryParameters['taskId'],
            ),
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
