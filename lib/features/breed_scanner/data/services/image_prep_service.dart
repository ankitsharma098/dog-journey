import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../core/logging/app_logger.dart';

class PreparedImage {
  const PreparedImage({required this.bytes, required this.hash});

  final Uint8List bytes;
  final String hash; // sha256 hex, 64 chars — Scan.imageHash / cache key
}

/// PRD §9 cost control: compress to ~1200px client-side before a
/// Storage upload or a model call. The hash of the *compressed* bytes
/// is what [ScanRepository.findCached] matches on, so a repeat scan of
/// the same photo hits the cache even if the original file changed
/// (e.g. re-exported by the OS) as long as it compresses identically.
class ImagePrepService {
  Future<PreparedImage> prepare(XFile file) async {
    final original = await file.readAsBytes();
    AppLogger.debug('ImagePrep compressing ${original.lengthInBytes} bytes');

    final bytes = await FlutterImageCompress.compressWithList(
      original,
      minWidth: 1200,
      minHeight: 1200,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    final hash = sha256.convert(bytes).toString();
    AppLogger.debug('ImagePrep done — ${bytes.lengthInBytes} bytes, hash $hash');
    return PreparedImage(bytes: bytes, hash: hash);
  }
}
