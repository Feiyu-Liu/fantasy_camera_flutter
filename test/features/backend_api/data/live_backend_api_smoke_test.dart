import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' hide AuthUser;

import 'package:fantasy_camera_flutter/auth/domain/access_token_provider.dart';
import 'package:fantasy_camera_flutter/config/app_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/fantasy_api_client.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';

void main() {
  const bool runLiveSmoke = bool.fromEnvironment('RUN_LIVE_BACKEND_SMOKE');
  const String email = String.fromEnvironment('SMOKE_EMAIL');
  const String password = String.fromEnvironment('SMOKE_PASSWORD');

  test(
    'live backend supports auth, config, credits, upload, and task creation',
    () async {
      if (!runLiveSmoke) {
        markTestSkipped(
          'Set RUN_LIVE_BACKEND_SMOKE=true to run live backend smoke.',
        );
        return;
      }
      if (!AppConfig.hasSupabaseConfig || AppConfig.workerApiBaseUrl.isEmpty) {
        fail('Supabase and Worker dart-defines are required.');
      }
      if (email.isEmpty || password.isEmpty) {
        fail('SMOKE_EMAIL and SMOKE_PASSWORD dart-defines are required.');
      }

      final SupabaseClient supabase = SupabaseClient(
        AppConfig.supabaseUrl,
        AppConfig.supabasePublishableKey,
      );
      final AuthResponse auth = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final String? accessToken = auth.session?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        fail('Supabase sign in did not return an access token.');
      }

      final FantasyApiClient client = FantasyApiClient(
        dio: buildFantasyApiDio(AppConfig.workerApiBaseUrl),
        accessTokenProvider: _StaticAccessTokenProvider(accessToken),
      );
      final AppConfigRepository appConfigRepository = WorkerAppConfigRepository(
        client,
      );
      final CreditsRepository creditsRepository = WorkerCreditsRepository(
        client,
      );
      final UploadRepository uploadRepository = WorkerUploadRepository(client);
      final GenerationTaskRepository taskRepository =
          WorkerGenerationTaskRepository(client);

      final appInputContract = await appConfigRepository
          .fetchAppInputContract();
      expect(appInputContract.id, isNotEmpty);

      final balance = await creditsRepository.fetchBalance();
      expect(balance.balance, greaterThanOrEqualTo(0));

      final Uint8List pngBytes = base64.decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
      );
      final upload = await uploadRepository.createUpload(
        clientRequestId: 'live-smoke-${DateTime.now().microsecondsSinceEpoch}',
        contentType: 'image/png',
        bytes: pngBytes,
      );
      await uploadRepository.uploadBytes(
        uploadSession: upload,
        bytes: pngBytes,
      );
      await uploadRepository.completeUpload(upload.uploadSessionId);

      final createdTask = await taskRepository.createTask(
        CreateGenerationTaskInput(
          uploadSessionId: upload.uploadSessionId,
          promptStyle: 'realistic',
          captureMode: 'manual',
          userInput: const <String, Object?>{
            'switches': <String, Object?>{
              'recompose': false,
              'beautifyFace': false,
              'cleanFrame': false,
            },
          },
          appInputContractId: appInputContract.id,
        ),
      );
      expect(createdTask.taskId, isNotEmpty);

      final fetchedTask = await taskRepository.fetchTask(createdTask.taskId);
      expect(fetchedTask.id, createdTask.taskId);

      final tasks = await taskRepository.listTasks(limit: 10);
      expect(
        tasks.map((GenerationTask task) => task.id),
        contains(createdTask.taskId),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _StaticAccessTokenProvider implements AccessTokenProvider {
  const _StaticAccessTokenProvider(this.accessToken);

  final String accessToken;

  @override
  Future<String?> ensureValidAccessToken() async => accessToken;

  @override
  Future<String?> refreshAccessToken() async => accessToken;
}
