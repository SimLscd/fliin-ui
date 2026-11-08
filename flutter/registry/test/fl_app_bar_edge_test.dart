import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'devrait garder la cible du retour et de l’action dans l’écran quand la barre touche ses bords en densité '
        'compacte, ${platform.name} ${direction.name}',
        (tester) async {
          tester.view.physicalSize = const Size(390, 200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            Directionality(
              textDirection: direction,
              child: FlScope(
                tokens: tortureB,
                density: FlDensity.compact,
                brightness: Brightness.light,
                platform: platform,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FlAppBar(
                    title: 'Léa',
                    back: FlAppBarBack(label: 'Retour', onPressed: () {}),
                    actions: [FlAppBarAction.text(label: 'Nouveau', onPressed: () {})],
                  ),
                ),
              ),
            ),
          );
          final target = platform == TargetPlatform.iOS ? 44.0 : 48.0;
          for (final label in ['Retour', 'Nouveau']) {
            final rect = tester.getSemantics(find.bySemanticsLabel(label)).rect;
            final global = MatrixUtils.transformRect(
              tester.renderObject(find.bySemanticsLabel(label)).getTransformTo(null),
              rect,
            );
            expect(global.width, greaterThanOrEqualTo(target), reason: label);
            expect(global.height, greaterThanOrEqualTo(target), reason: label);
            expect(global.left, greaterThanOrEqualTo(0), reason: label);
            expect(global.right, lessThanOrEqualTo(390), reason: label);
          }
          semantics.dispose();
        },
      );
    }
  }
}
