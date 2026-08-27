import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/app/app_router.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/credit_balance_cache_repository.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_redemption.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/feedback.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/prompt_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/background_r2_upload_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_original_file_store.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_record_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_image_mosaic_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_modal.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:fantasy_camera_flutter/theme/app_colors.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_ui/my_ui.dart';

const List<List<int>> _diagonalGridSquareSequence = <List<int>>[
  <int>[0],
  <int>[1],
  <int>[5],
  <int>[2],
  <int>[6],
  <int>[10],
  <int>[3],
  <int>[7],
  <int>[11],
  <int>[15],
  <int>[4],
  <int>[8],
  <int>[12],
  <int>[16],
  <int>[20],
  <int>[9],
  <int>[13],
  <int>[17],
  <int>[21],
  <int>[25],
  <int>[14],
  <int>[18],
  <int>[22],
  <int>[26],
  <int>[30],
  <int>[19],
  <int>[23],
  <int>[27],
  <int>[31],
  <int>[24],
  <int>[28],
  <int>[32],
  <int>[29],
  <int>[33],
  <int>[34],
];

const List<List<int>> _diamondGridSquareSequence = <List<int>>[
  <int>[17],
  <int>[12, 16, 18, 22],
  <int>[7, 11, 13, 15, 19, 21, 23, 27],
  <int>[2, 6, 8, 10, 14, 20, 24, 26, 28, 32],
  <int>[1, 3, 5, 9, 25, 29, 31, 33],
  <int>[0, 4, 30, 34],
];

