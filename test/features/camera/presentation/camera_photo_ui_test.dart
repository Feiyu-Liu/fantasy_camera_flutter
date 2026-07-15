import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_option_button.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_overlay_panel.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_ui.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_models.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_ui_tokens.dart';
import 'package:fantasy_camera_flutter/theme/app_colors.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('aspect ratio button reports taps and updates its label', (
    WidgetTester tester,
  ) async {
    String label = '4:3';
    int taps = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CameraPhotoTopBar(
              tokens: const CameraUiTokens(),
              controlsRotationTurns: 0.25,
              aspectRatioLabel: label,
              aspectRatioSemanticsLabel: 'Capture aspect ratio, $label',
              onAspectRatioPressed: () {
                setState(() {
                  taps += 1;
                  label = '1:1';
                });
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('4:3'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.bySemanticsLabel('Capture aspect ratio, 1:1'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('1:1'),
        matching: find.byType(AnimatedRotation),
      ),
      findsNothing,
    );
  });

  testWidgets('crop mask color follows the active app theme', (
    WidgetTester tester,
  ) async {
    late CameraUiTokens lightTokens;
    await tester.pumpWidget(
      CupertinoApp(
        home: AppThemeColorsScope(
          colors: AppThemeColors.light,
          child: Builder(
            builder: (BuildContext context) {
              lightTokens = CameraUiTokens.forTheme(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(lightTokens.captureCropMaskColor, AppColors.white);
    expect(lightTokens.captureCropMaskOpacity, 0.95);

    late CameraUiTokens darkTokens;
    await tester.pumpWidget(
      CupertinoApp(
        home: AppThemeColorsScope(
          colors: AppThemeColors.dark,
          child: Builder(
            builder: (BuildContext context) {
              darkTokens = CameraUiTokens.forTheme(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(darkTokens.captureCropMaskColor, AppColors.black);
    expect(darkTokens.captureCropMaskOpacity, 0.95);
  });

  testWidgets('square capture keeps the visible viewfinder at 3:4', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CupertinoApp(
        home: CameraPhotoBodyLayout(
          tokens: const CameraUiTokens(),
          viewfinderAspectRatio: 3 / 4,
          minimumBottomHeight: 92,
          viewfinder: const CameraPhotoViewfinder(
            tokens: CameraUiTokens(),
            captureCropAspectRatio: 1,
            viewfinder: ColoredBox(
              key: ValueKey<String>('camera-square-viewfinder'),
              color: AppColors.black,
            ),
          ),
          controlsBuilder:
              (BuildContext context, CameraPhotoControlsPlacement placement) =>
                  const SizedBox(height: 92),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-square-viewfinder')),
      ),
      const Size(375, 500),
    );
    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-mask')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('square crop rect is centered inside portrait and landscape frames', () {
    expect(
      cameraPhotoCropRectFor(size: const Size(300, 400), aspectRatio: 1),
      const Rect.fromLTWH(0, 50, 300, 300),
    );
    expect(
      cameraPhotoCropRectFor(size: const Size(400, 300), aspectRatio: 1),
      const Rect.fromLTWH(50, 0, 300, 300),
    );
    expect(
      cameraPhotoCropRectFor(size: const Size(300, 400), aspectRatio: 3 / 4),
      const Rect.fromLTWH(0, 0, 300, 400),
    );
    expect(
      cameraPhotoCropInsetsFor(
        size: const Size(300, 400),
        cropRect: const Rect.fromLTWH(0, 50, 300, 300),
      ),
      const EdgeInsets.only(top: 50, bottom: 50),
    );
    expect(
      cameraPhotoCropInsetsFor(
        size: const Size(300, 400),
        cropRect: const Rect.fromLTWH(37.5, 0, 225, 400),
      ),
      const EdgeInsets.symmetric(horizontal: 37.5),
    );
  });

  test('zoom pill tracks the bottom of a portrait crop', () {
    const Size size = Size(300, 400);
    const Rect squareCrop = Rect.fromLTWH(0, 50, 300, 300);

    expect(
      cameraPhotoZoomCropOffsetFor(
        size: size,
        cropRect: const Rect.fromLTWH(0, 0, 300, 400),
        downwardOffset: 12,
      ),
      12,
    );
    expect(
      cameraPhotoZoomCropOffsetFor(
        size: size,
        cropRect: squareCrop,
        downwardOffset: 12,
      ),
      -38,
    );
  });

  testWidgets('square capture keeps the zoom pill inside the preview bottom', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (BuildContext context) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
              child: Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: const CameraPhotoViewfinder(
                    tokens: CameraUiTokens(),
                    captureCropAspectRatio: 1,
                    zoomStops: <CameraZoomStop>[
                      CameraZoomStop(factor: 0.5, label: '.5x'),
                      CameraZoomStop(factor: 1, label: '1x'),
                      CameraZoomStop(factor: 2, label: '2x'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect viewfinderRect = tester.getRect(
      find.byType(CameraPhotoViewfinder),
    );
    final Rect zoomRect = tester.getRect(find.byType(CameraPhotoZoomSlider));

    expect(zoomRect.top, closeTo(viewfinderRect.top + 288, 0.01));
    expect(zoomRect.bottom, closeTo(viewfinderRect.top + 328, 0.01));
  });

  testWidgets('switching to square does not resize the viewfinder frame', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    double captureCropAspectRatio = 3 / 4;

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CameraPhotoBodyLayout(
              tokens: const CameraUiTokens(),
              viewfinderAspectRatio: 3 / 4,
              minimumBottomHeight: 92,
              viewfinder: CameraPhotoViewfinder(
                tokens: const CameraUiTokens(),
                captureCropAspectRatio: captureCropAspectRatio,
                viewfinder: const ColoredBox(
                  key: ValueKey<String>('camera-fixed-viewfinder'),
                  color: AppColors.black,
                ),
              ),
              controlsBuilder:
                  (
                    BuildContext context,
                    CameraPhotoControlsPlacement placement,
                  ) => CupertinoButton(
                    onPressed: () {
                      setState(() {
                        captureCropAspectRatio = 1;
                      });
                    },
                    child: const Text('Square'),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Size initialSize = tester.getSize(
      find.byKey(const ValueKey<String>('camera-fixed-viewfinder')),
    );
    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-mask')),
      findsNothing,
    );

    await tester.tap(find.text('Square'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('camera-capture-crop-curtain-top'),
            ),
          )
          .height,
      greaterThan(0),
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('camera-capture-crop-curtain-bottom'),
            ),
          )
          .height,
      greaterThan(0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-fixed-viewfinder')),
      ),
      initialSize,
    );
    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-mask')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-capture-crop-curtain-top')),
      ),
      const Size(375, 62.5),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('camera-capture-crop-curtain-bottom'),
        ),
      ),
      const Size(375, 62.5),
    );
  });

  testWidgets('landscape square crop uses synchronized side curtains', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: CameraPhotoCaptureCropOverlay(
              tokens: CameraUiTokens(),
              captureAspectRatio: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('camera-capture-crop-curtain-leading'),
        ),
      ),
      const Size(50, 300),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('camera-capture-crop-curtain-trailing'),
        ),
      ),
      const Size(50, 300),
    );
    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-curtain-top')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-curtain-bottom')),
      findsNothing,
    );
  });

  testWidgets('crop curtains respect the reduced-motion preference', (
    WidgetTester tester,
  ) async {
    double captureAspectRatio = 3 / 4;

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CameraPhotoCaptureCropOverlay(
                        tokens: const CameraUiTokens(),
                        captureAspectRatio: captureAspectRatio,
                      ),
                      CupertinoButton(
                        onPressed: () {
                          setState(() {
                            captureAspectRatio = 1;
                          });
                        },
                        child: const Text('Square'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Square'));
    await tester.pump();

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('camera-capture-crop-curtain-top')),
      ),
      const Size(300, 50),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('camera-capture-crop-curtain-bottom'),
        ),
      ),
      const Size(300, 50),
    );
  });

  testWidgets('crop mask does not intercept viewfinder taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    final Key previewKey = UniqueKey();

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GestureDetector(
                  key: previewKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    taps += 1;
                  },
                ),
                const CameraPhotoCaptureCropOverlay(
                  tokens: CameraUiTokens(),
                  captureAspectRatio: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('camera-capture-crop-mask')),
      findsOneWidget,
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(previewKey)) + const Offset(8, 8),
    );

    expect(taps, 1);
  });

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
    String selectedMode = 'auto';
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
                    CameraUiMode(id: 'auto', label: 'AUTO'),
                    CameraUiMode(id: 'manual', label: 'MANUAL'),
                  ],
                  selectedModeId: selectedMode,
                  modeExtensions: <String, List<Widget>>{
                    'manual': <Widget>[
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
            CameraUiMode(id: 'auto', label: 'AUTO'),
            CameraUiMode(id: 'manual', label: 'MANUAL'),
          ],
          selectedModeId: 'auto',
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
            CameraUiMode(id: 'auto', label: 'AUTO'),
            CameraUiMode(id: 'manual', label: 'MANUAL'),
          ],
          selectedModeId: 'auto',
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
            CameraUiMode(id: 'auto', label: 'AUTO'),
            CameraUiMode(id: 'manual', label: 'MANUAL'),
          ],
          selectedModeId: 'auto',
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

    String selectedMode = 'auto';

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CameraPhotoUi(
              tokens: const CameraUiTokens(),
              viewfinder: const ColoredBox(color: AppColors.black),
              modes: const <CameraUiMode>[
                CameraUiMode(id: 'auto', label: 'AUTO'),
                CameraUiMode(id: 'manual', label: 'MANUAL'),
              ],
              selectedModeId: selectedMode,
              modeExtensions: const <String, List<Widget>>{
                'manual': <Widget>[
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
