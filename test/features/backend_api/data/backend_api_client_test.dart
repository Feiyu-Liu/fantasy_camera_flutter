import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/auth/domain/access_token_provider.dart';
import 'package:fantasy_camera_flutter/config/app_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/checksum.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/fantasy_api_client.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/feedback.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/notifications/domain/notification_device.dart';

void main() {
  group('FantasyApiClient', () {
    test('attaches bearer token to authorized requests', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'balance': 9,
          'reservedBalance': 2,
          'lifetimeEarned': 20,
          'lifetimeSpent': 11,
          'updatedAt': '2026-05-29T00:00:00Z',
        },
        'requestId': 'req-1',
      });
      final CreditsRepository repository = WorkerCreditsRepository(
        _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
      );

      final balance = await repository.fetchBalance();

      expect(balance.balance, 9);
      expect(
        adapter.requests.single.headers.value('authorization'),
        'Bearer token-1',
      );
    });

    test('refreshes token and retries once after 401', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'error': <String, Object?>{
          'code': 'unauthorized',
          'message': 'Supabase session is invalid',
        },
        'requestId': 'req-401',
      }, statusCode: 401);
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'balance': 5,
          'reservedBalance': 0,
          'lifetimeEarned': 5,
          'lifetimeSpent': 0,
          'updatedAt': '2026-05-29T00:00:00Z',
        },
        'requestId': 'req-2',
      });
      final _FakeAccessTokenProvider tokenProvider = _FakeAccessTokenProvider();
      final CreditsRepository repository = WorkerCreditsRepository(
        _client(adapter, tokenProvider: tokenProvider),
      );

      final balance = await repository.fetchBalance();

      expect(balance.balance, 5);
      expect(tokenProvider.refreshCalls, 1);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers.value('authorization'),
        'Bearer token-1',
      );
      expect(
        adapter.requests.last.headers.value('authorization'),
        'Bearer token-2',
      );
    });

    test('maps backend error envelope to BackendApiFailure', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'error': <String, Object?>{
          'code': 'conflict',
          'message': 'Insufficient credits',
          'details': <String, Object?>{'balance': 0},
        },
        'requestId': 'req-error',
      }, statusCode: 409);
      final CreditsRepository repository = WorkerCreditsRepository(
        _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
      );

      await expectLater(
        repository.fetchBalance(),
        throwsA(
          isA<BackendApiFailure>()
              .having(
                (BackendApiFailure error) => error.code,
                'code',
                'conflict',
              )
              .having(
                (BackendApiFailure error) => error.statusCode,
                'statusCode',
                409,
              )
              .having(
                (BackendApiFailure error) => error.requestId,
                'requestId',
                'req-error',
              ),
        ),
      );
    });
  });

  group('Repositories', () {
    test('parses app config and generation task responses', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'id': 'contract-1',
          'contractKey': 'mvp',
          'version': '3',
          'minAppVersion': null,
          'config': <String, Object?>{'promptStyles': <Object?>[]},
          'costRules': <String, Object?>{'generationCredits': 2},
          'publicMetadata': <String, Object?>{},
          'activatedAt': '2026-05-29T00:00:00Z',
        },
        'requestId': 'req-config',
      });
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'taskId': 'task-1',
          'status': 'pending',
          'creditReservationId': 'reservation-1',
          'costCredits': 2,
        },
        'requestId': 'req-task',
      }, statusCode: 202);

      final FantasyApiClient client = _client(
        adapter,
        tokenProvider: _FakeAccessTokenProvider(),
      );
      final appConfig = await WorkerAppConfigRepository(
        client,
      ).fetchAppInputContract();
      final task = await WorkerGenerationTaskRepository(client).createTask(
        const CreateGenerationTaskInput(
          uploadSessionId: 'upload-1',
          promptStyle: 'realistic',
          captureMode: 'portrait',
          userInput: <String, Object?>{
            'switches': <String, Object?>{'cleanFrame': true},
          },
        ),
      );

      expect(appConfig.contractKey, 'mvp');
      expect(appConfig.costRules['generationCredits'], 2);
      expect(task.taskId, 'task-1');
      expect(task.status, GenerationTaskStatus.pending);
      expect(adapter.requests.last.bodyAsJson['promptStyle'], 'realistic');
      expect(adapter.requests.last.bodyAsJson['originDeviceId'], isNull);
      expect(adapter.requests.last.bodyAsJson['userInput'], <String, Object?>{
        'promptConfigVersion': AppConfig.promptConfigVersion,
        'switches': <String, Object?>{'cleanFrame': true},
      });
    });

    test('generation task request always includes prompt config version', () {
      expect(
        const CreateGenerationTaskInput(
          uploadSessionId: 'upload-1',
          promptStyle: 'realistic',
          captureMode: 'portrait',
        ).toJson()['userInput'],
        <String, Object?>{'promptConfigVersion': AppConfig.promptConfigVersion},
      );
    });

    test('generation task request preserves explicit user input switches', () {
      expect(
        const CreateGenerationTaskInput(
          uploadSessionId: 'upload-1',
          promptStyle: 'realistic',
          captureMode: 'portrait',
          userInput: <String, Object?>{
            'switches': <String, Object?>{'cleanFrame': true},
          },
        ).toJson()['userInput'],
        <String, Object?>{
          'promptConfigVersion': AppConfig.promptConfigVersion,
          'switches': <String, Object?>{'cleanFrame': true},
        },
      );
    });

    test('redeems credit code through worker credits endpoint', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'ok': true,
          'grantedCredits': 50,
          'balance': 80,
          'reservedBalance': 0,
          'campaignId': 'campaign-1',
          'codeId': 'code-1',
        },
        'requestId': 'req-redeem',
      });
      final CreditsRepository repository = WorkerCreditsRepository(
        _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
      );

      final result = await repository.redeemCode('ABCD-EFGH-2345');

      expect(result.grantedCredits, 50);
      expect(result.balance, 80);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/v1/credits/redeem');
      expect(adapter.requests.single.bodyAsJson, <String, Object?>{
        'code': 'ABCD-EFGH-2345',
      });
    });

    test('maps redemption ok false response to backend failure', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'ok': false,
          'errorCode': 'redemption_code_unavailable',
        },
        'requestId': 'req-redeem-failed',
      });
      final CreditsRepository repository = WorkerCreditsRepository(
        _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
      );

      await expectLater(
        repository.redeemCode('ABCD-EFGH-2345'),
        throwsA(
          isA<BackendApiFailure>().having(
            (BackendApiFailure error) => error.code,
            'code',
            'redemption_code_unavailable',
          ),
        ),
      );
    });

    test(
      'generation task request includes origin device id when available',
      () {
        expect(
          const CreateGenerationTaskInput(
            uploadSessionId: 'upload-1',
            promptStyle: 'realistic',
            captureMode: 'portrait',
            originDeviceId: 'device-1',
          ).toJson()['originDeviceId'],
          'device-1',
        );
      },
    );

    test(
      'notification device repository registers and unregisters devices',
      () async {
        final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
        adapter.enqueueJson(<String, Object?>{
          'data': <String, Object?>{
            'id': 'device-1',
            'installationId': 'installation-1',
            'platform': 'ios',
            'environment': 'development',
            'topic': 'host.eunoia.tessercam',
            'locale': 'zh',
            'permissionEnabled': true,
          },
          'requestId': 'req-device',
        }, statusCode: 201);
        adapter.enqueueJson(<String, Object?>{
          'data': <String, Object?>{
            'deviceId': 'device-1',
            'unregistered': true,
          },
          'requestId': 'req-delete',
        });

        final NotificationDeviceRepository repository =
            WorkerNotificationDeviceRepository(
              _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
            );

        final RegisteredNotificationDevice device = await repository
            .registerDevice(
              const RegisterNotificationDeviceInput(
                installationId: 'installation-1',
                deviceToken: 'aabbccddeeff',
                environment: 'development',
                topic: 'host.eunoia.tessercam',
                locale: 'zh',
                permissionEnabled: true,
              ),
            );
        final UnregisteredNotificationDevice unregistered = await repository
            .unregisterDevice('device-1');

        expect(device.id, 'device-1');
        expect(unregistered.unregistered, true);
        expect(adapter.requests.first.method, 'POST');
        expect(adapter.requests.first.uri.path, '/v1/notifications/devices');
        expect(adapter.requests.first.bodyAsJson['permissionEnabled'], true);
        expect(adapter.requests.last.method, 'DELETE');
        expect(
          adapter.requests.last.uri.path,
          '/v1/notifications/devices/device-1',
        );
      },
    );

    test('upload repository creates and completes upload', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'uploadSessionId': 'upload-1',
          'sourceImageObjectId': 'image-1',
          'provider': 'r2',
          'bucket': 'fantasy-camera',
          'expiresAt': '2026-05-29T01:00:00Z',
          'requiredHeaders': <String, Object?>{
            'content-type': 'image/png',
            'content-length': '3',
            'x-amz-checksum-sha256':
                'ungWv48Bz+pBQUDeXa4iI7ADYaOWF3g1zQYfVryGRBY=',
          },
          'url': 'https://example.com/upload',
          'expiresInSeconds': 600,
        },
        'requestId': 'req-upload',
      }, statusCode: 201);
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{'id': 'upload-1', 'status': 'uploaded'},
        'requestId': 'req-complete',
      });

      final UploadRepository repository = WorkerUploadRepository(
        _client(adapter, tokenProvider: _FakeAccessTokenProvider()),
      );
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final upload = await repository.createUpload(
        clientRequestId: 'local-test-record',
        contentType: 'image/png',
        bytes: bytes,
        generationRequest: const CreateGenerationTaskInput(
          uploadSessionId: '',
          promptStyle: 'realistic',
          captureMode: 'portrait',
          userInput: <String, Object?>{'switches': <String, Object?>{}},
        ),
      );
      final completion = await repository.completeUpload(
        upload.uploadSessionId,
      );

      expect(upload.uploadSessionId, 'upload-1');
      expect(completion['status'], 'uploaded');
      expect(
        adapter.requests.first.bodyAsJson['clientRequestId'],
        'local-test-record',
      );
      expect(
        adapter.requests.first.bodyAsJson['checksumSha256'],
        sha256Base64(bytes),
      );
      expect(
        adapter.requests.first.bodyAsJson['generationRequest'],
        containsPair('promptStyle', 'realistic'),
      );
      expect(
        adapter.requests.first.bodyAsJson['generationRequest'],
        isNot(contains('uploadSessionId')),
      );
      expect(adapter.requests.last.uri.path, '/v1/uploads/upload-1/complete');
    });

    test('parses task list, result url, and feedback response', () async {
      final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter();
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'tasks': <Object?>[_taskJson(id: 'task-1', status: 'completed')],
        },
        'requestId': 'req-list',
      });
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'url': 'https://example.com/result',
          'expiresInSeconds': 600,
        },
        'requestId': 'req-result',
      });
      adapter.enqueueJson(<String, Object?>{
        'data': <String, Object?>{
          'id': 'feedback-1',
          'taskId': 'task-1',
          'rating': 'negative',
          'improveOptIn': true,
          'createdAt': '2026-05-29T00:00:00Z',
        },
        'requestId': 'req-feedback',
      }, statusCode: 201);

      final FantasyApiClient client = _client(
        adapter,
        tokenProvider: _FakeAccessTokenProvider(),
      );
      final tasks = await WorkerGenerationTaskRepository(client).listTasks();
      final result = await WorkerGenerationTaskRepository(
        client,
      ).createResultUrl('task-1');
      final feedback = await WorkerFeedbackRepository(client).submitFeedback(
        const FeedbackInput(
          taskId: 'task-1',
          rating: FeedbackRating.negative,
          tags: <String>['face'],
          note: 'Face changed too much',
          improveOptIn: true,
        ),
      );

      expect(tasks.single.status, GenerationTaskStatus.completed);
      expect(tasks.single.isTerminal, isTrue);
      expect(result.url, 'https://example.com/result');
      expect(feedback.rating, FeedbackRating.negative);
      expect(adapter.requests.last.bodyAsJson['rating'], 'negative');
      expect(adapter.requests.last.bodyAsJson['note'], 'Face changed too much');
    });
  });

  test('sha256Base64 matches backend upload checksum format', () {
    final Uint8List mockPngBytes = base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    );

    expect(
      sha256Base64(mockPngBytes),
      'S1xcks7Dsj5qKU/A7qQyNO9RJsWmT0xsUxrIQwqwuEQ=',
    );
  });
}