void main() {
  testWidgets('modal shows captured photos with status icons', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
      _job(id: 'processing', status: GenerationSubmissionStatus.pollingTask),
      _job(id: 'completed', status: GenerationSubmissionStatus.completed),
      _job(id: 'failed', status: GenerationSubmissionStatus.failed),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-awaiting'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-processing'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-top-gradient-awaiting'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-bottom-gradient-awaiting',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
      findsOneWidget,
    );
    final Size cancelButtonSize = tester.getSize(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
    );
    final Size confirmButtonSize = tester.getSize(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    final Finder cancelVisual = find.byKey(
      const ValueKey<String>('generation-submission-cancel-visual-awaiting'),
    );
    final Finder removeButton = find.byKey(
      const ValueKey<String>('generation-submission-remove-failed'),
    );
    final Finder removeVisual = find.byKey(
      const ValueKey<String>('generation-submission-remove-visual-failed'),
    );
    expect(cancelButtonSize.height, 44);
    expect(tester.getSize(removeButton), const Size.square(44));
    expect(confirmButtonSize.height, 44);
    expect(tester.getSize(cancelVisual), const Size.square(24));
    expect(tester.getSize(removeVisual), const Size.square(24));
    final DecoratedBox cancelDecoration = tester.widget<DecoratedBox>(
      cancelVisual,
    );
    final DecoratedBox removeDecoration = tester.widget<DecoratedBox>(
      removeVisual,
    );
    final ShapeDecoration cancelShape =
        cancelDecoration.decoration as ShapeDecoration;
    final ShapeDecoration removeShape =
        removeDecoration.decoration as ShapeDecoration;
    expect(cancelShape.color, AppColors.blackOverlay(0.45));
    expect(removeShape.color, cancelShape.color);
    final Icon deleteIcon = tester.widget<Icon>(
      find.descendant(
        of: cancelVisual,
        matching: find.byIcon(LucideIcons.trash2),
      ),
    );
    final Icon removeIcon = tester.widget<Icon>(
      find.descendant(
        of: removeVisual,
        matching: find.byIcon(LucideIcons.trash2),
      ),
    );
    expect(deleteIcon.color, AppColors.danger);
    expect(removeIcon.color, deleteIcon.color);
    expect(
      find.descendant(of: removeVisual, matching: find.byIcon(LucideIcons.x)),
      findsNothing,
    );
    expect(find.text('删除'), findsNothing);
    final Rect thumbnailRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('generation-submission-photo-awaiting'),
      ),
    );
    final Rect cancelButtonRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
    );
    final Rect awaitingOverlayRect = tester.getRect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-awaiting-overlay-awaiting',
        ),
      ),
    );
    final Rect confirmButtonRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    final Rect removeButtonRect = tester.getRect(removeButton);
    final Rect failedImageRect = tester.getRect(
      find.byKey(const ValueKey<String>('generation-thumbnail-image-failed')),
    );
    expect(cancelButtonRect.left, awaitingOverlayRect.left);
    expect(cancelButtonRect.top, awaitingOverlayRect.top);
    expect(removeButtonRect.left, failedImageRect.left);
    expect(removeButtonRect.top, failedImageRect.top);
    expect(
      confirmButtonRect.center.dx,
      moreOrLessEquals(thumbnailRect.center.dx, epsilon: 0.01),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('generation-submission-cancel-awaiting'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>(
                  'generation-submission-confirm-awaiting',
                ),
              ),
            )
            .dy,
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-grid-square-processing'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-grid-square-completed'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-completed'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-status-failed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-retry-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-remove-failed')),
      findsOneWidget,
    );
  });

  testWidgets(
    'loading cards cycle through three branded mosaic animation variants',
    (WidgetTester tester) async {
      final _FakeGenerationImageMosaicRepository mosaicRepository =
          _FakeGenerationImageMosaicRepository(
            _testMosaic(const <Color>[
              Color(0xFFF4A6A6),
              Color(0xFFA6D8F4),
              Color(0xFFB9E6B3),
            ]),
          );
      final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
        _job(id: 'a', status: GenerationSubmissionStatus.pollingTask),
        _job(id: 'd', status: GenerationSubmissionStatus.uploading),
        _job(id: 'g', status: GenerationSubmissionStatus.processingResultImage),
        _job(id: 'j', status: GenerationSubmissionStatus.pollingTask),
      ];

      await _pumpModalHost(
        tester,
        _ModalHost(jobs: jobs, imageMosaicRepository: mosaicRepository),
      );
      await tester.pump();

      final Finder diamondGrid = find.byKey(
        const ValueKey<String>('generation-submission-grid-square-d'),
      );
      final Finder rowsEnhancedGrid = find.byKey(
        const ValueKey<String>('generation-submission-grid-square-g'),
      );
      final Finder diagonalGrid = find.byKey(
        const ValueKey<String>('generation-submission-grid-square-a'),
      );
      final Finder repeatedDiagonalGrid = find.byKey(
        const ValueKey<String>('generation-submission-grid-square-j'),
      );

      expect(diamondGrid, findsOneWidget);
      expect(rowsEnhancedGrid, findsOneWidget);
      expect(diagonalGrid, findsOneWidget);
      expect(repeatedDiagonalGrid, findsOneWidget);
      final GridSquareAnimation diamondEffect = tester
          .widget<GridSquareAnimation>(diamondGrid);
      final GridSquareAnimation rowsEnhancedEffect = tester
          .widget<GridSquareAnimation>(rowsEnhancedGrid);
      final GridSquareAnimation diagonalEffect = tester
          .widget<GridSquareAnimation>(diagonalGrid);
      final GridSquareAnimation repeatedDiagonalEffect = tester
          .widget<GridSquareAnimation>(repeatedDiagonalGrid);
      final List<GridSquareAnimation> effects = <GridSquareAnimation>[
        diagonalEffect,
        diamondEffect,
        rowsEnhancedEffect,
        repeatedDiagonalEffect,
      ];

      for (final GridSquareAnimation effect in effects) {
        expect(effect.rows, 7);
        expect(effect.columns, 5);
        expect(effect.rows, greaterThan(effect.columns));
        expect(effect.spacing, 2.173295454545453);
        expect(effect.borderRadius, 4);
        expect(effect.lightUpCurve, Curves.easeOutCubic);
        expect(effect.dimCurve, Curves.easeInCubic);
        expect(
          effect.baseColor,
          AppColors.accentYellow.withValues(
            alpha: generationImageMosaicBaseAlpha,
          ),
        );
        expect(effect.lightUpColor, AppColors.accentYellow);
        expect(effect.baseCellColors, hasLength(35));
        expect(effect.lightUpCellColors, hasLength(35));
        expect(
          effect.baseCellColors!.every(
            (Color color) => color.a == generationImageMosaicBaseAlpha,
          ),
          isTrue,
        );
        expect(
          effect.lightUpCellColors!.every((Color color) => color.a == 1),
          isTrue,
        );
        for (int index = 0; index < 35; index += 1) {
          expect(
            effect.baseCellColors![index].withValues(alpha: 1),
            effect.lightUpCellColors![index],
          );
        }
        expect(effect.enableGlow, isTrue);
        expect(effect.glowIntensity, 0.63);
      }

      expect(diagonalEffect.groupedSequence, _diagonalGridSquareSequence);
      expect(diagonalEffect.lightUpDuration, const Duration(milliseconds: 300));
      expect(diagonalEffect.dimDuration, const Duration(milliseconds: 1000));
      expect(diagonalEffect.staggerInterval, const Duration(milliseconds: 72));
      expect(
        diagonalEffect.groupLoopPauseDuration,
        const Duration(milliseconds: 150),
      );
      expect(
        repeatedDiagonalEffect.groupedSequence,
        _diagonalGridSquareSequence,
      );

      expect(diamondEffect.groupedSequence, _diamondGridSquareSequence);
      expect(diamondEffect.lightUpDuration, const Duration(milliseconds: 300));
      expect(diamondEffect.dimDuration, const Duration(milliseconds: 518));
      expect(diamondEffect.staggerInterval, const Duration(milliseconds: 118));
      expect(
        diamondEffect.groupLoopPauseDuration,
        const Duration(milliseconds: 243),
      );

      expect(rowsEnhancedEffect.groupedSequence, <List<int>>[
        for (int index = 0; index < 35; index += 1) <int>[index],
      ]);
      expect(
        rowsEnhancedEffect.lightUpDuration,
        const Duration(milliseconds: 300),
      );
      expect(
        rowsEnhancedEffect.dimDuration,
        const Duration(milliseconds: 1000),
      );
      expect(
        rowsEnhancedEffect.staggerInterval,
        const Duration(milliseconds: 72),
      );
      expect(
        rowsEnhancedEffect.groupLoopPauseDuration,
        const Duration(milliseconds: 570),
      );
      expect(find.byType(ShaderMask), findsNothing);
      expect(
        mosaicRepository.extractedRequests.map((request) => request.path),
        containsAll(jobs.map((GenerationSubmissionJob job) => job.imagePath)),
      );
      expect(
        mosaicRepository.extractedRequests.every(
          (request) => request.rows == 7 && request.columns == 5,
        ),
        isTrue,
      );
      final ColoredBox diamondBackground = tester.widget<ColoredBox>(
        find.byKey(
          const ValueKey<String>(
            'generation-submission-grid-square-background-d',
          ),
        ),
      );
      expect(diamondBackground.color, AppColors.white);
      final Finder diamondBack = find.byKey(
        const ValueKey<String>('generation-submission-grid-square-back-d'),
      );
      final Size backSize = tester.getSize(diamondBack);
      expect(
        tester.getSize(diamondGrid),
        Size(backSize.width - 16, backSize.height - 16),
      );
      expect(tester.getCenter(diamondGrid), tester.getCenter(diamondBack));
      expect(
        find.byKey(
          const ValueKey<String>(
            'generation-submission-grid-square-progress-d',
          ),
        ),
        findsOneWidget,
      );
      final Text progressText = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>(
            'generation-submission-grid-square-progress-d',
          ),
        ),
      );
      expect(progressText.style?.color, AppColors.black);
      expect(find.text('0%'), findsWidgets);
      expect(find.text('即将完成'), findsOneWidget);
    },
  );

  testWidgets('grid square animation assignment stays stable across status', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: <GenerationSubmissionJob>[
          _job(id: 'early', status: GenerationSubmissionStatus.uploading),
        ],
      ),
    );

    const ValueKey<String> animationKey = ValueKey<String>(
      'generation-submission-grid-square-early',
    );
    final GridSquareAnimation before = tester.widget<GridSquareAnimation>(
      find.byKey(animationKey),
    );

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'early',
        status: GenerationSubmissionStatus.processingResultImage,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    final GridSquareAnimation after = tester.widget<GridSquareAnimation>(
      find.byKey(animationKey),
    );
    expect(after.groupedSequence, before.groupedSequence);
    expect(after.lightUpDuration, before.lightUpDuration);
    expect(after.dimDuration, before.dimDuration);
    expect(after.staggerInterval, before.staggerInterval);
    expect(after.groupLoopPauseDuration, before.groupLoopPauseDuration);
  });

  testWidgets('legacy job without animation index falls back to diagonal', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: <GenerationSubmissionJob>[
          _job(id: 'first', status: GenerationSubmissionStatus.uploading),
          _job(id: 'legacy', status: GenerationSubmissionStatus.uploading),
        ],
      ),
    );

    const ValueKey<String> animationKey = ValueKey<String>(
      'generation-submission-grid-square-legacy',
    );
    final GridSquareAnimation persisted = tester.widget<GridSquareAnimation>(
      find.byKey(animationKey),
    );
    expect(persisted.groupedSequence, _diamondGridSquareSequence);

    await hostKey.currentState!.clearAnimationIndex('legacy');
    await tester.pump();
    await tester.pump();

    final GridSquareAnimation fallback = tester.widget<GridSquareAnimation>(
      find.byKey(animationKey),
    );
    expect(fallback.groupedSequence, _diagonalGridSquareSequence);
  });

  testWidgets('grid square follows the inherited ticker mode', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: <GenerationSubmissionJob>[
          _job(id: 'ticker-mode', status: GenerationSubmissionStatus.uploading),
        ],
      ),
    );

    final Finder grid = find.byKey(
      const ValueKey<String>('generation-submission-grid-square-ticker-mode'),
    );
    expect(TickerMode.valuesOf(tester.element(grid)).enabled, isTrue);

    hostKey.currentState!.setTickerModeEnabled(false);
    await tester.pump();
    expect(TickerMode.valuesOf(tester.element(grid)).enabled, isFalse);

    hostKey.currentState!.setTickerModeEnabled(true);
    await tester.pump();
    expect(TickerMode.valuesOf(tester.element(grid)).enabled, isTrue);
  });

  testWidgets('grid square reloads its mosaic when the image path changes', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final _FakeGenerationImageMosaicRepository mosaicRepository =
        _FakeGenerationImageMosaicRepository(
          _testMosaic(const <Color>[
            Color(0xFFF4A6A6),
            Color(0xFFA6D8F4),
            Color(0xFFB9E6B3),
          ]),
        );
    final String firstPath = _writeImageFile('mosaic-first').path;
    final String secondPath = _writeImageFile('mosaic-second').path;
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'mosaic-path',
            imagePath: firstPath,
            status: GenerationSubmissionStatus.uploading,
          ),
        ],
        imageMosaicRepository: mosaicRepository,
      ),
    );
    expect(
      mosaicRepository.extractedRequests.map((request) => request.path),
      <String>[firstPath],
    );

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'mosaic-path',
        imagePath: secondPath,
        status: GenerationSubmissionStatus.uploading,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(
      mosaicRepository.extractedRequests.map((request) => request.path),
      <String>[firstPath, secondPath],
    );
  });

  testWidgets('grid square keeps its fallback when mosaic extraction fails', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'mosaic-failure',
            status: GenerationSubmissionStatus.uploading,
          ),
        ],
        imageMosaicRepository: _FakeGenerationImageMosaicRepository(
          GenerationImageMosaic.fallback(rows: 7, columns: 5),
          failure: const FormatException('invalid mosaic'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-mosaic-failure',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generation progress advances at integer boundaries', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: <GenerationSubmissionJob>[
          _job(id: 'estimate', status: GenerationSubmissionStatus.pollingTask),
        ],
      ),
    );
    final Finder progress = find.byKey(
      const ValueKey<String>(
        'generation-submission-grid-square-progress-estimate',
      ),
    );

    expect(progress, findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('1%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);

    await tester.pump(const Duration(seconds: 34, milliseconds: 300));
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1%'), findsNothing);

    await tester.pump(const Duration(seconds: 34, milliseconds: 300));
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('50%'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('即将完成'), findsOneWidget);
    expect(find.text('99%'), findsNothing);
  });

  testWidgets('generation progress advances without resizing its card', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'polling', status: GenerationSubmissionStatus.pollingTask),
    ];

    await _pumpModalHost(tester, _ModalHost(key: hostKey, jobs: jobs));
    await tester.pump();

    final Finder card = find.byKey(
      const ValueKey<String>('generation-submission-flip-polling'),
    );
    final Size initialSize = tester.getSize(card);
    expect(find.text('0%'), findsOneWidget);

    // Polls update updatedAt, but the persisted generation attempt start remains
    // the only clock used by the estimate.
    for (int i = 0; i < 3; i++) {
      await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
        _job(
          id: 'polling',
          status: GenerationSubmissionStatus.pollingTask,
          updatedAt: DateTime.now(),
        ),
      ]);
      await tester.pump(const Duration(seconds: 10));
    }

    expect(tester.getSize(card), initialSize);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('generation progress survives thumbnail remounts', (
    WidgetTester tester,
  ) async {
    final DateTime startedAt = DateTime.now().subtract(
      const Duration(seconds: 35),
    );
    GenerationSubmissionJob job = _job(
      id: 'persisted-progress',
      status: GenerationSubmissionStatus.pollingTask,
      generationStartedAt: startedAt,
    );

    await _pumpModalHost(
      tester,
      _ModalHost(
        key: const ValueKey<String>('first-progress-host'),
        jobs: <GenerationSubmissionJob>[job],
      ),
    );
    final Finder firstProgress = find.byKey(
      const ValueKey<String>(
        'generation-submission-grid-square-progress-persisted-progress',
      ),
    );
    final Finder firstCard = find.byKey(
      const ValueKey<String>('generation-submission-flip-persisted-progress'),
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-persisted-progress',
        ),
      ),
      findsOneWidget,
    );
    final Size firstSize = tester.getSize(firstCard);
    expect(firstProgress, findsOneWidget);
    final int firstPercentage = _percentageFromText(
      tester.widget<Text>(firstProgress).data!,
    );
    expect(firstPercentage, greaterThanOrEqualTo(50));

    job = _job(
      id: 'persisted-progress',
      status: GenerationSubmissionStatus.pollingTask,
      generationStartedAt: startedAt,
    );
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: const ValueKey<String>('second-progress-host'),
        jobs: <GenerationSubmissionJob>[job],
      ),
    );
    final Finder secondCard = find.byKey(
      const ValueKey<String>('generation-submission-flip-persisted-progress'),
    );
    final Finder secondProgress = find.byKey(
      const ValueKey<String>(
        'generation-submission-grid-square-progress-persisted-progress',
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-persisted-progress',
        ),
      ),
      findsOneWidget,
    );
    final int secondPercentage = _percentageFromText(
      tester.widget<Text>(secondProgress).data!,
    );
    expect(tester.getSize(secondCard), firstSize);
    expect(secondPercentage, greaterThanOrEqualTo(firstPercentage));
    expect(secondPercentage, lessThanOrEqualTo(99));
  });

  testWidgets('completed keeps the grid square finishing label visible', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'completion',
            status: GenerationSubmissionStatus.completed,
            generationStartedAt: DateTime.now(),
          ),
        ],
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-progress-completion'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-grid-square-completion'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-completed'),
      ),
      findsNothing,
    );
    expect(find.text('即将完成'), findsOneWidget);
  });

  testWidgets('reduced motion shows static grid square progress immediately', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        disableAnimations: true,
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'reduced-motion',
            status: GenerationSubmissionStatus.pollingTask,
          ),
        ],
      ),
    );
    final Finder progress = find.byKey(
      const ValueKey<String>(
        'generation-submission-grid-square-progress-reduced-motion',
      ),
    );
    expect(progress, findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    final Finder grid = find.byKey(
      const ValueKey<String>(
        'generation-submission-grid-square-reduced-motion',
      ),
    );
    final GridSquareAnimation animation = tester.widget<GridSquareAnimation>(
      grid,
    );
    expect(animation.lightUpColor, AppColors.accentYellow);
    expect(TickerMode.valuesOf(tester.element(grid)).enabled, isFalse);

    await tester.pump(const Duration(seconds: 21));

    expect(find.text('30%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(TickerMode.valuesOf(tester.element(grid)).enabled, isFalse);
  });

  for (final Locale locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'generation progress fits thumbnail in ${locale.toLanguageTag()}',
      (WidgetTester tester) async {
        await _pumpModalHost(
          tester,
          _ModalHost(
            locale: locale,
            jobs: <GenerationSubmissionJob>[
              _job(
                id: 'localized-estimate',
                status: GenerationSubmissionStatus.completed,
                generationStartedAt: DateTime.now(),
              ),
            ],
          ),
          locale: locale,
        );

        final String finishingLabel = appLocalizationsFor(
          locale,
        ).generationSubmissionEstimatedFinishing;
        expect(find.text(finishingLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('thumbnail prompt badge reflects capture mode and switches', () {
    expect(
      generationThumbnailPromptBadgeLabel(
        selection: const PromptSelectionSnapshot(
          promptStyle: defaultPromptStyle,
          captureMode: defaultCaptureMode,
          switches: <String, bool>{},
        ),
        manualLabel: '手动',
      ),
      isNull,
    );
    expect(
      generationThumbnailPromptBadgeLabel(
        selection: const PromptSelectionSnapshot(
          promptStyle: defaultPromptStyle,
          captureMode: manualCaptureMode,
          switches: <String, bool>{
            'recompose': false,
            'beautifyFace': false,
            'cleanFrame': false,
            'backgroundBlur': false,
          },
        ),
        manualLabel: '手动',
      ),
      '手动',
    );
    expect(
      generationThumbnailPromptBadgeLabel(
        selection: const PromptSelectionSnapshot(
          promptStyle: defaultPromptStyle,
          captureMode: manualCaptureMode,
          switches: <String, bool>{
            'recompose': true,
            'beautifyFace': false,
            'cleanFrame': true,
            'backgroundBlur': false,
          },
        ),
        manualLabel: '手动',
      ),
      '+2',
    );
  });

  testWidgets('confirming awaiting photo starts generation', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(uploadRepository.createUploadCount, 1);
    expect(taskRepository.createTaskCount, 0);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-flip-awaiting')),
      findsOneWidget,
    );
    final FlipCard card = tester.widget<FlipCard>(
      find.byKey(const ValueKey<String>('generation-submission-flip-awaiting')),
    );
    expect(card.side, FlipCardSide.back);
  });

  testWidgets('real confirmation flips the card toward grid square', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'animated-confirm',
            status: GenerationSubmissionStatus.awaitingConfirmation,
          ),
        ],
        guideRepository: _FakeGenerationSubmissionGuideRepository(seen: true),
        uploadRepository: _FakeUploadRepository(),
        taskRepository: _FakeGenerationTaskRepository(),
      ),
    );

    final Finder cardFinder = find.byKey(
      const ValueKey<String>('generation-submission-flip-animated-confirm'),
    );
    final FlipCardController cardController = tester
        .widget<FlipCard>(cardFinder)
        .controller;
    expect(
      tester.widget<FlipCard>(cardFinder).animationDuration,
      const Duration(milliseconds: 800),
    );
    expect(cardController.state!.animationController.value, 0);

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-confirm-animated-confirm',
        ),
      ),
    );
    for (int attempt = 0; attempt < 10; attempt += 1) {
      await tester.pump();
      if (tester.widget<FlipCard>(cardFinder).side == FlipCardSide.back) {
        break;
      }
    }

    expect(tester.widget<FlipCard>(cardFinder).side, FlipCardSide.back);
    expect(cardController.state!.animationController.value, 0);

    await tester.pump(const Duration(milliseconds: 80));

    expect(
      cardController.state!.animationController.value,
      inExclusiveRange(0, 0.5),
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-confirm-animated-confirm',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-estimate-animated-confirm',
        ),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-reveal-animated-confirm',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-animated-confirm',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey<String>(
                'generation-submission-grid-square-reveal-animated-confirm',
              ),
            ),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 380));
    await tester.pump(const Duration(milliseconds: 999));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey<String>(
                'generation-submission-grid-square-reveal-animated-confirm',
              ),
            ),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey<String>(
                'generation-submission-grid-square-reveal-animated-confirm',
              ),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('guided confirmation also flips toward grid square', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'guided-animated-confirm',
            status: GenerationSubmissionStatus.awaitingConfirmation,
          ),
        ],
        guideRepository: _FakeGenerationSubmissionGuideRepository(seen: false),
        uploadRepository: _FakeUploadRepository(),
        taskRepository: _FakeGenerationTaskRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    final Finder cardFinder = find.byKey(
      const ValueKey<String>(
        'generation-submission-flip-guided-animated-confirm',
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-confirm-guided-animated-confirm',
        ),
      ),
    );
    for (int attempt = 0; attempt < 10; attempt += 1) {
      await tester.pump();
      if (tester.widget<FlipCard>(cardFinder).side == FlipCardSide.back) {
        break;
      }
    }

    expect(tester.widget<FlipCard>(cardFinder).side, FlipCardSide.back);
    await tester.pump(const Duration(milliseconds: 860));
    await tester.pump();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey<String>(
                'generation-submission-grid-square-reveal-guided-animated-confirm',
              ),
            ),
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(
              const ValueKey<String>(
                'generation-submission-grid-square-reveal-guided-animated-confirm',
              ),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('real loading job flips back to its retry controls', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: <GenerationSubmissionJob>[
          _job(
            id: 'real-retry-transition',
            status: GenerationSubmissionStatus.pollingTask,
            generationStartedAt: DateTime.now(),
          ),
        ],
      ),
    );

    final Finder cardFinder = find.byKey(
      const ValueKey<String>(
        'generation-submission-flip-real-retry-transition',
      ),
    );
    final FlipCardController cardController = tester
        .widget<FlipCard>(cardFinder)
        .controller;
    expect(cardController.state!.animationController.value, 1);
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-grid-square-real-retry-transition',
        ),
      ),
      findsOneWidget,
    );

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'real-retry-transition',
        status: GenerationSubmissionStatus.failed,
        generationStartedAt: DateTime.now(),
      ),
    ]);
    for (int attempt = 0; attempt < 10; attempt += 1) {
      await tester.pump();
      if (tester.widget<FlipCard>(cardFinder).side == FlipCardSide.front) {
        break;
      }
    }

    expect(tester.widget<FlipCard>(cardFinder).side, FlipCardSide.front);
    expect(cardController.state!.animationController.value, 1);

    await tester.pump(const Duration(milliseconds: 60));

    expect(
      cardController.state!.animationController.value,
      inExclusiveRange(0.5, 1),
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-retry-real-retry-transition',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('confirmation guide appears above first awaiting thumbnail', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationSubmissionGuideRepository guideRepository =
        _FakeGenerationSubmissionGuideRepository(seen: false);
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(jobs: jobs, guideRepository: guideRepository),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    final Finder message = find.byKey(
      const ValueKey<String>(
        'generation-submission-confirmation-guide-message',
      ),
    );
    final Finder thumbnail = find.byKey(
      const ValueKey<String>('generation-submission-photo-awaiting'),
    );
    expect(message, findsOneWidget);
    expect(
      find.text('每张照片优化将消耗2积分，确认后需要等待约1分钟。期间你可以退出app，完成后会通过通知提醒'),
      findsOneWidget,
    );
    expect(
      tester.getRect(message).bottom,
      lessThan(tester.getRect(thumbnail).top),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-confirmation-guide-dismiss',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(guideRepository.seen, isTrue);
    expect(message, findsNothing);
  });

  testWidgets('confirmation guide stays hidden after it has been seen', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        guideRepository: _FakeGenerationSubmissionGuideRepository(seen: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-confirmation-guide-message',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('confirmation guide is marked seen when confirming photo', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationSubmissionGuideRepository guideRepository =
        _FakeGenerationSubmissionGuideRepository(seen: false);
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(jobs: jobs, guideRepository: guideRepository),
    );
    await tester.pump(const Duration(milliseconds: 320));

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    await tester.pump();

    expect(guideRepository.seen, isTrue);
  });

  testWidgets('insufficient credits opens paywall before upload', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
        creditBalance: 0,
        enableRouter: true,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
    expect(
      find.byKey(const ValueKey<String>('test-credit-purchase-page')),
      findsOneWidget,
    );
  });

  testWidgets('backend insufficient credits fallback opens paywall', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository(
      createUploadFailure: const BackendApiFailure(
        code: 'insufficient_credits',
        message: 'Insufficient credits',
      ),
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
        creditBalanceFailure: StateError('balance unavailable'),
        enableRouter: true,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    for (int index = 0; index < 20; index += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(const ValueKey<String>('test-credit-purchase-page'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(uploadRepository.createUploadCount, 1);
    expect(taskRepository.createTaskCount, 0);
    expect(
      find.byKey(const ValueKey<String>('test-credit-purchase-page')),
      findsOneWidget,
    );
  });

  testWidgets('canceling awaiting photo removes it from the list', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-photo-awaiting'),
      ),
      findsNothing,
    );
    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
  });

  testWidgets('tapping failed thumbnail retry restarts generation', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'failed', status: GenerationSubmissionStatus.failed),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-retry-failed')),
    );
    await tester.pump();
    await tester.pump();

    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-estimate-failed'),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<FlipCard>(
            find.byKey(
              const ValueKey<String>('generation-submission-flip-failed'),
            ),
          )
          .side,
      FlipCardSide.back,
    );
  });

  testWidgets('tapping failed thumbnail remove deletes the job', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'failed', status: GenerationSubmissionStatus.failed),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-remove-failed')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-failed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-retry-failed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-remove-failed')),
      findsNothing,
    );
  });

  testWidgets('modal shows gallery picker when no jobs exist', (
    WidgetTester tester,
  ) async {
    await _pumpModalHost(
      tester,
      const _ModalHost(jobs: <GenerationSubmissionJob>[]),
    );

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
    expect(find.text('No captured photos yet'), findsNothing);
  });

  testWidgets('gallery uses dark theme colors', (WidgetTester tester) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'dark', status: GenerationSubmissionStatus.awaitingConfirmation),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(jobs: jobs, themePreference: AppThemePreference.dark),
    );

    final DecoratedBox stripBox = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('generation-submission-photo-list'),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final BoxDecoration stripDecoration = stripBox.decoration as BoxDecoration;
    expect(stripDecoration.color, AppThemeColors.dark.background);

    final Container pickerTile = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('generation-submission-gallery-picker'),
            ),
            matching: find.bySubtype<Container>(),
          )
          .first,
    );
    final ShapeDecoration pickerDecoration =
        pickerTile.decoration! as ShapeDecoration;
    expect(pickerDecoration.color, AppThemeColors.dark.surface);
    expect(
      (pickerDecoration.shape as OutlinedBorder).side.color,
      AppThemeColors.dark.border,
    );

    final Container thumbnail = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('generation-submission-photo-dark'),
            ),
            matching: find.bySubtype<Container>(),
          )
          .first,
    );
    final ShapeDecoration thumbnailDecoration =
        thumbnail.decoration! as ShapeDecoration;
    expect(
      (thumbnailDecoration.shape as OutlinedBorder).side.color,
      AppThemeColors.dark.accentYellow,
    );
  });

  testWidgets('modal shows thumbnail fallback when original file is missing', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'missing',
        status: GenerationSubmissionStatus.awaitingConfirmation,
        imagePath: '/tmp/does-not-exist.heic',
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-missing')),
      findsOneWidget,
    );
  });

  testWidgets('hero toolbar is present but disabled before result exists', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'pending', status: GenerationSubmissionStatus.pollingTask),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-settings'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsNothing,
    );
  });

  testWidgets('awaiting hero toolbar opens prompt settings', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting-prompt',
        status: GenerationSubmissionStatus.awaitingConfirmation,
        promptSelection: const PromptSelectionSnapshot(
          promptStyle: defaultPromptStyle,
          captureMode: defaultCaptureMode,
          switches: <String, bool>{},
        ),
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-settings'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-settings'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-prompt-mode-manual')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey<String>('generation-prompt-option-recompose')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-awaiting-prompt'),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('+4'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-prompt-option-recompose')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('+3'), findsNothing);
  });

  testWidgets('prompt settings collapse when tapping hero outside toolbar', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting-prompt-collapse',
        status: GenerationSubmissionStatus.awaitingConfirmation,
        promptSelection: const PromptSelectionSnapshot(
          promptStyle: defaultPromptStyle,
          captureMode: defaultCaptureMode,
          switches: <String, bool>{},
        ),
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-settings'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));
    _expectDismissLayerEnabled(tester, true);

    final Rect heroRect = tester.getRect(
      find.byKey(const ValueKey<String>('generation-gallery-hero-pager')),
    );
    await tester.tapAt(Offset(heroRect.center.dx, heroRect.top + 24));
    await tester.pump(const Duration(milliseconds: 360));

    _expectDismissLayerEnabled(tester, false);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-prompt-settings'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('completed result url keeps hero on original before local save', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final File processedFile = _writeImageFile('processed-done-result');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'pending', status: GenerationSubmissionStatus.pollingTask),
      _job(
        id: 'done',
        status: GenerationSubmissionStatus.completed,
        taskId: 'task-done',
      ),
    ];

    await _pumpModalHost(
      tester,
      _ModalHost(key: hostKey, jobs: jobs, taskRepository: taskRepository),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-photo-done')),
    );
    await tester.pump();
    await tester.pump();

    expect(taskRepository.resultUrlTaskIds, isEmpty);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsNothing,
    );
    expect(find.byType(BlurredImageSwapTransition), findsNothing);

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(id: 'pending', status: GenerationSubmissionStatus.pollingTask),
      _job(
        id: 'done',
        status: GenerationSubmissionStatus.resultSaved,
        imagePath: jobs[1].imagePath,
        taskId: 'task-done',
        processedResultPath: processedFile.path,
      ),
    ]);
    for (int i = 0; i < 10; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(BlurredImageSwapTransition).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(BlurredImageSwapTransition), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsNothing,
    );
  });

  testWidgets('saved result photo shows processed local image', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-result');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'saved',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-processed-result-image'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'missing saved result shows result load failure instead of original',
    (WidgetTester tester) async {
      final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
        _job(
          id: 'missing-saved-result',
          status: GenerationSubmissionStatus.resultSaved,
          resultAvailability: GenerationRecordResultAvailability.missing,
        ),
      ];

      await _pumpModalHost(tester, _ModalHost(jobs: jobs));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('generation-gallery-hero-failure')),
        findsOneWidget,
      );
      expect(find.text('处理后的结果图无法加载'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('generation-submission-original-image'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('generation-submission-image-toggle'),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('generation-submission-original-image'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('saved result thumbnail directly shows processed image', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-thumbnail-result');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'saved-thumbnail',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(
      find.byKey(
        const ValueKey<String>('generation-thumbnail-swap-saved-thumbnail'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-thumbnail-image-saved-thumbnail'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hero animates only when selected result first arrives', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'arriving', status: GenerationSubmissionStatus.pollingTask),
    ];
    final File processedFile = _writeImageFile('processed-arriving-result');

    await _pumpModalHost(tester, _ModalHost(key: hostKey, jobs: jobs));

    expect(find.byType(BlurredImageSwapTransition), findsNothing);

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'arriving',
        status: GenerationSubmissionStatus.resultSaved,
        imagePath: jobs.single.imagePath,
        processedResultPath: processedFile.path,
      ),
    ]);
    for (int i = 0; i < 10; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(BlurredImageSwapTransition).evaluate().isNotEmpty) {
        break;
      }
    }

    final BlurredImageSwapTransition transition = tester.widget(
      find.byType(BlurredImageSwapTransition),
    );
    expect(transition.showReplacement, isTrue);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(BlurredImageSwapTransition), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-processed-result-image'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();
    expect(find.byType(BlurredImageSwapTransition), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();
    expect(find.byType(BlurredImageSwapTransition), findsNothing);
  });

  testWidgets(
    'hero does not animate for completed result url before local save',
    (WidgetTester tester) async {
      final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
      final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
        _job(
          id: 'arriving-url',
          status: GenerationSubmissionStatus.pollingTask,
        ),
      ];

      await _pumpModalHost(tester, _ModalHost(key: hostKey, jobs: jobs));

      await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
        _job(
          id: 'arriving-url',
          status: GenerationSubmissionStatus.completed,
          imagePath: jobs.single.imagePath,
          resultUrl: 'https://example.com/result.jpg',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BlurredImageSwapTransition), findsNothing);
    },
  );

  testWidgets('hero holds original until saved result is precached', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final Completer<bool> precacheCompleter = Completer<bool>();
    final List<ImageProvider> precachedImages = <ImageProvider>[];
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'precache', status: GenerationSubmissionStatus.pollingTask),
    ];
    final File processedFile = _writeImageFile('processed-precache-result');

    await _pumpModalHost(
      tester,
      _ModalHost(
        key: hostKey,
        jobs: jobs,
        heroImagePrecache: (ImageProvider imageProvider) {
          precachedImages.add(imageProvider);
          return precacheCompleter.future;
        },
      ),
    );

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'precache',
        status: GenerationSubmissionStatus.resultSaved,
        imagePath: jobs.single.imagePath,
        processedResultPath: processedFile.path,
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(BlurredImageSwapTransition), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-thumbnail-image-precache')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-grid-square-precache'),
      ),
      findsOneWidget,
    );
    expect(precachedImages, hasLength(2));

    precacheCompleter.complete(true);
    await tester.pump();

    expect(find.byType(BlurredImageSwapTransition), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 720));
    expect(
      find.byKey(const ValueKey<String>('generation-thumbnail-image-precache')),
      findsOneWidget,
    );
  });

  testWidgets('hero keeps original before local result can animate', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'published', status: GenerationSubmissionStatus.pollingTask),
    ];
    final File processedFile = _writeImageFile('processed-published-result');

    await _pumpModalHost(tester, _ModalHost(key: hostKey, jobs: jobs));

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'published',
        status: GenerationSubmissionStatus.completed,
        imagePath: jobs.single.imagePath,
        taskId: 'task-published',
      ),
    ]);
    await tester.pump();

    expect(find.byType(BlurredImageSwapTransition), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'published',
        status: GenerationSubmissionStatus.resultSaved,
        imagePath: jobs.single.imagePath,
        processedResultPath: processedFile.path,
      ),
    ]);
    for (int i = 0; i < 10; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(BlurredImageSwapTransition).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(BlurredImageSwapTransition), findsOneWidget);
  });

  testWidgets('saved result photo toggle switches to original image', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-toggle-result');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'saved-toggle',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-processed-result-image'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('result processing failure keeps error text off hero', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'failed-result',
        status: GenerationSubmissionStatus.resultProcessingFailed,
        resultSaveErrorMessage: 'HEIF conversion failed',
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    expect(find.text('HEIF conversion failed'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-retry-failed-result'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hero more actions expand inside toolbar', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-more-actions');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'more-actions',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('在相册中查看'), findsOneWidget);
    expect(find.text('保存原始照片'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('不喜欢这张图片'), findsOneWidget);
    expect(find.text('移除'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-more-dismiss-layer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hero more actions collapse when tapping outside', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-more-collapse');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'more-collapse',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('在相册中查看'), findsOneWidget);

    _expectDismissLayerEnabled(tester, true);
    final Rect dismissRect = tester.getRect(_dismissLayerFinder());
    await tester.tapAt(Offset(dismissRect.left + 8, dismissRect.top + 8));
    await tester.pump(const Duration(milliseconds: 360));

    _expectDismissLayerEnabled(tester, false);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
      findsOneWidget,
    );
  });

  testWidgets('hero more actions stay expanded across parent rebuilds', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-more-rebuild');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'more-rebuild',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];
    final GlobalKey<_ModalHostState> hostKey = GlobalKey<_ModalHostState>();

    await _pumpModalHost(tester, _ModalHost(key: hostKey, jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('在相册中查看'), findsOneWidget);

    await hostKey.currentState!.replaceJobs(<GenerationSubmissionJob>[
      _job(
        id: 'more-rebuild',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('在相册中查看'), findsOneWidget);
    _expectDismissLayerEnabled(tester, true);
  });

  testWidgets('more action opens photo library', (WidgetTester tester) async {
    final File processedFile = _writeImageFile('processed-open-library');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'open-library',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _tapExpandedMoreAction(tester, 0);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(_FakePhotoLibraryAssetStore.openPhotoLibraryCount, 1);
  });

  testWidgets('more action saves camera original to photo library', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'save-original',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _tapExpandedMoreAction(tester, 1);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(_FakePhotoLibraryAssetStore.librarySavePaths, hasLength(1));
    expect(
      _FakePhotoLibraryAssetStore.librarySaveFileNames.single,
      startsWith('TesserCam-Original-save-original.'),
    );
  });

  testWidgets('more action asks for dislike reason and submits feedback', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-dislike');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'dislike',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _tapExpandedMoreAction(tester, 3);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(_FakeFeedbackRepository.inputs, isEmpty);
    expect(find.text('这张不太满意？'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('generation-submission-dislike-note')),
      '  人脸不像本人  ',
    );
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(_FakeFeedbackRepository.inputs, hasLength(1));
    expect(
      _FakeFeedbackRepository.inputs.single.rating,
      FeedbackRating.negative,
    );
    expect(_FakeFeedbackRepository.inputs.single.tags, <String>[
      'dislike_result',
    ]);
    expect(_FakeFeedbackRepository.inputs.single.note, '人脸不像本人');
  });

  testWidgets('more action submits negative feedback with empty note', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-dislike-empty');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'dislike-empty',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _tapExpandedMoreAction(tester, 3);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(_FakeFeedbackRepository.inputs, hasLength(1));
    expect(
      _FakeFeedbackRepository.inputs.single.rating,
      FeedbackRating.negative,
    );
    expect(_FakeFeedbackRepository.inputs.single.note, isNull);
  });

  testWidgets('more action cancels dislike feedback without submitting', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-dislike-cancel');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'dislike-cancel',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _tapExpandedMoreAction(tester, 3);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(_FakeFeedbackRepository.inputs, isEmpty);
  });

  testWidgets('submitted negative feedback disables dislike action', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-dislike-submitted');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'dislike-submitted',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
        resultNegativeFeedbackSubmittedAt: DateTime.parse(
          '2026-05-29T00:10:00Z',
        ),
      ),
    ];

    await _pumpModalHost(tester, _ModalHost(jobs: jobs));

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-more-actions')),
    );
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('已提交反馈'), findsOneWidget);

    await _tapExpandedMoreAction(tester, 3);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(find.text('这张不太满意？'), findsNothing);
    expect(_FakeFeedbackRepository.inputs, isEmpty);
  });

  testWidgets(
    'more action removes record from gallery without deleting asset',
    (WidgetTester tester) async {
      final File processedFile = _writeImageFile('processed-remove');
      final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
        _job(
          id: 'remove',
          status: GenerationSubmissionStatus.resultSaved,
          processedResultPath: processedFile.path,
        ),
      ];

      await _pumpModalHost(tester, _ModalHost(jobs: jobs));

      expect(
        find.byKey(
          const ValueKey<String>('generation-submission-photo-remove'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('generation-submission-more-actions'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 320));
      await _tapExpandedMoreAction(tester, 4);
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('generation-submission-photo-remove'),
        ),
        findsNothing,
      );
      expect(_FakePhotoLibraryAssetStore.deletedAssetIds, isEmpty);
    },
  );

  testWidgets('tapping gallery picker queues selected image for confirmation', (
    WidgetTester tester,
  ) async {
    final File imageFile = _writeImageFile('gallery-picked');
    final _FakeGalleryImagePicker imagePicker = _FakeGalleryImagePicker(
      XFile(imageFile.path),
    );
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: const <GenerationSubmissionJob>[],
        imagePicker: imagePicker,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
    );
    for (int i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (_confirmButtonFinder().evaluate().isNotEmpty) {
        break;
      }
    }

    expect(imagePicker.pickCount, 1);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-list')),
      findsOneWidget,
    );
    expect(_confirmButtonFinder(), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsNothing,
    );
    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
  });

  testWidgets('canceling gallery picker does not submit image', (
    WidgetTester tester,
  ) async {
    final _FakeGalleryImagePicker imagePicker = _FakeGalleryImagePicker(null);

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: const <GenerationSubmissionJob>[],
        imagePicker: imagePicker,
        uploadRepository: _FakeUploadRepository(),
        taskRepository: _FakeGenerationTaskRepository(),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(imagePicker.pickCount, 1);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsNothing,
    );
  });

  testWidgets('gallery picker shows iCloud export progress dialog', (
    WidgetTester tester,
  ) async {
    final File imageFile = _writeImageFile('gallery-icloud-picked');
    final _FakeGalleryImagePicker imagePicker = _FakeGalleryImagePicker(
      XFile(imageFile.path),
      waitForCompletion: true,
    );
    addTearDown(imagePicker.dispose);

    await _pumpModalHost(
      tester,
      _ModalHost(
        jobs: const <GenerationSubmissionJob>[],
        imagePicker: imagePicker,
        uploadRepository: _FakeUploadRepository(),
        taskRepository: _FakeGenerationTaskRepository(),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
    );
    await tester.pump();

    imagePicker.emitProgress(0.4);
    await tester.pump();

    expect(find.text('正在从 iCloud 下载'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('generation-gallery-export-progress-bar'),
      ),
      findsOneWidget,
    );

    imagePicker.completePick();
    await imagePicker.pickFinished;
    for (int i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('正在从 iCloud 下载').evaluate().isEmpty &&
          _confirmButtonFinder().evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('正在从 iCloud 下载'), findsNothing);
    expect(_confirmButtonFinder(), findsOneWidget);
  });
}

