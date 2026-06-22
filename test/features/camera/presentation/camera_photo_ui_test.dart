import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_ui.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_tokens.dart';
import 'package:fantasy_camera_flutter/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery button shows green result badge on success', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CameraPhotoGalleryButton(
            tokens: CameraUiTokens(),
            badgeStatus: CameraGalleryBadgeStatus.success,
          ),
        ),
      ),
    );

    final DecoratedBox badge = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
    );
    final BoxDecoration decoration = badge.decoration as BoxDecoration;

    expect(
      find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
      findsOneWidget,
    );
    expect(decoration.color, AppColors.success);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, hasLength(2));
    _expectBadgeOutsideTopRight(tester);
  });

  testWidgets('gallery button shows red result badge on failure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CameraPhotoGalleryButton(
            tokens: CameraUiTokens(),
            badgeStatus: CameraGalleryBadgeStatus.failure,
          ),
        ),
      ),
    );

    final DecoratedBox badge = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
    );
    final BoxDecoration decoration = badge.decoration as BoxDecoration;

    expect(
      find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
      findsOneWidget,
    );
    expect(decoration.color, AppColors.danger);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, hasLength(2));
    _expectBadgeOutsideTopRight(tester);
  });

  testWidgets('gallery button hides result badge by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(child: CameraPhotoGalleryButton(tokens: CameraUiTokens())),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
      findsNothing,
    );
  });
}

void _expectBadgeOutsideTopRight(WidgetTester tester) {
  final Rect buttonRect = tester.getRect(find.byType(CameraPhotoGalleryButton));
  final Rect badgeRect = tester.getRect(
    find.byKey(const ValueKey<String>('camera-gallery-result-badge')),
  );

  expect(badgeRect.top, lessThan(buttonRect.top));
  expect(badgeRect.right, greaterThan(buttonRect.right));
}
