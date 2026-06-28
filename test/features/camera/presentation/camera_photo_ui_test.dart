import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_ui.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_models.dart';
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

  testWidgets('mode selector shows manual extension only when selected', (
    WidgetTester tester,
  ) async {
    String selectedMode = 'general';
    int extensionTapCount = 0;

    Future<void> pump() {
      return tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 180,
                child: CameraPhotoModeExpansionMotion(
                  tokens: const CameraUiTokens(),
                  modes: const <CameraUiMode>[
                    CameraUiMode(id: 'general', label: 'AUTO'),
                    CameraUiMode(id: 'portrait', label: 'MANUAL'),
                  ],
                  selectedModeId: selectedMode,
                  modeExtensions: <String, List<Widget>>{
                    'portrait': <Widget>[
                      CupertinoButton(
                        key: const ValueKey<String>('manual-extension-button'),
                        onPressed: () {
                          extensionTapCount += 1;
                        },
                        child: const Text('Portrait Enhance'),
                      ),
                    ],
                  },
                  onModeSelected: (String mode) {
                    setState(() {
                      selectedMode = mode;
                    });
                  },
                  bottomControls: const SizedBox.shrink(),
                  reduceMotion: false,
                ),
              );
            },
          ),
        ),
      );
    }

    await pump();

    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('camera-photo-mode-indicator')),
      findsOneWidget,
    );
    expect(find.text('Portrait Enhance'), findsNothing);

    await tester.tap(find.text('MANUAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('camera-photo-mode-indicator')),
      findsOneWidget,
    );
    expect(find.text('Portrait Enhance'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('manual-extension-button')),
    );

    expect(extensionTapCount, 1);
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
