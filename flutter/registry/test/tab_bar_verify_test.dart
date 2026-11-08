import 'package:fliin_ui/components/tab_bar/fl_tab_bar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les glyphes des onglets : une maison, une bulle, une personne, une
/// cloche et une roue, tracés au trait de la couleur de l'`IconTheme`.
enum _Glyph { home, chat, person, bell, gear }

class _Icon extends StatelessWidget {
  const _Icon(this.glyph);

  final _Glyph glyph;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return CustomPaint(size: Size.square(icon.size!), painter: _IconPainter(glyph, icon.color!));
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Offset p(double x, double y) => Offset(x * u, y * u);
    switch (glyph) {
      case _Glyph.home:
        canvas.drawPath(
          Path()
            ..moveTo(4 * u, 11 * u)
            ..lineTo(12 * u, 4 * u)
            ..lineTo(20 * u, 11 * u)
            ..lineTo(20 * u, 20 * u)
            ..lineTo(4 * u, 20 * u)
            ..close(),
          paint,
        );
      case _Glyph.chat:
        canvas
          ..drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(3, 5), p(21, 17)), Radius.circular(4 * u)), paint)
          ..drawLine(p(8, 17), p(7, 21), paint);
      case _Glyph.person:
        canvas
          ..drawCircle(p(12, 8), 4 * u, paint)
          ..drawArc(Rect.fromPoints(p(4, 14), p(20, 30)), 3.4, 2.6, false, paint);
      case _Glyph.bell:
        canvas
          ..drawPath(
            Path()
              ..moveTo(5 * u, 17 * u)
              ..lineTo(6 * u, 10 * u)
              ..arcToPoint(p(18, 10), radius: Radius.circular(6 * u))
              ..lineTo(19 * u, 17 * u)
              ..close(),
            paint,
          )
          ..drawLine(p(10, 20.5), p(14, 20.5), paint);
      case _Glyph.gear:
        canvas
          ..drawCircle(p(12, 12), 3 * u, paint)
          ..drawCircle(p(12, 12), 8 * u, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => glyph != oldDelegate.glyph || color != oldDelegate.color;
}

/// Une pastille ronde `dangerFill`, nommée pour le lecteur d'écran.
Widget _dot(BuildContext context, String label) => Semantics(
  label: label,
  child: SizedBox.square(
    dimension: FlScope.of(context).space.sm * 1.25,
    child: DecoratedBox(
      decoration: ShapeDecoration(color: FlScope.of(context).colors.dangerFill, shape: const CircleBorder()),
    ),
  ),
);

/// Trois barres : trois onglets sur le premier, quatre dont un pastillé sur
/// le deuxième, cinq sur le dernier choisi.
Widget _bars(BuildContext context, {required bool rtl}) {
  FlBottomTab tab(_Glyph glyph, String fr, String ar, {Widget? badge}) =>
      FlBottomTab(icon: _Icon(glyph), label: tr(rtl, fr, ar), badge: badge);
  final home = tab(_Glyph.home, 'Home', 'الرئيسية');
  final chat = tab(_Glyph.chat, 'Messages', 'الرسائل', badge: _dot(context, tr(rtl, 'Unread', 'غير مقروءة')));
  final person = tab(_Glyph.person, 'Profile', 'الملف');
  final bell = tab(_Glyph.bell, 'Alerts', 'التنبيهات');
  final gear = tab(_Glyph.gear, 'Settings', 'الإعدادات');
  final theme = FlScope.of(context);
  return ColoredBox(
    color: theme.colors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.xl,
      children: [
        FlBottomTabBar(tabs: [home, chat, person], index: 0, onSelected: (_) {}),
        FlBottomTabBar(tabs: [home, chat, bell, person], index: 1, onSelected: (_) {}),
        FlBottomTabBar(tabs: [home, chat, bell, person, gear], index: 4, onSelected: (_) {}),
      ],
    ),
  );
}

void main() =>
    verifyItem(item: 'tab-bar', testFile: 'test/tab_bar_verify_test.dart', size: const Size(390, 400), showcase: _bars);
