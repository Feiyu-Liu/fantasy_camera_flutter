import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/generation_record_database.dart';
import '../data/generation_record_repository.dart';

final generationRecordDatabaseProvider = Provider<GenerationRecordDatabase>((
  Ref ref,
) {
  final GenerationRecordDatabase database = GenerationRecordDatabase();
  ref.onDispose(database.close);
  return database;
}, dependencies: const <ProviderOrFamily>[]);

final generationRecordRepositoryProvider = Provider<GenerationRecordRepository>(
  (Ref ref) {
    return GenerationRecordRepository(
      ref.watch(generationRecordDatabaseProvider),
    );
  },
  dependencies: <ProviderOrFamily>[generationRecordDatabaseProvider],
);

final generationRecordsProvider = StreamProvider<List<GenerationRecord>>((
  Ref ref,
) {
  return ref.watch(generationRecordRepositoryProvider).watchRecords();
}, dependencies: <ProviderOrFamily>[generationRecordRepositoryProvider]);
