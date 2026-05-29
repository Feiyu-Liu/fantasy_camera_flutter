import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../config/app_config.dart';
import '../data/backend_repositories.dart';
import '../data/fantasy_api_client.dart';

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
  return AppConfigRepository(ref.watch(fantasyApiClientProvider));
});

final creditsRepositoryProvider = Provider<CreditsRepository>((Ref ref) {
  return CreditsRepository(ref.watch(fantasyApiClientProvider));
});

final uploadRepositoryProvider = Provider<UploadRepository>((Ref ref) {
  return UploadRepository(ref.watch(fantasyApiClientProvider));
});

final generationTaskRepositoryProvider = Provider<GenerationTaskRepository>((
  Ref ref,
) {
  return GenerationTaskRepository(ref.watch(fantasyApiClientProvider));
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((Ref ref) {
  return FeedbackRepository(ref.watch(fantasyApiClientProvider));
});
