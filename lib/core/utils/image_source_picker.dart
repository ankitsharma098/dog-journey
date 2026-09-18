import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../widgets/royal/action_sheet.dart';

/// "Take photo" / "Choose from gallery" — the choice the breed scanner
/// already offered, but Add Dog and Add Memory skipped straight to
/// the gallery. Centralised here so both get the same choice instead
/// of the gap reappearing wherever the next photo picker is added.
Future<Uint8List?> pickImageWithSourceChoice(
  BuildContext context, {
  double maxWidth = 1600,
  int imageQuality = 85,
}) async {
  final completer = Completer<ImageSource?>();
  await showRoyalActionSheet(
    context,
    items: [
      RoyalActionSheetItem(
        icon: PhosphorIconsFill.camera,
        title: 'Take a photo',
        subtitle: 'Use your camera now',
        onTap: () => completer.complete(ImageSource.camera),
      ),
      RoyalActionSheetItem(
        icon: PhosphorIconsFill.imagesSquare,
        title: 'Choose from gallery',
        subtitle: 'Pick an existing photo',
        onTap: () => completer.complete(ImageSource.gallery),
      ),
    ],
  );
  // The sheet can also be dismissed (tap outside, swipe down) without
  // either item firing — resolve that as "no choice" instead of
  // hanging forever.
  if (!completer.isCompleted) completer.complete(null);
  final source = await completer.future;
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
