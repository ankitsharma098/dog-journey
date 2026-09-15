import 'package:flutter/material.dart';

/// A subtle repeating paw-print pattern behind the chat, in the style
/// of WhatsApp/Telegram's tiled wallpaper — replaces the flat solid
/// dark fill so the conversation doesn't read as an empty black box.
class ChatDoodleBackground extends StatelessWidget {
  const ChatDoodleBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0F0F14)),
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _DoodlePainter())),
        ),
        child,
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  static const _icons = [Icons.pets_rounded, Icons.favorite_rounded];
  static const _colSpacing = 56.0;
  static const _rowSpacing = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / _colSpacing).ceil() + 1;
    final rows = (size.height / _rowSpacing).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final icon = _icons[(row + col) % _icons.length];
        final dx = col * _colSpacing + (row.isOdd ? _colSpacing / 2 : 0);
        final dy = row * _rowSpacing;
        _paintGlyph(canvas, icon, Offset(dx, dy));
      }
    }
  }

  void _paintGlyph(Canvas canvas, IconData icon, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 20,
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => false;
}