Finder _confirmButtonFinder() {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return widget is GestureDetector &&
        key is ValueKey<String> &&
        key.value.startsWith('generation-submission-confirm-');
  });
}

Future<void> _pumpModalHost(
  WidgetTester tester,
  _ModalHost host, {
  Locale locale = defaultAppLocale,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  });
  if (host.enableRouter) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => host,
        ),
        GoRoute(
          path: creditPurchaseRoute,
          builder: (BuildContext context, GoRouterState state) {
            return const CupertinoPageScaffold(
              child: Center(
                child: SizedBox(
                  key: ValueKey<String>('test-credit-purchase-page'),
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      CupertinoApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  } else {
    await tester.pumpWidget(
      CupertinoApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: host,
      ),
    );
  }
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Finder _dismissLayerFinder() {
  return find.byKey(
    const ValueKey<String>('generation-submission-more-dismiss-layer'),
  );
}

void _expectDismissLayerEnabled(WidgetTester tester, bool enabled) {
  expect(_dismissLayerFinder(), findsOneWidget);
  final Finder ignorePointerFinder = find.ancestor(
    of: _dismissLayerFinder(),
    matching: find.byType(IgnorePointer),
  );
  final IgnorePointer ignorePointer = tester.widget<IgnorePointer>(
    ignorePointerFinder.first,
  );
  expect(ignorePointer.ignoring, !enabled);
}

Future<void> _tapExpandedMoreAction(WidgetTester tester, int index) async {
  const List<String> actionKeys = <String>[
    'viewInAlbum',
    'saveOriginal',
    'retry',
    'dislike',
    'remove',
  ];
  final Finder action = find.byKey(
    ValueKey<String>('generation-submission-more-${actionKeys[index]}'),
  );
  final Finder hitRegion = find.byKey(
    const ValueKey<String>('generation-submission-more-hit-region'),
  );
  final double requiredHeight = 10 + (index + 1) * 42;
  for (int attempt = 0; attempt < 10; attempt += 1) {
    final bool actionExists = action.evaluate().isNotEmpty;
    final bool hasRoom =
        hitRegion.evaluate().isNotEmpty &&
        tester.getRect(hitRegion).height >= requiredHeight;
    if (actionExists && hasRoom) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(action, findsOneWidget);
  expect(
    tester.getRect(hitRegion).height,
    greaterThanOrEqualTo(requiredHeight),
  );
  await tester.tap(action);
}

class _ModalHost extends StatefulWidget {
  const _ModalHost({
    super.key,
    required this.jobs,
    this.themePreference = AppThemePreference.light,
    this.imagePicker,
    this.heroImagePrecache,
    this.imageMosaicRepository,
    this.uploadRepository,
    this.taskRepository,
    this.guideRepository,
    this.creditBalance = 99,
    this.creditBalanceFailure,
    this.enableRouter = false,
    this.disableAnimations = false,
    this.locale = defaultAppLocale,
  });

  final List<GenerationSubmissionJob> jobs;
  final AppThemePreference themePreference;
  final _FakeGalleryImagePicker? imagePicker;
  final HeroImagePrecache? heroImagePrecache;
  final GenerationImageMosaicRepository? imageMosaicRepository;
  final _FakeUploadRepository? uploadRepository;
  final _FakeGenerationTaskRepository? taskRepository;
  final _FakeGenerationSubmissionGuideRepository? guideRepository;
  final int creditBalance;
  final Object? creditBalanceFailure;
  final bool enableRouter;
  final bool disableAnimations;
  final Locale locale;

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
  bool _tickerModeEnabled = true;
  late final GenerationRecordDatabase _database =
      GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
  late final StreamController<List<GenerationRecord>> _recordsController =
      StreamController<List<GenerationRecord>>.broadcast();
  late final _NotifyingGenerationRecordRepository _recordRepository =
      _NotifyingGenerationRecordRepository(_database, _recordsController);
  late final Future<List<GenerationRecord>> _seedFuture = _seedRecords();

  Future<List<GenerationRecord>> _seedRecords() async {
    _FakePhotoLibraryAssetStore.resultPaths.clear();
    _FakePhotoLibraryAssetStore.librarySavePaths.clear();
    _FakePhotoLibraryAssetStore.librarySaveFileNames.clear();
    _FakePhotoLibraryAssetStore.deletedAssetIds.clear();
    _FakePhotoLibraryAssetStore.openPhotoLibraryCount = 0;
    _FakeFeedbackRepository.inputs.clear();
    await _seedJobs(widget.jobs, _recordRepository);
    return _recordRepository.listRecords();
  }

  Future<void> replaceJobs(List<GenerationSubmissionJob> jobs) async {
    await _recordRepository.replaceJobs(jobs);
  }

  Future<void> clearAnimationIndex(String recordId) {
    return _recordRepository.clearAnimationIndex(recordId);
  }

  void setTickerModeEnabled(bool enabled) {
    setState(() => _tickerModeEnabled = enabled);
  }

  @override
  void dispose() {
    _recordsController.close();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget page = CupertinoPageScaffold(
      child: _SeededModal(seedFuture: _seedFuture),
    );
    if (widget.disableAnimations) {
      page = MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: page,
      );
    }
    page = TickerMode(enabled: _tickerModeEnabled, child: page);
    final bool useExplicitTheme =
        widget.themePreference != AppThemePreference.light;
    return AppToastHost(
      child: ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'alex@example.com'),
              ),
            ),
          ),
          creditsRepositoryProvider.overrideWithValue(
            _FakeCreditsRepository(
              widget.creditBalance,
              failure: widget.creditBalanceFailure,
            ),
          ),
          creditBalanceCacheRepositoryProvider.overrideWithValue(
            _FakeCreditBalanceCacheRepository(),
          ),
          generationRecordDatabaseProvider.overrideWithValue(_database),
          generationRecordRepositoryProvider.overrideWithValue(
            _recordRepository,
          ),
          appToastPresenterProvider.overrideWithValue(_NoopAppToastPresenter()),
          galleryResumeActiveRecordsOnOpenProvider.overrideWithValue(false),
          generationSubmissionGuideRepositoryProvider.overrideWithValue(
            widget.guideRepository ??
                _FakeGenerationSubmissionGuideRepository(seen: true),
          ),
          generationRecordsProvider.overrideWith((Ref ref) {
            return (() async* {
              yield await _seedFuture;
              yield* _recordsController.stream;
            })();
          }),
          generationImageProcessorProvider.overrideWithValue(
            const _FakeGenerationImageProcessor(),
          ),
          generationOriginalFileStoreProvider.overrideWithValue(
            const _FakeGenerationOriginalFileStore(),
          ),
          galleryImagePickerProvider.overrideWithValue(
            widget.imagePicker ?? _FakeGalleryImagePicker(null),
          ),
          heroImagePrecacheProvider.overrideWithValue(
            widget.heroImagePrecache ??
                (ImageProvider imageProvider) async {
                  return true;
                },
          ),
          generationImageMosaicRepositoryProvider.overrideWithValue(
            widget.imageMosaicRepository ??
                _FakeGenerationImageMosaicRepository(
                  GenerationImageMosaic.fallback(rows: 7, columns: 5),
                ),
          ),
          uploadRepositoryProvider.overrideWithValue(
            widget.uploadRepository ?? _FakeUploadRepository(),
          ),
          generationTaskRepositoryProvider.overrideWithValue(
            widget.taskRepository ?? _FakeGenerationTaskRepository(),
          ),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            final GenerationSubmissionService service =
                GenerationSubmissionService(
                  uploadRepository: ref.watch(uploadRepositoryProvider),
                  generationTaskRepository: ref.watch(
                    generationTaskRepositoryProvider,
                  ),
                  feedbackRepository: const _FakeFeedbackRepository(),
                  generationRecordRepository: _recordRepository,
                  originalFileStore: const _FakeGenerationOriginalFileStore(),
                  photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
                  imageProcessor: const _FakeGenerationImageProcessor(),
                  backgroundR2UploadService:
                      const _FakeBackgroundR2UploadService(),
                );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
        child: useExplicitTheme
            ? CupertinoApp(
                locale: widget.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: appCupertinoThemeForPreference(widget.themePreference),
                home: AppThemeColorsScope(
                  colors: appThemeColorsForPreference(widget.themePreference),
                  child: page,
                ),
              )
            : CupertinoApp(
                locale: widget.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page,
              ),
      ),
    );
  }
}

