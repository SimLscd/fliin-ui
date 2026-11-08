import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

void main() {
  /// [control] seul dans une colonne étirée de 300 de large.
  Widget stretched(Widget control) => SizedBox(
    width: 300,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [control],
    ),
  );

  final size = FlTokens.defaults.size;

  testWidgets(
    'devrait garder sa taille propre, au début de la ligne, quand un interrupteur est seul dans une colonne étirée',
    (tester) async {
      await tester.pumpWidget(
        toggleApp(
          stretched(FlSwitch(value: true, label: 'Wi-Fi', onChanged: (_) {})),
        ),
      );
      final box = tester.getRect(controlOf(find.byType(FlSwitch)));
      expect(box.size, Size(size.switchWidth, size.switchHeight));
      expect(box.left, tester.getRect(find.byType(Column)).left);
    },
  );

  testWidgets(
    'devrait finir à droite quand un interrupteur est seul dans une colonne étirée de droite à gauche',
    (tester) async {
      await tester.pumpWidget(
        toggleApp(
          stretched(FlSwitch(value: true, label: 'Wi-Fi', onChanged: (_) {})),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getRect(controlOf(find.byType(FlSwitch))).right,
        tester.getRect(find.byType(Column)).right,
      );
    },
  );

  testWidgets(
    'devrait garder leur taille propre quand une case ou un radio est seul dans une colonne étirée',
    (tester) async {
      await tester.pumpWidget(
        toggleApp(
          stretched(
            FlCheckbox(value: true, label: 'Conditions', onChanged: (_) {}),
          ),
        ),
      );
      expect(
        tester.getSize(controlOf(find.byType(FlCheckbox))),
        Size.square(size.toggle),
      );
      await tester.pumpWidget(
        toggleApp(
          stretched(
            RadioGroup<int>(
              groupValue: 1,
              onChanged: (_) {},
              child: const FlRadio<int>(value: 1, label: 'Un'),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(controlOf(find.byType(FlRadio<int>))),
        Size.square(size.toggle),
      );
    },
  );
}
