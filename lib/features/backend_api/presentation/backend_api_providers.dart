import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../config/app_config.dart';
import '../data/backend_repositories.dart';
import '../data/credit_balance_cache_repository.dart';
import '../data/fantasy_api_client.dart';
import '../domain/credit_balance.dart';

final backendDioProvider = Provider<Dio>((Ref ref) {
  return buildFantasyApiDio(AppConfig.workerApiBaseUrl);
});

final fantasyApiClientProvider = Provider<FantasyApiClient>((Ref ref) {
  return FantasyApiClient(
    dio: ref.watch(backendDioProvider),
    accessTokenProvider: ref.watch(accessTokenProvider),
  );
}, dependencies: <ProviderOrFamily>[backendDioProvider, accessTokenProvider]);

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (Ref ref) {
    return WorkerAppConfigRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (Ref ref) {
    return WorkerAccountRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final creditsRepositoryProvider = Provider<CreditsRepository>(
  (Ref ref) {
    return WorkerCreditsRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final creditBalanceCacheRepositoryProvider =
    Provider<CreditBalanceCacheRepository>(
      (Ref ref) => const SharedPreferencesCreditBalanceCacheRepository(),
      dependencies: const <ProviderOrFamily>[],
    );

final creditBalanceProvider =
    AsyncNotifierProvider<CreditBalanceController, CreditBalance>(
      CreditBalanceController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        creditsRepositoryProvider,
        creditBalanceCacheRepositoryProvider,
      ],
    );

class CreditBalanceController extends AsyncNotifier<CreditBalance> {
  String? _userId;
  late CreditsRepository _creditsRepository;
  late CreditBalanceCacheRepository _cacheRepository;
  bool _isDisposed = false;

  @override
  Future<CreditBalance> build() async {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    _creditsRepository = ref.watch(creditsRepositoryProvider);
    _cacheRepository = ref.watch(creditBalanceCacheRepositoryProvider);

    final String? userId = ref.watch(authSessionProvider).valueOrNull?.user?.id;
    _userId = userId;
    if (userId == null || userId.isEmpty) {
      return Future<CreditBalance>.error(
        StateError('Sign in is required to load credits.'),
      );
    }

    final CreditBalance? cached = await _loadCachedBalance(userId);
    if (cached != null) {
      _refreshFromServerInBackground(userId);
      return cached;
    }
    return _fetchAndCache(userId);
  }

  Future<void> refreshFromServer({String? userId}) async {
    userId ??= await _currentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final CreditBalance? previous = state.valueOrNull;
    state = previous == null
        ? const AsyncValue<CreditBalance>.loading()
        : AsyncValue<CreditBalance>.data(previous);
    try {
      final CreditBalance balance = await _fetchAndCache(userId);
      if (!_isDisposed && _userId == userId) {
        state = AsyncValue<CreditBalance>.data(balance);
      }
    } on Object catch (error, stackTrace) {
      if (_isDisposed || _userId != userId) {
        return;
      }
      if (previous == null) {
        state = AsyncValue<CreditBalance>.error(error, stackTrace);
      } else {
        state = AsyncValue<CreditBalance>.data(previous);
      }
    }
  }

  Future<void> _refreshFromServerInBackground(String userId) async {
    try {
      final CreditBalance balance = await _fetchAndCache(userId);
      if (!_isDisposed && _userId == userId) {
        state = AsyncValue<CreditBalance>.data(balance);
      }
    } on Object {
      // Keep the cached balance visible when the background refresh fails.
    }
  }

  Future<CreditBalance> _fetchAndCache(String userId) async {
    final CreditBalance balance = await _creditsRepository.fetchBalance();
    await _cacheRepository.saveBalance(userId, balance);
    return balance;
  }

  Future<CreditBalance?> _loadCachedBalance(String userId) async {
    try {
      return await _cacheRepository.loadBalance(userId);
    } on Object {
      return null;
    }
  }

  Future<String?> _currentUserId() async {
    final String? loadedUserId = _userId;
    if (loadedUserId != null && loadedUserId.isNotEmpty) {
      return loadedUserId;
    }
    return null;
  }
}

final uploadRepositoryProvider = Provider<UploadRepository>(
  (Ref ref) {
    return WorkerUploadRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final generationTaskRepositoryProvider = Provider<GenerationTaskRepository>(
  (Ref ref) {
    return WorkerGenerationTaskRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (Ref ref) {
    return WorkerFeedbackRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);