class _NoopAppToastPresenter extends AppToastPresenter {
  @override
  void show(AppToastMessage message) {}
}

class _FakeGenerationImageMosaicRepository
    implements GenerationImageMosaicRepository {
  _FakeGenerationImageMosaicRepository(this.mosaic, {this.failure});

  final GenerationImageMosaic mosaic;
  final Object? failure;
  final List<({String path, int rows, int columns})> extractedRequests =
      <({String path, int rows, int columns})>[];

  @override
  Future<GenerationImageMosaic> extract(
    String imagePath, {
    required int rows,
    required int columns,
  }) async {
    extractedRequests.add((path: imagePath, rows: rows, columns: columns));
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
    return mosaic;
  }
}

class _SeededModal extends StatefulWidget {
  const _SeededModal({required this.seedFuture});

  final Future<List<GenerationRecord>> seedFuture;

  @override
  State<_SeededModal> createState() => _SeededModalState();
}

class _SeededModalState extends State<_SeededModal> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GenerationRecord>>(
      future: widget.seedFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<GenerationRecord>> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            return const GenerationSubmissionDebugModal();
          },
    );
  }
}

class _NotifyingGenerationRecordRepository extends GenerationRecordRepository {
  _NotifyingGenerationRecordRepository(this._database, this._recordsController)
    : super(_database);

