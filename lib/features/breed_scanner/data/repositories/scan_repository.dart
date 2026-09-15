import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/data/supabase_repository.dart';
import '../../../../core/error/result.dart';
import '../models/scan.dart';

class ScanRepository extends SupabaseRepository<Scan> {
  ScanRepository({required super.client})
    : super(
        table: SupabaseTables.scans,
        fromJson: Scan.fromJson,
        toJson: (scan) => scan.toJson(),
      );

  /// BS-3's hash-and-cache cost control: a prior *completed* scan of
  /// the same photo (same [imageHash]) under the same [modelVersion]
  /// means the model call — and the quota it would cost — can be
  /// skipped entirely.
  ///
  /// [userId] is an explicit filter here for the `scans_cache_idx`
  /// index (`user_id, image_hash, model_version where status='done'`),
  /// not a security requirement — RLS already restricts every `scans`
  /// read to the caller's own rows regardless of the query shape.
  Future<Result<Scan?>> findCached(
    String userId,
    String imageHash,
    String modelVersion,
  ) async {
    final result = await queryOnce(
      (query) => query
          .eq('user_id', userId)
          .eq('image_hash', imageHash)
          .eq('model_version', modelVersion)
          .eq('status', 'done')
          .limit(1),
    );
    return result.fold(
      (matches) => Result.ok(matches.isEmpty ? null : matches.first),
      Result.err,
    );
  }
}
