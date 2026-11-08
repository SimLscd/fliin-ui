import 'package:fliin_ui/components/scroll_shadow/fl_scroll_shadow.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une liste verticale défilée au milieu (deux ombres), puis une rangée
/// horizontale au début (l'ombre de fin seule, à gauche en RTL). Des blocs
/// sans texte : le texte fondu sous une ombre ferait échouer le contraste.
Widget _shadows(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  Widget block({double? width}) => SizedBox(
    width: width,
    height: 40,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceSecondary,
        borderRadius: BorderRadius.all(Radius.circular(theme.shape.radiusMd)),
      ),
    ),
  );
  return columnPage(context, [
    SizedBox(
      height: 160,
      child: FlScrollShadow(
        child: ListView(
          controller: ScrollController(initialScrollOffset: 80),
          children: [
            for (var i = 0; i < 8; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(bottom: theme.space.sm),
                child: block(),
              ),
          ],
        ),
      ),
    ),
    SizedBox(
      height: 40,
      child: FlScrollShadow(
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < 8; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(end: theme.space.sm),
                child: block(width: 96),
              ),
          ],
        ),
      ),
    ),
  ]);
}

void main() => verifyItem(
  item: 'scroll-shadow',
  testFile: 'test/scroll_shadow_verify_test.dart',
  size: const Size(390, 280),
  settle: const Duration(milliseconds: 400),
  showcase: _shadows,
);