  final GenerationRecordDatabase _database;
  final StreamController<List<GenerationRecord>> _recordsController;
  bool _suspendEmits = false;

  Future<void> _emitRecords() async {
    if (!_suspendEmits && !_recordsController.isClosed) {
      _recordsController.add(await listRecords());
    }
  }

  Future<void> replaceJobs(List<GenerationSubmissionJob> jobs) async {
    _suspendEmits = true;
    try {
      await super.deleteAllRecords();
      await _seedJobs(jobs, this);
    } finally {
      _suspendEmits = false;
    }
    await _emitRecords();
  }

  Future<void> clearAnimationIndex(String recordId) async {
    await (_database.update(_database.generationRecords)..where(
          ($GenerationRecordsTable table) => table.recordId.equals(recordId),
        ))
        .write(
          const GenerationRecordsCompanion(animationIndex: Value<int?>(null)),
        );
    await _emitRecords();
  }

  @override
  Future<void> createCameraRecord({
    required String recordId,
    required String originalLocalPath,
    required DateTime createdAt,
    DateTime? originalCapturedAt,
    String? originalFormat,
    int? originalWidth,
    int? originalHeight,
    String? promptStyle,
    String? captureMode,
    String? captureAspectRatio,
    String? appInputContractId,
    String? userInputJson,
    String? displaySnapshotJson,
  }) async {
    await super.createCameraRecord(
      recordId: recordId,
      originalLocalPath: originalLocalPath,
      createdAt: createdAt,
      originalCapturedAt: originalCapturedAt,
      originalFormat: originalFormat,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      promptStyle: promptStyle,
      captureMode: captureMode,
      captureAspectRatio: captureAspectRatio,
      appInputContractId: appInputContractId,
      userInputJson: userInputJson,
      displaySnapshotJson: displaySnapshotJson,
    );
    await _emitRecords();
  }

