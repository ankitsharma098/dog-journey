import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';

/// Writes into the `photos` Storage bucket (supabase/migrations/0001_init.sql)
/// — replaces the Drive-based workaround this session started with
/// before landing here. Bucket policy: authenticated users may write
/// only under their own uid prefix, public read on the whole bucket.
class SupabaseStorageService {
  SupabaseStorageService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  static const String _bucket = 'photos';

  /// Uploads [bytes] to `photos/{path}` and returns a URL usable
  /// directly with `Image.network`.
  Future<String> upload(
    Uint8List bytes,
    String path, {
    String contentType = 'image/jpeg',
  }) async {
    AppLogger.debug('SupabaseStorage upload $path (${bytes.lengthInBytes} bytes)');
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);
    AppLogger.info('SupabaseStorage upload $path — ok');
    return url;
  }
}
