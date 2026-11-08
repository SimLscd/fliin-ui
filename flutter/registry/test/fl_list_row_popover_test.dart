import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

const _row = SizedBox(
  width: 280,
  child: FlListRow(key: Key('row'), title: 'Paris', subtitle: 'Nord', value: '75', trailing: Text('3')),
);

/// La ligne dans le contenu d'un popover ouvert, et la même dans la page.
Widget _page(FlPopoverController controller) => Align(
  alignment: AlignmentDirectional.topStart,
  child: SizedBox(
    width: 280,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FlListRow(key: Key('page'), title: 'Paris', subtitle: 'Nord', value: '75', trailing: Text('3')),
        FlPopover(
          controller: controller,
          label: 'Villes',
          content: _row,
          child: FlButton(label: 'Villes', onPressed: controller.toggle),
        ),
      ],
    ),
  ),
);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets("devrait garder l'interligne de la ligne dans le contenu d'un popover, qui pose un interligne de 1,5, "
        'sous ${platform.name}', (tester) async {
      final controller = FlPopoverController();
      await tester.pumpWidget(overlayApp(_page(controller), platform: platform));
      controller.open();
      await tester.pumpAndSettle();

      Finder inRow(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
      for (final text in ['Paris', 'Nord', '75', '3']) {
        expect(tester.getSize(inRow('row', text)), tester.getSize(inRow('page', text)), reason: text);
      }
      expect(tester.getSize(inRow('row', 'Nord')).height, 20);
      expect(tester.getSize(find.byKey(const Key('row'))), tester.getSize(find.byKey(const Key('page'))));
    });
  }
}