  @override
  Future<void> createGalleryRecord({
    required String recordId,
    required DateTime createdAt,
    String? originalLocalPath,
    String? originalAssetId,
    DateTime? originalCapturedAt,
    String? originalFormat,
    int? originalWidth,
    int? originalHeight,
    String? promptStyle,
    String? captureMode,
    String? captureAspectRatio,
    String? appInputContractId,
    String? userInputJson,
    String? displaySnapshotJson,
  }) async {
    await super.createGalleryRecord(
      recordId: recordId,
      createdAt: createdAt,
      originalLocalPath: originalLocalPath,
      originalAssetId: originalAssetId,
      originalCapturedAt: originalCapturedAt,
      originalFormat: originalFormat,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      promptStyle: promptStyle,
      captureMode: captureMode,
      captureAspectRatio: captureAspectRatio,
      appInputContractId: appInputContractId,
      userInputJson: userInputJson,
      displaySnapshotJson: displaySnapshotJson,
    );
    await _emitRecords();
  }

  @override
  Future<void> updatePipelineStatus({
    required String recordId,
    required GenerationRecordPipelineStatus status,
    required DateTime updatedAt,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    bool clearFailure = false,
    bool clearGenerationStartedAt = false,
  }) async {
    await super.updatePipelineStatus(
      recordId: recordId,
      status: status,
      updatedAt: updatedAt,
      errorCode: errorCode,
      errorMessage: errorMessage,
      clearError: clearError,
      clearFailure: clearFailure,
      clearGenerationStartedAt: clearGenerationStartedAt,
    );
    await _emitRecords();
  }

