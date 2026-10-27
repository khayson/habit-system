import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';

/// A56: the stacked-cards mark (the launcher icon's three cards and check on its green circle),
/// drawn in code so no image asset is needed. Decorative: hidden from TalkBack.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _MarkPainter()),
  );
}

/// The mark with the app's name beside it, at the top of sign-in and create-account.
class BrandHeader extends StatelessWidget {
  final String name;

  const BrandHeader({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: HabitSpace.s16),
      child: Row(
        children: [
          const BrandMark(size: 48),
          const SizedBox(width: HabitSpace.s12),
          Flexible(
            child: Text(name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  // The icon kit's colours (ic_launcher_*): the green circle and the cards.
  static const _green = Color(0xFF2F7B45);
  static const _back = Color(0xFFE7F4E7);
  static const _middle = Color(0xFF8BD799);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    canvas.drawCircle(Offset(24 * s, 24 * s), 24 * s, Paint()..color = _green);
    RRect card(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x * s, y * s, w * s, h * s), Radius.circular(r * s));
    canvas.save();
    canvas.translate(24 * s, 17 * s);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-24 * s, -17 * s);
    canvas.drawRRect(card(13, 13, 22, 9, 4), Paint()..color = _back);
    canvas.restore();
    canvas.drawRRect(card(12, 18, 24, 9, 4), Paint()..color = _middle);
    canvas.drawRRect(card(11, 23, 26, 14, 5), Paint()..color = Colors.white);
    final check = Path()
      ..moveTo(17 * s, 30 * s)
      ..lineTo(21 * s, 34 * s)
      ..lineTo(30 * s, 25 * s);
    canvas.drawPath(
      check,
      Paint()
        ..color = _green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
