import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_option_button.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_overlay_panel.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_ui.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_models.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_tokens.dart';
import 'package:fantasy_camera_flutter/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  testWidgets('body layout overlays controls when bottom space is too small', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 623));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<CameraPhotoControlsPlacement> placements =
        <CameraPhotoControlsPlacement>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: CameraPhotoBodyLayout(
          tokens: const CameraUiTokens(),
          minimumBottomHeight: 134,
          compactBottomOverlayHeight: 0,
          viewfinder: const ColoredBox(
            key: ValueKey<String>('camera-test-viewfinder'),
            color: AppColors.black,
          ),
          controlsBuilder:
              (
                BuildContext context,
                CameraPhotoControlsPlacement resolvedPlacement,
              ) {
                placements.add(resolvedPlacement);
                return SizedBox(
                  key: ValueKey<String>(
                    'camera-test-controls-${resolvedPlacement.name}',
                  ),
                  height: 134,
                );
              },
        ),
      ),
    );

    expect(placements, <CameraPhotoControlsPlacement>[
      CameraPhotoControlsPlacement.heroOverlay,
      CameraPhotoControlsPlacement.bottomOverlay,
    ]);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-test-viewfinder')),
      ),
      const Size(375, 500),
    );
    expect(
      find.byKey(const ValueKey<String>('camera-test-controls-bottomOverlay')),
      findsOneWidget,
    );
  });

  testWidgets('body layout keeps hero 3:4 on short compact screens', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(899, 286));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<CameraPhotoControlsPlacement> placements =
        <CameraPhotoControlsPlacement>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: CameraPhotoBodyLayout(
          tokens: const CameraUiTokens(),
          minimumBottomHeight: 134,
          compactBottomOverlayHeight: 92,
          viewfinder: const ColoredBox(
            key: ValueKey<String>('camera-test-short-viewfinder'),
            color: AppColors.black,
          ),
          controlsBuilder:
              (
                BuildContext context,
                CameraPhotoControlsPlacement resolvedPlacement,
              ) {
                placements.add(resolvedPlacement);
                return SizedBox(
                  key: ValueKey<String>(
                    'camera-test-short-controls-${resolvedPlacement.name}',
                  ),
                  height: 134,
                );
              },
        ),
      ),
    );

    expect(placements, <CameraPhotoControlsPlacement>[
      CameraPhotoControlsPlacement.heroOverlay,
      CameraPhotoControlsPlacement.bottomOverlay,
    ]);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-test-short-viewfinder')),
      ),
      const Size(145.5, 194),
    );
  });

  testWidgets('compact overlay pins mode selector to hero bottom', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(899, 286));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const CupertinoApp(
        home: CameraPhotoUi(
          tokens: CameraUiTokens(),
          viewfinder: ColoredBox(color: AppColors.black),
          modes: <CameraUiMode>[
            CameraUiMode(id: 'general', label: 'AUTO'),
            CameraUiMode(id: 'portrait', label: 'MANUAL'),
          ],
          selectedModeId: 'general',
        ),
      ),
    );

    final Rect modeSelectorRect = tester.getRect(
      find.byType(CameraPhotoModeSelector),
    );
    final Rect heroRect = tester.getRect(find.byType(CameraPhotoViewfinder));
    final Rect bottomControlsRect = tester.getRect(
      find.byType(CameraPhotoBottomControls),
    );

    expect(modeSelectorRect.bottom, heroRect.bottom);
    expect(modeSelectorRect.bottom, lessThanOrEqualTo(bottomControlsRect.top));
  });

  testWidgets('compact overlay centers bottom controls in remaining space', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(899, 286));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const CupertinoApp(
        home: CameraPhotoUi(
          tokens: CameraUiTokens(),
          viewfinder: ColoredBox(color: AppColors.black),
          modes: <CameraUiMode>[
            CameraUiMode(id: 'general', label: 'AUTO'),
            CameraUiMode(id: 'portrait', label: 'MANUAL'),
          ],
          selectedModeId: 'general',
        ),
      ),
    );

    final Rect heroRect = tester.getRect(find.byType(CameraPhotoViewfinder));
    final Rect bottomControlsRect = tester.getRect(
      find.byType(CameraPhotoBottomControls),
    );
    final double remainingSpaceCenter =
        heroRect.bottom + (286 - heroRect.bottom) / 2;

    expect(bottomControlsRect.center.dy, remainingSpaceCenter);
  });

  testWidgets('compact overlay keeps zoom slider above mode selector', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(899, 286));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const CupertinoApp(
        home: CameraPhotoUi(
          tokens: CameraUiTokens(),
          viewfinder: ColoredBox(color: AppColors.black),
          modes: <CameraUiMode>[
            CameraUiMode(id: 'general', label: 'AUTO'),
            CameraUiMode(id: 'portrait', label: 'MANUAL'),
          ],
          selectedModeId: 'general',
          zoomStops: <CameraZoomStop>[
            CameraZoomStop(factor: 1, label: '1x'),
            CameraZoomStop(factor: 2, label: '2x'),
          ],
        ),
      ),
    );

    final Rect zoomRect = tester.getRect(find.byType(CameraPhotoZoomSlider));
    final Rect modeSelectorRect = tester.getRect(
      find.byType(CameraPhotoModeSelector),
    );

    expect(zoomRect.bottom, lessThanOrEqualTo(modeSelectorRect.top));
  });

  testWidgets('compact overlay expands manual options upward', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String selectedMode = 'general';

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CameraPhotoUi(
              tokens: const CameraUiTokens(),
              viewfinder: const ColoredBox(color: AppColors.black),
              modes: const <CameraUiMode>[
                CameraUiMode(id: 'general', label: 'AUTO'),
                CameraUiMode(id: 'portrait', label: 'MANUAL'),
              ],
              selectedModeId: selectedMode,
              modeExtensions: const <String, List<Widget>>{
                'portrait': <Widget>[
                  SizedBox(
                    key: ValueKey<String>('manual-extension-content'),
                    width: 64,
                    height: 32,
                  ),
                ],
              },
              onModeSelected: (String mode) {
                setState(() {
                  selectedMode = mode;
                });
              },
            );
          },
        ),
      ),
    );

    final Rect collapsedModeSelectorRect = tester.getRect(
      find.byType(CameraPhotoModeSelector),
    );
    final Rect collapsedBottomControlsRect = tester.getRect(
      find.byType(CameraPhotoBottomControls),
    );

    await tester.tap(find.text('MANUAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Rect expandedModeSelectorRect = tester.getRect(
      find.byType(CameraPhotoModeSelector),
    );
    final Rect expandedBottomControlsRect = tester.getRect(
      find.byType(CameraPhotoBottomControls),
    );

    expect(expandedModeSelectorRect.bottom, collapsedModeSelectorRect.bottom);
    expect(
      expandedModeSelectorRect.top,
      lessThan(collapsedModeSelectorRect.top),
    );
    expect(expandedBottomControlsRect, collapsedBottomControlsRect);
  });

  testWidgets('prompt option button background follows overlay translucency', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CameraPhotoOverlayPanel(
            enabled: true,
            child: CameraPhotoOptionButton(
              tokens: const CameraUiTokens(),
              label: 'Clean Frame',
              icon: LucideIcons.sparkles,
              selected: false,
              animationIndex: 0,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 220));

    final AnimatedContainer container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final ShapeDecoration decoration = container.decoration! as ShapeDecoration;

    expect(decoration.color!.a, lessThan(1));
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