  @override
  Future<bool> beginGenerationAttempt({
    required String recordId,
    required DateTime startedAt,
  }) async {
    final bool started = await super.beginGenerationAttempt(
      recordId: recordId,
      startedAt: startedAt,
    );
    await _emitRecords();
    return started;
  }

  @override
  Future<void> markFailure({
    required String recordId,
    required GenerationRecordPipelineStatus status,
    required GenerationRecordFailureStage failureStage,
    required bool failureRetryable,
    required DateTime updatedAt,
    required String errorCode,
    required String errorMessage,
  }) async {
    await super.markFailure(
      recordId: recordId,
      status: status,
      failureStage: failureStage,
      failureRetryable: failureRetryable,
      updatedAt: updatedAt,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
    await _emitRecords();
  }

  @override
  Future<void> updateUploadFields({
    required String recordId,
    required DateTime updatedAt,
    String? uploadSessionId,
    String? sourceImageObjectId,
    String? uploadContentType,
    int? uploadSizeBytes,
    String? uploadSha256,
  }) async {
    await super.updateUploadFields(
      recordId: recordId,
      updatedAt: updatedAt,
      uploadSessionId: uploadSessionId,
      sourceImageObjectId: sourceImageObjectId,
      uploadContentType: uploadContentType,
      uploadSizeBytes: uploadSizeBytes,
      uploadSha256: uploadSha256,
    );
    await _emitRecords();
  }

  @override
  Future<void> updateTaskFields({
    required String recordId,
    required DateTime updatedAt,
    String? taskId,
    String? taskStatus,
    String? resultImageObjectId,
  }) async {
    await super.updateTaskFields(
      recordId: recordId,
      updatedAt: updatedAt,
      taskId: taskId,
      taskStatus: taskStatus,
      resultImageObjectId: resultImageObjectId,
    );
    await _emitRecords();
  }

  @override
  Future<void> updatePromptSelection({
    required String recordId,
    required DateTime updatedAt,
    required String promptStyle,
    required String captureMode,
    required String? appInputContractId,
    required String userInputJson,
  }) async {
    await super.updatePromptSelection(
      recordId: recordId,
      updatedAt: updatedAt,
      promptStyle: promptStyle,
      captureMode: captureMode,
      appInputContractId: appInputContractId,
      userInputJson: userInputJson,
    );
    await _emitRecords();
  }

  @override
  Future<void> updateResultFields({
    required String recordId,
    required DateTime updatedAt,
    GenerationRecordResultAvailability? resultAvailability,
    String? resultImageObjectId,
    String? resultLocalCachePath,
    String? resultAssetId,
    DateTime? resultSavedAt,
    int? resultSizeBytes,
    String? resultSha256,
    GenerationRecordHashStatus? resultHashStatus,
    String? resultHashError,
  }) async {
    await super.updateResultFields(
      recordId: recordId,
      updatedAt: updatedAt,
      resultAvailability: resultAvailability,
      resultImageObjectId: resultImageObjectId,
      resultLocalCachePath: resultLocalCachePath,
      resultAssetId: resultAssetId,
      resultSavedAt: resultSavedAt,
      resultSizeBytes: resultSizeBytes,
      resultSha256: resultSha256,
      resultHashStatus: resultHashStatus,
      resultHashError: resultHashError,
    );
    await _emitRecords();
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await super.deleteRecord(recordId);
    await _emitRecords();
  }
}

Future<void> _seedJobs(
  List<GenerationSubmissionJob> jobs,
  GenerationRecordRepository repository,
) async {
  for (final GenerationSubmissionJob job in jobs) {
    final PromptSelectionSnapshot promptSelection =
        job.promptSelection ?? PromptSelectionSnapshot.fallback;
    await repository.createCameraRecord(
      recordId: job.id,
      originalLocalPath: job.imagePath,
      createdAt: job.createdAt,
      promptStyle: promptSelection.promptStyle,
      captureMode: promptSelection.captureMode,
      appInputContractId: promptSelection.appInputContractId,
      userInputJson: jsonEncode(promptSelection.userInput),
    );
    if (job.generationStartedAt != null) {
      await repository.beginGenerationAttempt(
        recordId: job.id,
        startedAt: job.generationStartedAt!,
      );
    }
    final GenerationRecordPipelineStatus pipelineStatus = _recordStatusForJob(
      job.status,
    );
    if (job.status == GenerationSubmissionStatus.failed ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      await repository.markFailure(
        recordId: job.id,
        status: pipelineStatus,
        failureStage:
            job.failureStage ??
            (job.status == GenerationSubmissionStatus.resultProcessingFailed
                ? GenerationRecordFailureStage.processingResult
                : GenerationRecordFailureStage.backendGeneration),
        failureRetryable: job.failureRetryable,
        updatedAt: job.updatedAt,
        errorCode: job.errorCode ?? 'test_failure',
        errorMessage:
            job.errorMessage ?? job.resultSaveErrorMessage ?? 'Test failure.',
      );
    } else {
      await repository.updatePipelineStatus(
        recordId: job.id,
        status: pipelineStatus,
        updatedAt: job.updatedAt,
        errorCode: job.errorCode,
        errorMessage: job.errorMessage ?? job.resultSaveErrorMessage,
      );
    }
    await repository.updateTaskFields(
      recordId: job.id,
      updatedAt: job.updatedAt,
      taskId: job.taskId,
      taskStatus: job.taskStatus?.wireValue,
      resultImageObjectId: job.resultImageObjectId,
    );
    if (job.processedResultPath != null ||
        job.resultAvailability != GenerationRecordResultAvailability.none) {
      final String resultAssetId = 'asset-result-${job.id}';
      final String? processedResultPath = job.processedResultPath;
      if (processedResultPath != null) {
        _FakePhotoLibraryAssetStore.resultPaths[resultAssetId] =
            processedResultPath;
      }
      await repository.updateResultFields(
        recordId: job.id,
        updatedAt: job.updatedAt,
        resultAvailability:
            job.resultAvailability == GenerationRecordResultAvailability.none
            ? GenerationRecordResultAvailability.savedToPhotoLibrary
            : job.resultAvailability,
        resultAssetId: resultAssetId,
      );
    }
    final DateTime? negativeFeedbackSubmittedAt =
        job.resultNegativeFeedbackSubmittedAt;
    if (negativeFeedbackSubmittedAt != null) {
      await repository.markNegativeFeedbackSubmitted(
        recordId: job.id,
        submittedAt: negativeFeedbackSubmittedAt,
      );
    }
  }
}

GenerationRecordPipelineStatus _recordStatusForJob(
  GenerationSubmissionStatus status,
) {
  return switch (status) {
    GenerationSubmissionStatus.awaitingConfirmation =>
      GenerationRecordPipelineStatus.awaitingConfirmation,
    GenerationSubmissionStatus.queued =>
      GenerationRecordPipelineStatus.awaitingRetry,
    GenerationSubmissionStatus.preparingUploadImage =>
      GenerationRecordPipelineStatus.preparingUploadImage,
    GenerationSubmissionStatus.readingFile ||
    GenerationSubmissionStatus.creatingUpload =>
      GenerationRecordPipelineStatus.creatingUpload,
    GenerationSubmissionStatus.uploading =>
      GenerationRecordPipelineStatus.uploading,
    GenerationSubmissionStatus.uploadedWaitingTask =>
      GenerationRecordPipelineStatus.uploadedWaitingTask,
    GenerationSubmissionStatus.creatingTask =>
      GenerationRecordPipelineStatus.creatingTask,
    GenerationSubmissionStatus.submitted =>
      GenerationRecordPipelineStatus.submitted,
    GenerationSubmissionStatus.pollingTask =>
      GenerationRecordPipelineStatus.pollingTask,
    GenerationSubmissionStatus.completed =>
      GenerationRecordPipelineStatus.completed,
    GenerationSubmissionStatus.processingResultImage =>
      GenerationRecordPipelineStatus.processingResultImage,
    GenerationSubmissionStatus.resultSaved =>
      GenerationRecordPipelineStatus.resultSaved,
    GenerationSubmissionStatus.resultProcessingFailed =>
      GenerationRecordPipelineStatus.resultSaveFailed,
    GenerationSubmissionStatus.failed =>
      GenerationRecordPipelineStatus.generationFailed,
  };
}

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  const _FakeGenerationImageProcessor();

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    return PreparedUploadImage(
      path: '$sourcePath.cleaned.jpg',
      bytes: Uint8List.fromList(<int>[1]),
      sourceExif: const <String, Object>{},
    );
  }

  @override
  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  }) async {
    return ProcessedResultImage(
      path: '/tmp/result.heic',
      bytes: Uint8List.fromList(<int>[1]),
    );
  }
}

class _FakeGalleryImagePicker implements GalleryImagePicker {
  _FakeGalleryImagePicker(this.result, {this.waitForCompletion = false});

  final XFile? result;
  final bool waitForCompletion;
  final StreamController<GalleryImagePickProgress> _progressController =
      StreamController<GalleryImagePickProgress>.broadcast();
  Completer<void>? _pickCompleter;
  Completer<void>? _pickFinishedCompleter;
  int pickCount = 0;

  Future<void> get pickFinished {
    return _pickFinishedCompleter?.future ?? Future<void>.value();
  }

  @override
  Stream<GalleryImagePickProgress> get progressEvents {
    return _progressController.stream;
  }

  @override
  Future<PickedGalleryImage?> pickImageFromGallery() async {
    pickCount += 1;
    _pickFinishedCompleter = Completer<void>();
    if (waitForCompletion) {
      _pickCompleter = Completer<void>();
      await _pickCompleter!.future;
    }
    final XFile? result = this.result;
    if (result == null) {
      _pickFinishedCompleter?.complete();
      return null;
    }
    final PickedGalleryImage pickedImage = PickedGalleryImage(
      file: result,
      assetId: 'asset-gallery-1',
    );
    _pickFinishedCompleter?.complete();
    return pickedImage;
  }

