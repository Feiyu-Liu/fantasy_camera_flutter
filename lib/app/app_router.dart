import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_gate.dart';
import '../features/generation_submission/presentation/generation_gallery_assets_debug_page.dart';
import '../features/generation_submission/presentation/generation_submission_modal.dart';

const String appHomeRoute = '/';
const String generationGalleryRoute = '/generation-gallery';
const String generationGalleryAssetsDebugRoute =
    '/generation-gallery-assets-debug';

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
        path: generationGalleryAssetsDebugRoute,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const CupertinoPage<void>(
            child: GenerationGalleryAssetsDebugPage(),
          );
        },
      ),
    ],
  );
}
