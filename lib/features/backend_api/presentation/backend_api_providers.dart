import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../config/app_config.dart';
import '../data/backend_repositories.dart';
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
});

final appConfigRepositoryProvider = Provider<AppConfigRepository>((Ref ref) {
  return WorkerAppConfigRepository(ref.watch(fantasyApiClientProvider));
}, dependencies: <ProviderOrFamily>[fantasyApiClientProvider]);

final creditsRepositoryProvider = Provider<CreditsRepository>((Ref ref) {
  return WorkerCreditsRepository(ref.watch(fantasyApiClientProvider));
}, dependencies: <ProviderOrFamily>[fantasyApiClientProvider]);

final creditBalanceProvider = FutureProvider<CreditBalance>((Ref ref) {
  return ref.watch(creditsRepositoryProvider).fetchBalance();
}, dependencies: <ProviderOrFamily>[creditsRepositoryProvider]);

final uploadRepositoryProvider = Provider<UploadRepository>((Ref ref) {
  return WorkerUploadRepository(ref.watch(fantasyApiClientProvider));
}, dependencies: <ProviderOrFamily>[fantasyApiClientProvider]);

final generationTaskRepositoryProvider = Provider<GenerationTaskRepository>((
  Ref ref,
) {
  return WorkerGenerationTaskRepository(ref.watch(fantasyApiClientProvider));
}, dependencies: <ProviderOrFamily>[fantasyApiClientProvider]);

final feedbackRepositoryProvider = Provider<FeedbackRepository>((Ref ref) {
  return WorkerFeedbackRepository(ref.watch(fantasyApiClientProvider));
}, dependencies: <ProviderOrFamily>[fantasyApiClientProvider]);
