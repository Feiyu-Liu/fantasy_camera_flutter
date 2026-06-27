import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
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
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_modal.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ui/my_ui.dart';

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
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-completed'),
      ),
      findsOneWidget,
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
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
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

    expect(uploadRepository.createUploadCount, 1);
    expect(taskRepository.createTaskCount, 0);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsOneWidget,
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

  testWidgets('tapping completed photo loads result image', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
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
      _ModalHost(jobs: jobs, taskRepository: taskRepository),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-photo-done')),
    );
    await tester.pump();
    await tester.pump();

    expect(taskRepository.resultUrlTaskIds, <String>['task-done']);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
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
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsOneWidget,
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
    expect(find.text('保存原图'), findsOneWidget);
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

    final Rect dismissRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('generation-submission-more-dismiss-layer'),
      ),
    );
    await tester.tapAt(Offset(dismissRect.left + 8, dismissRect.top + 8));
    await tester.pump(const Duration(milliseconds: 360));

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-more-dismiss-layer'),
      ),
      findsNothing,
    );
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
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-more-dismiss-layer'),
      ),
      findsOneWidget,
    );
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
    return key is ValueKey<String> &&
        key.value.startsWith('generation-submission-confirm-');
  });
}

Future<void> _pumpModalHost(WidgetTester tester, _ModalHost host) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  });
  await tester.pumpWidget(
    CupertinoApp(
      locale: defaultAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: host,
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Future<void> _tapExpandedMoreAction(WidgetTester tester, int index) async {
  final Finder hitRegion = find.byKey(
    const ValueKey<String>('generation-submission-more-hit-region'),
  );
  final double requiredHeight = 10 + (index + 1) * 42;
  for (int attempt = 0; attempt < 10; attempt += 1) {
    final Rect rect = tester.getRect(hitRegion);
    if (rect.height >= requiredHeight) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 40));
  }
  final Rect rect = tester.getRect(hitRegion);
  expect(rect.height, greaterThanOrEqualTo(requiredHeight));
  await tester.tapAt(Offset(rect.center.dx, rect.top + 10 + index * 42 + 21));
}

class _ModalHost extends StatefulWidget {
  const _ModalHost({
    super.key,
    required this.jobs,
    this.themePreference = AppThemePreference.light,
    this.imagePicker,
    this.heroImagePrecache,
    this.uploadRepository,
    this.taskRepository,
  });

  final List<GenerationSubmissionJob> jobs;
  final AppThemePreference themePreference;
  final _FakeGalleryImagePicker? imagePicker;
  final HeroImagePrecache? heroImagePrecache;
  final _FakeUploadRepository? uploadRepository;
  final _FakeGenerationTaskRepository? taskRepository;

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
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

  @override
  void dispose() {
    _recordsController.close();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = CupertinoPageScaffold(
      child: _SeededModal(seedFuture: _seedFuture),
    );
    final bool useExplicitTheme =
        widget.themePreference != AppThemePreference.light;
    return AppToastHost(
      child: ProviderScope(
        overrides: <Override>[
          generationRecordDatabaseProvider.overrideWithValue(_database),
          generationRecordRepositoryProvider.overrideWithValue(
            _recordRepository,
          ),
          appToastPresenterProvider.overrideWithValue(_NoopAppToastPresenter()),
          galleryResumeActiveRecordsOnOpenProvider.overrideWithValue(false),
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
                theme: appCupertinoThemeForPreference(widget.themePreference),
                home: AppThemeColorsScope(
                  colors: appThemeColorsForPreference(widget.themePreference),
                  child: page,
                ),
              )
            : CupertinoApp(home: page),
      ),
    );
  }
}

class _NoopAppToastPresenter extends AppToastPresenter {
  @override
  void show(AppToastMessage message) {}
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
  _NotifyingGenerationRecordRepository(super.database, this._recordsController);

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
      for (final GenerationRecord record in await listRecords()) {
        await super.deleteRecord(record.recordId);
      }
      await _seedJobs(jobs, this);
    } finally {
      _suspendEmits = false;
    }
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
  }) async {
    await super.updatePipelineStatus(
      recordId: recordId,
      status: status,
      updatedAt: updatedAt,
      errorCode: errorCode,
      errorMessage: errorMessage,
      clearError: clearError,
      clearFailure: clearFailure,
    );
    await _emitRecords();
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
    await repository.createCameraRecord(
      recordId: job.id,
      originalLocalPath: job.imagePath,
      createdAt: job.createdAt,
      promptStyle:
          job.promptSelection?.promptStyle ??
          PromptSelectionSnapshot.fallback.promptStyle,
      captureMode:
          job.promptSelection?.captureMode ??
          PromptSelectionSnapshot.fallback.captureMode,
    );
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
  int createUploadCount = 0;

  @override
  Future<UploadSession> createUpload({
    required String clientRequestId,
    required String contentType,
    required Uint8List bytes,
    CreateGenerationTaskInput? generationRequest,
  }) async {
    createUploadCount += 1;
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
      captureMode: 'portrait',
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
              captureMode: 'portrait',
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

GenerationSubmissionJob _job({
  required String id,
  required GenerationSubmissionStatus status,
  String? taskId,
  String? imagePath,
  String? processedResultPath,
  GenerationRecordResultAvailability resultAvailability =
      GenerationRecordResultAvailability.none,
  String? resultUrl,
  String? resultSaveErrorMessage,
  DateTime? resultNegativeFeedbackSubmittedAt,
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
    promptSelection: const PromptSelectionSnapshot(
      promptStyle: 'realistic',
      captureMode: 'portrait',
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
    updatedAt: now,
  );
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
