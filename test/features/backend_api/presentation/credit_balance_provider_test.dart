import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/credit_balance_cache_repository.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads cached balance first and refreshes server balance', () async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository(
      balances: <CreditBalance>[_balance(99)],
    );
    final _FakeCreditBalanceCacheRepository cacheRepository =
        _FakeCreditBalanceCacheRepository()..balances['user-1'] = _balance(42);
    final ProviderContainer container = _container(
      creditsRepository: creditsRepository,
      cacheRepository: cacheRepository,
    );
    addTearDown(container.dispose);

    final CreditBalance cached = await _readBalance(container);
    expect(cached.balance, 42);

    await _waitForBalance(container, 99);

    expect(container.read(creditBalanceProvider).valueOrNull?.balance, 99);
    expect(cacheRepository.balances['user-1']?.balance, 99);
    expect(creditsRepository.fetchCalls, 1);
  });

  test('loads server balance and saves it when cache is empty', () async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository(
      balances: <CreditBalance>[_balance(15)],
    );
    final _FakeCreditBalanceCacheRepository cacheRepository =
        _FakeCreditBalanceCacheRepository();
    final ProviderContainer container = _container(
      creditsRepository: creditsRepository,
      cacheRepository: cacheRepository,
    );
    addTearDown(container.dispose);

    final CreditBalance balance = await _readBalance(container);

    expect(balance.balance, 15);
    expect(cacheRepository.balances['user-1']?.balance, 15);
    expect(creditsRepository.fetchCalls, 1);
  });

  test('uses user-scoped cache entries', () async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository(
      balances: <CreditBalance>[_balance(11)],
    );
    final _FakeCreditBalanceCacheRepository cacheRepository =
        _FakeCreditBalanceCacheRepository()
          ..balances['user-1'] = _balance(11)
          ..balances['user-2'] = _balance(88);
    final ProviderContainer container = _container(
      userId: 'user-2',
      creditsRepository: creditsRepository,
      cacheRepository: cacheRepository,
    );
    addTearDown(container.dispose);

    final CreditBalance balance = await _readBalance(container);

    expect(balance.balance, 88);
    await _waitForBalance(container, 11);
    expect(cacheRepository.balances['user-1']?.balance, 11);
    expect(cacheRepository.balances['user-2']?.balance, 11);
  });

  test('keeps cached balance when background refresh fails', () async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository(
      failure: StateError('network failed'),
    );
    final _FakeCreditBalanceCacheRepository cacheRepository =
        _FakeCreditBalanceCacheRepository()..balances['user-1'] = _balance(31);
    final ProviderContainer container = _container(
      creditsRepository: creditsRepository,
      cacheRepository: cacheRepository,
    );
    addTearDown(container.dispose);

    final CreditBalance cached = await _readBalance(container);
    await _pumpEventQueue();

    expect(cached.balance, 31);
    expect(container.read(creditBalanceProvider).valueOrNull?.balance, 31);
    expect(cacheRepository.balances['user-1']?.balance, 31);
  });

  test(
    'explicit refresh keeps previous value when server refresh fails',
    () async {
      final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository(
        balances: <CreditBalance>[_balance(21)],
      );
      final _FakeCreditBalanceCacheRepository cacheRepository =
          _FakeCreditBalanceCacheRepository();
      final ProviderContainer container = _container(
        creditsRepository: creditsRepository,
        cacheRepository: cacheRepository,
      );
      addTearDown(container.dispose);

      await _readBalance(container);
      creditsRepository.failure = StateError('network failed');

      await container.read(creditBalanceProvider.notifier).refreshFromServer();

      expect(container.read(creditBalanceProvider).valueOrNull?.balance, 21);
    },
  );
}

ProviderContainer _container({
  String userId = 'user-1',
  required _FakeCreditsRepository creditsRepository,
  required _FakeCreditBalanceCacheRepository cacheRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      authSessionProvider.overrideWith(
        (_) => Stream<AuthSessionState>.value(
          AuthSessionState.signedIn(
            AuthUser(id: userId, email: '$userId@example.com'),
          ),
        ),
      ),
      creditsRepositoryProvider.overrideWithValue(creditsRepository),
      creditBalanceCacheRepositoryProvider.overrideWithValue(cacheRepository),
    ],
  );
}

CreditBalance _balance(int value) {
  return CreditBalance(
    balance: value,
    reservedBalance: 0,
    lifetimeEarned: value,
    lifetimeSpent: 0,
    updatedAt: DateTime.utc(2026, 6, 22),
  );
}

Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<CreditBalance> _readBalance(ProviderContainer container) async {
  await container.read(authSessionProvider.future);
  return container.read(creditBalanceProvider.future);
}

Future<void> _waitForBalance(ProviderContainer container, int expected) async {
  for (int index = 0; index < 20; index += 1) {
    if (container.read(creditBalanceProvider).valueOrNull?.balance ==
        expected) {
      return;
    }
    await _pumpEventQueue();
  }
}

class _FakeCreditsRepository implements CreditsRepository {
  _FakeCreditsRepository({
    this.balances = const <CreditBalance>[],
    this.failure,
  });

  final List<CreditBalance> balances;
  Object? failure;
  int fetchCalls = 0;

  @override
  Future<CreditBalance> fetchBalance() async {
    fetchCalls += 1;
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
    if (balances.isEmpty) {
      return _balance(0);
    }
    return balances[(fetchCalls - 1).clamp(0, balances.length - 1)];
  }
}

class _FakeCreditBalanceCacheRepository
    implements CreditBalanceCacheRepository {
  final Map<String, CreditBalance> balances = <String, CreditBalance>{};

  @override
  Future<CreditBalance?> loadBalance(String userId) async {
    return balances[userId];
  }

  @override
  Future<void> saveBalance(String userId, CreditBalance balance) async {
    balances[userId] = balance;
  }
}
