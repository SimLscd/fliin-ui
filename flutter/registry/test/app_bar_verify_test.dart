import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une croix ou trois points à la couleur et à la taille de l'`IconTheme`.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.dots});

  final bool dots;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(icon.size!),
      painter: _GlyphPainter(icon.color!, dots: dots),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color, {required this.dots});

  final Color color;
  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width / 10
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    if (dots) {
      for (final dx in [-0.3, 0.0, 0.3]) {
        canvas.drawCircle(c + Offset(dx * size.width, 0), size.width / 12, paint);
      }
    } else {
      canvas
        ..drawLine(c - Offset(0, size.height * 0.35), c + Offset(0, size.height * 0.35), paint)
        ..drawLine(c - Offset(size.width * 0.35, 0), c + Offset(size.width * 0.35, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// La barre `inline` au repos avec son retour et deux actions, une barre à
/// action écrite (« Enregistrer »), le grand titre déplié, puis la même barre
/// repliée sur une liste passée dessous.
Widget _bars(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final back = FlAppBarBack(label: tr(rtl, 'Back', 'رجوع'), onPressed: () {});
  final actions = [
    FlAppBarAction(icon: const _Glyph(dots: false), label: tr(rtl, 'New', 'جديد'), onPressed: () {}),
    FlAppBarAction(icon: const _Glyph(dots: true), label: tr(rtl, 'Options', 'خيارات'), onPressed: () {}),
  ];
  FlAppBar large() => FlAppBar(
    title: tr(rtl, 'Messages', 'الرسائل'),
    titleSize: FlAppBarTitleSize.large,
    back: back,
    actions: actions.sublist(0, 1),
  );
  return ColoredBox(
    color: theme.colors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.xl,
      children: [
        FlAppBar(title: tr(rtl, 'Settings', 'الإعدادات'), back: back, actions: actions),
        FlAppBar(title: tr(rtl, 'Product', 'المنتج'), filled: false, back: back, actions: actions),
        FlAppBar(
          title: tr(rtl, 'Profile', 'الملف الشخصي'),
          titleSize: FlAppBarTitleSize.small,
          back: back,
          actions: [FlAppBarAction.text(label: tr(rtl, 'Save', 'حفظ'), onPressed: () {})],
        ),
        large(),
        SizedBox(
          height: 220,
          child: Viewport(
            offset: ViewportOffset.fixed(160),
            slivers: [
              FlSliverAppBar(appBar: large()),
              SliverList.list(
                children: [
                  // Des blocs muets : une ligne pressable à demi passée sous la
                  // barre aurait une cible coupée par elle.
                  for (var i = 0; i < 12; i++)
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.lg, vertical: theme.space.xs),
                      child: SizedBox(
                        height: 40,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: theme.colors.surfaceSecondary,
                            shape: FlContinuousBorder(radius: theme.shape.radiusMd),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() =>
    verifyItem(item: 'app-bar', testFile: 'test/app_bar_verify_test.dart', size: const Size(390, 720), showcase: _bars);