  @override
  Future<void> cancelActivePick() async {}

  void emitProgress(double progress) {
    _progressController.add(
      GalleryImagePickProgress(assetId: 'asset-gallery-1', progress: progress),
    );
  }

  void completePick() {
    _pickCompleter?.complete();
  }

  Future<void> dispose() {
    return _progressController.close();
  }
}

class _FakePhotoLibraryAssetStore implements PhotoLibraryAssetStore {
  const _FakePhotoLibraryAssetStore();

  static final Map<String, String> resultPaths = <String, String>{};
  static final List<String> librarySavePaths = <String>[];
  static final List<String> librarySaveFileNames = <String>[];
  static final List<String> deletedAssetIds = <String>[];
  static int openPhotoLibraryCount = 0;

  @override
  Future<SavedPhotoLibraryImage> saveImage(
    String path, {
    required String album,
    required String fileName,
  }) async {
    return const SavedPhotoLibraryImage(assetId: 'asset-result-1');
  }

  @override
  Future<SavedPhotoLibraryImage> saveImageToLibrary(
    String path, {
    required String fileName,
  }) async {
    librarySavePaths.add(path);
    librarySaveFileNames.add(fileName);
    return const SavedPhotoLibraryImage(assetId: 'asset-original-1');
  }

  @override
  Future<String?> resolveImagePath(String assetId) async {
    return resultPaths[assetId];
  }

  @override
  Future<void> setFavorite(String assetId, {required bool isFavorite}) async {}

  @override
  Future<void> openPhotoLibrary() async {
    openPhotoLibraryCount += 1;
  }
}

class _FakeFeedbackRepository implements FeedbackRepository {
  const _FakeFeedbackRepository();

  static final List<FeedbackInput> inputs = <FeedbackInput>[];

  @override
  Future<FeedbackSubmission> submitFeedback(FeedbackInput input) async {
    inputs.add(input);
    return FeedbackSubmission(
      id: 'feedback-${input.taskId}',
      taskId: input.taskId,
      rating: input.rating,
      improveOptIn: input.improveOptIn,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }
}

class _FakeGenerationOriginalFileStore implements GenerationOriginalFileStore {
  const _FakeGenerationOriginalFileStore();

  @override
  Future<void> deleteOriginal(String path) async {}

  @override
  Future<String> resolveOriginalPath(String path) async {
    return path;
  }

  @override
  Future<bool> originalExists(String path) async {
    return true;
  }

  @override
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  }) async {
    return StoredOriginalFile(path: sourcePath, format: 'jpg');
  }

  @override
  Future<StoredOriginalFile> storeGalleryOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime importedAt,
  }) async {
    return storeCameraOriginal(
      recordId: recordId,
      sourcePath: sourcePath,
      capturedAt: importedAt,
    );
  }
}

class _FakeUploadRepository implements UploadRepository {
  _FakeUploadRepository({this.createUploadFailure});

  final BackendApiFailure? createUploadFailure;
  int createUploadCount = 0;

  @override
  Future<UploadSession> createUpload({
    required String clientRequestId,
    required String contentType,
    required Uint8List bytes,
    CreateGenerationTaskInput? generationRequest,
  }) async {
    createUploadCount += 1;
    final BackendApiFailure? failure = createUploadFailure;
    if (failure != null) {
      throw failure;
    }
    return UploadSession(
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      provider: 'r2',
      bucket: 'fantasy-camera',
      expiresAt: DateTime.parse('2026-05-29T01:00:00Z'),
      requiredHeaders: const <String, String>{
        'content-type': 'image/jpeg',
        'content-length': '1',
        'x-amz-checksum-sha256': 'checksum',
      },
      url: 'https://example.com/upload',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> uploadBytes({
    required UploadSession uploadSession,
    required Uint8List bytes,
  }) async {}

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) async {
    return <String, Object?>{'id': uploadSessionId, 'status': 'uploaded'};
  }
}

class _FakeBackgroundR2UploadService implements BackgroundR2UploadService {
  const _FakeBackgroundR2UploadService();

  @override
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  }) async {
    return const BackgroundR2UploadResult(
      downloaderTaskId: 'downloader-1',
      status: TaskStatus.complete,
      responseStatusCode: 200,
    );
  }

  @override
  void dispose() {}
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  final List<String> resultUrlTaskIds = <String>[];
  int createTaskCount = 0;

  @override
  Future<CreatedGenerationTask> createTask(
    CreateGenerationTaskInput input,
  ) async {
    createTaskCount += 1;
    return const CreatedGenerationTask(
      taskId: 'task-1',
      status: GenerationTaskStatus.pending,
      creditReservationId: 'reservation-1',
      costCredits: 2,
    );
  }

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<ResultUrl> createResultUrl(String taskId) async {
    resultUrlTaskIds.add(taskId);
    return const ResultUrl(
      url: 'https://example.com/result.jpg',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) async {
    return GenerationTask(
      id: taskId,
      status: GenerationTaskStatus.pending,
      promptStyle: 'realistic',
      captureMode: 'manual',
      sourceImageObjectId: 'source-1',
      costCredits: 2,
      attemptCount: 1,
      maxAttempts: 3,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }

  @override
  Future<GenerationTask?> fetchTaskByUploadSession(
    String uploadSessionId,
  ) async {
    return null;
  }

  @override
  Future<GenerationTasksBatchResult> fetchTasksBatch(
    List<String> taskIds,
  ) async {
    return GenerationTasksBatchResult(
      tasks: taskIds
          .map(
            (String taskId) => GenerationTask(
              id: taskId,
              status: GenerationTaskStatus.pending,
              promptStyle: 'realistic',
              captureMode: 'manual',
              sourceImageObjectId: 'source-1',
              costCredits: 2,
              attemptCount: 1,
              maxAttempts: 3,
              createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
            ),
          )
          .toList(growable: false),
      missingIds: const <String>[],
    );
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) async {
    return const <GenerationTask>[];
  }
}

class _FakeCreditsRepository implements CreditsRepository {
  const _FakeCreditsRepository(this.balance, {this.failure});

  final int balance;
  final Object? failure;

  @override
  Future<CreditBalance> fetchBalance() async {
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
    return CreditBalance(
      balance: balance,
      reservedBalance: 0,
      lifetimeEarned: balance,
      lifetimeSpent: 0,
      updatedAt: DateTime.utc(2026, 7, 5),
    );
  }

  @override
  Future<CreditRedemptionResult> redeemCode(String code) async {
    return CreditRedemptionResult(
      grantedCredits: 0,
      balance: balance,
      reservedBalance: 0,
      campaignId: 'test-campaign',
      codeId: code,
    );
  }
}

class _FakeCreditBalanceCacheRepository
    implements CreditBalanceCacheRepository {
  @override
  Future<void> clearBalance(String userId) async {}

  @override
  Future<CreditBalance?> loadBalance(String userId) async {
    return null;
  }

  @override
  Future<void> saveBalance(String userId, CreditBalance balance) async {}
}

class _FakeGenerationSubmissionGuideRepository
    implements GenerationSubmissionGuideRepository {
  _FakeGenerationSubmissionGuideRepository({required this.seen});

  bool seen;

  @override
  Future<bool> isConfirmationGuideSeen() async {
    return seen;
  }

  @override
  Future<void> markConfirmationGuideSeen() async {
    seen = true;
  }
}

GenerationImageMosaic _testMosaic(List<Color> colors) {
  assert(colors.isNotEmpty);
  return GenerationImageMosaic(
    rows: 7,
    columns: 5,
    cellColors: List<Color>.generate(
      35,
      (int index) => colors[index % colors.length].withValues(alpha: 1),
      growable: false,
    ),
  );
}

GenerationSubmissionJob _job({
  required String id,
  required GenerationSubmissionStatus status,
  String? taskId,
  String? imagePath,
  String? processedResultPath,
  PromptSelectionSnapshot? promptSelection,
  GenerationRecordResultAvailability resultAvailability =
      GenerationRecordResultAvailability.none,
  String? resultUrl,
  String? resultSaveErrorMessage,
  DateTime? resultNegativeFeedbackSubmittedAt,
  DateTime? updatedAt,
  DateTime? generationStartedAt,
}) {
  final DateTime now = DateTime.parse('2026-05-29T00:00:00Z');
  final String resolvedImagePath = imagePath ?? _writeImageFile(id).path;
  final bool retryableFailure =
      status == GenerationSubmissionStatus.failed ||
      status == GenerationSubmissionStatus.resultProcessingFailed;
  return GenerationSubmissionJob(
    id: id,
    imagePath: resolvedImagePath,
    status: status,
    taskId: taskId ?? 'task-$id',
    promptSelection:
        promptSelection ??
        const PromptSelectionSnapshot(
          promptStyle: 'realistic',
          captureMode: 'manual',
          switches: <String, bool>{
            'recompose': true,
            'beautifyFace': false,
            'cleanFrame': false,
            'backgroundBlur': false,
          },
        ),
    resultUrl: resultUrl,
    processedResultPath: processedResultPath,
    resultAvailability: resultAvailability,
    resultNegativeFeedbackSubmittedAt: resultNegativeFeedbackSubmittedAt,
    resultSaveErrorMessage: resultSaveErrorMessage,
    failureStage: retryableFailure
        ? GenerationRecordFailureStage.backendGeneration
        : null,
    failureRetryable: retryableFailure,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    generationStartedAt: generationStartedAt,
  );
}

int _percentageFromText(String text) {
  return int.parse(text.substring(0, text.length - 1));
}

File _writeImageFile(String id) {
  final File imageFile = File('${Directory.systemTemp.path}/$id.jpg');
  if (!imageFile.existsSync()) {
    imageFile.writeAsBytesSync(_onePixelPng);
  }
  return imageFile;
}

final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