FantasyApiClient _client(
  _FakeHttpClientAdapter adapter, {
  required AccessTokenProvider tokenProvider,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.com',
      validateStatus: (int? status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return FantasyApiClient(dio: dio, accessTokenProvider: tokenProvider);
}

Map<String, Object?> _taskJson({required String id, required String status}) {
  return <String, Object?>{
    'id': id,
    'status': status,
    'promptStyle': 'realistic',
    'captureMode': 'portrait',
    'sourceImageObjectId': 'source-1',
    'resultImageObjectId': status == 'completed' ? 'result-1' : null,
    'costCredits': 2,
    'attemptCount': 1,
    'maxAttempts': 3,
    'lastErrorCode': null,
    'lastErrorMessage': null,
    'createdAt': '2026-05-29T00:00:00Z',
    'completedAt': status == 'completed' ? '2026-05-29T00:01:00Z' : null,
    'failedAt': null,
    'canceledAt': null,
  };
}

class _FakeAccessTokenProvider implements AccessTokenProvider {
  int ensureCalls = 0;
  int refreshCalls = 0;

  @override
  Future<String?> ensureValidAccessToken() async {
    ensureCalls += 1;
    return 'token-1';
  }

  @override
  Future<String?> refreshAccessToken() async {
    refreshCalls += 1;
    return 'token-2';
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final List<_QueuedResponse> _responses = <_QueuedResponse>[];
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  void enqueueJson(Map<String, Object?> json, {int statusCode = 200}) {
    _responses.add(
      _QueuedResponse(
        statusCode: statusCode,
        bytes: utf8.encode(jsonEncode(json)),
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      ),
    );
  }

  void enqueueBytes(
    Uint8List bytes, {
    int statusCode = 200,
    String contentType = 'application/octet-stream',
  }) {
    _responses.add(
      _QueuedResponse(
        statusCode: statusCode,
        bytes: bytes,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[contentType],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Uint8List body = requestStream == null
        ? Uint8List(0)
        : Uint8List.fromList(
            await requestStream
                .expand<int>((Uint8List chunk) => chunk)
                .toList(),
          );
    requests.add(
      _CapturedRequest(
        method: options.method,
        uri: options.uri,
        headers: Headers.fromMap(
          options.headers.map((String key, Object? value) {
            if (value is List<String>) {
              return MapEntry<String, List<String>>(key, value);
            }
            return MapEntry<String, List<String>>(key, <String>[
              if (value != null) value.toString(),
            ]);
          }),
        ),
        body: body,
      ),
    );

    if (_responses.isEmpty) {
      throw StateError(
        'No queued response for ${options.method} ${options.uri}.',
      );
    }
    final _QueuedResponse response = _responses.removeAt(0);
    return ResponseBody.fromBytes(
      response.bytes,
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _QueuedResponse {
  const _QueuedResponse({
    required this.statusCode,
    required this.bytes,
    required this.headers,
  });

  final int statusCode;
  final List<int> bytes;
  final Map<String, List<String>> headers;
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Headers headers;
  final Uint8List body;

  Map<String, Object?> get bodyAsJson {
    final Object? decoded = jsonDecode(utf8.decode(body));
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return Map<String, Object?>.from(decoded as Map);
  }
}
