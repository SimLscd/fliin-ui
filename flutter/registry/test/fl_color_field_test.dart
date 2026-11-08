import 'package:fliin_ui/components/color_field/fl_color_field.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un champ de couleur que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({super.key, this.initial = const Color(0xFF0485F7), this.alpha = false, this.required = false});

  final Color? initial;
  final bool alpha;
  final bool required;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Color? value = widget.initial;
  final changes = <Color?>[];

  @override
  Widget build(BuildContext context) => Overlay(
    initialEntries: [OverlayEntry(builder: (context) => Center(child: _field()))],
  );

  Widget _field() => SizedBox(
    width: 300,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlColorField(
          label: 'Couleur',
          value: value,
          alpha: widget.alpha,
          required: widget.required,
          onChanged: (next) => setState(() {
            changes.add(next);
            value = next;
          }),
        ),
        const Focus(child: SizedBox.square(dimension: 10)),
      ],
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

String _text(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

Future<void> _leave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

void main() {
  testWidgets('devrait écrire la couleur en #RRGGBB, sa pastille au début du champ', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(_text(tester), '#0485F7');
    expect(tester.widget<FlColorSwatch>(find.byType(FlColorSwatch)).color, const Color(0xFF0485F7));
  });

  testWidgets('devrait rendre une couleur tapée dès qu’elle en est une, puis la réécrire en entier au départ', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.enterText(find.byType(EditableText), '#0a6c');
    await tester.pump();
    expect(_host(tester).changes, isEmpty, reason: 'cinq chiffres ne sont pas une couleur');
    await tester.enterText(find.byType(EditableText), '#0a6cff');
    await tester.pump();
    expect(_host(tester).changes, [const Color(0xFF0A6CFF)]);
    expect(_text(tester), '#0a6cff', reason: 'le texte en cours n’est pas réécrit');
    expect(tester.widget<FlColorSwatch>(find.byType(FlColorSwatch)).color, const Color(0xFF0A6CFF));
    await _leave(tester);
    expect(_text(tester), '#0A6CFF');
  });

  testWidgets('devrait rendre la couleur précédente quand le texte n’en est pas une au départ', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.enterText(find.byType(EditableText), 'bleu');
    await _leave(tester);
    expect(_text(tester), '#0485F7');
    expect(_host(tester).changes, isEmpty);
  });

  testWidgets('devrait rendre null quand le champ est vidé, sauf s’il est requis', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.enterText(find.byType(EditableText), '');
    await _leave(tester);
    expect(_host(tester).changes, [null]);
    expect(find.byType(FlColorSwatch), findsNothing);

    await tester.pumpWidget(toggleApp(const _Host(key: ValueKey('requis'), required: true)));
    await tester.enterText(find.byType(EditableText), '');
    await _leave(tester);
    expect(_text(tester), '#0485F7');
  });

  testWidgets('devrait lire et écrire l’opacité avec alpha', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(initial: Color(0x800485F7), alpha: true)));
    expect(_text(tester), '#0485F780');
    await tester.enterText(find.byType(EditableText), '#FF000040');
    await tester.pump();
    expect(_host(tester).changes, [const Color(0x40FF0000)]);
  });

  testWidgets('devrait remplacer le texte quand le parent change la couleur', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final state = _host(tester);
    // ignore: invalid_use_of_protected_member
    state.setState(() => state.value = const Color(0xFF13BA82));
    await tester.pump();
    expect(_text(tester), '#13BA82');
  });

  testWidgets('devrait écrire le code de gauche à droite sur une page arabe', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    expect(Directionality.of(tester.element(find.byType(EditableText))), TextDirection.ltr);
  });
}
