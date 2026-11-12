import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/select/fl_select.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

FlTokens get _tokens => FlTokens.defaults;

const _fruits = [
  FlSelectOption(value: 'pomme', label: 'Pomme'),
  FlSelectOption(value: 'poire', label: 'Poire', description: 'Juteuse'),
  FlSelectOption(value: 'kiwi', label: 'Kiwi'),
];

/// Un select de fruits sur 280 de large, centré en haut de la page, qui
/// garde son choix.
Widget _select({
  String? value,
  bool enabled = true,
  FlSelectPresentation presentation = FlSelectPresentation.popover,
  FlSelectController? controller,
  List<String>? log,
}) {
  var current = value;
  return StatefulBuilder(
    builder: (context, setState) => Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: SizedBox(
          width: 280,
          child: FlSelect<String>(
            label: 'Fruit',
            placeholder: 'Choisir un fruit',
            listLabel: 'Fruits',
            options: _fruits,
            presentation: presentation,
            barrierLabel: presentation == FlSelectPresentation.popover ? null : 'Fermer',
            controller: controller,
            selection: FlSingleSelection(
              value: current,
              onChanged: enabled
                  ? (fruit) {
                      log?.add(fruit);
                      setState(() => current = fruit);
                    }
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
}

final _trigger = find.byType(FlSelect<String>);
final _pressable = find.descendant(of: _trigger, matching: find.byType(FlPressable)).first;

Color? _color(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text).first)).style.color;

void main() {
  testWidgets('devrait montrer le placeholder atténué sans choix, et le libellé de l’option choisie', (tester) async {
    await tester.pumpWidget(overlayApp(_select()));
    expect(_color(tester, 'Choisir un fruit'), _tokens.light.fieldPlaceholder);
    await tester.pumpWidget(overlayApp(_select(value: 'poire')));
    expect(find.text('Poire'), findsOneWidget);
    expect(_color(tester, 'Poire'), _tokens.light.onSurface);
  });

  testWidgets('devrait poser le déclencheur blanc et ombré sans contour et cocher l’option choisie en selected', (
    tester,
  ) async {
    await tester.pumpWidget(overlayApp(_select(value: 'poire')));
    final box = tester.widget<DecoratedBox>(find.descendant(of: _trigger, matching: find.byType(DecoratedBox)).first);
    final decoration = box.decoration as ShapeDecoration;
    expect(decoration.color, _tokens.light.field);
    expect((decoration.shape as FlContinuousBorder).side, BorderSide.none);
    final shadow = tester.widget<FlShadow>(find.descendant(of: _trigger, matching: find.byType(FlShadow)).first);
    expect(shadow.layers, _tokens.shadow.light.field);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    final check = find.descendant(
      of: find.ancestor(of: find.text('Juteuse'), matching: find.byType(Row)).first,
      matching: find.byType(FlIcon),
    );
    expect(tester.widget<FlIcon>(check).color, _tokens.light.selected);
  });

  testWidgets('devrait ouvrir la liste à 8 points sous le déclencheur, à sa largeur', (tester) async {
    await tester.pumpWidget(overlayApp(_select(value: 'pomme')));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    final list = tester.getRect(find.ancestor(of: find.text('Kiwi'), matching: find.byType(FlShadow)).last);
    final trigger = tester.getRect(_trigger);
    expect(list.top, closeTo(trigger.bottom + 8, 0.5));
    expect(list.width, closeTo(trigger.width, 0.5));
    expect(find.text('Fruits'), findsOneWidget);
  });

  testWidgets('devrait rendre l’option touchée, se fermer et rendre le focus au déclencheur', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_select(log: log)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final trigger = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();
    expect(log, ['kiwi']);
    expect(find.text('Fruits'), findsNothing);
    expect(find.text('Kiwi'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(trigger));
  });

  testWidgets('devrait se fermer à Échap', (tester) async {
    await tester.pumpWidget(overlayApp(_select()));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Fruits'), findsNothing);
  });

  testWidgets('devrait tourner son chevron d’un demi-tour ouvert, et s’annoncer déplié', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_select(value: 'pomme')));
    expect(
      tester.getSemantics(_pressable),
      isSemantics(label: 'Fruit', value: 'Pomme', isExpanded: false, hasExpandedState: true),
    );
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    final turns = tester.widget<RotationTransition>(
      find.descendant(of: _trigger, matching: find.byType(RotationTransition)),
    );
    expect(turns.turns.value, closeTo(-0.5, 0.01));
    expect(tester.getSemantics(_pressable), isSemantics(label: 'Fruit', isExpanded: true, hasExpandedState: true));
    semantics.dispose();
  });

  testWidgets('devrait cocher et décocher plusieurs options sans se fermer, et les montrer jointes', (tester) async {
    var fruits = <String>{'pomme'};
    await tester.pumpWidget(
      overlayApp(
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 280,
              child: FlSelect<String>(
                label: 'Fruits',
                placeholder: 'Choisir',
                options: _fruits,
                selection: FlMultipleSelection(values: fruits, onChanged: (value) => setState(() => fruits = value)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();
    expect(fruits, {'pomme', 'kiwi'});
    expect(find.text('Pomme, Kiwi'), findsOneWidget);
    await tester.tap(find.text('Pomme').last);
    await tester.pumpAndSettle();
    expect(fruits, {'kiwi'});
    expect(find.text('Poire'), findsOneWidget);
  });

  testWidgets('devrait rester fermé et pâlir quand il est désactivé', (tester) async {
    await tester.pumpWidget(overlayApp(_select(enabled: false)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.text('Fruits'), findsNothing);
    final opacity = tester.widget<Opacity>(find.descendant(of: _trigger, matching: find.byType(Opacity)).first);
    expect(opacity.opacity, _tokens.size.disabledOpacity);
  });

  testWidgets('devrait s’ouvrir et se fermer par son contrôleur', (tester) async {
    final controller = FlSelectController();
    await tester.pumpWidget(overlayApp(_select(controller: controller)));
    controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(find.text('Fruits'), findsOneWidget);
    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(find.text('Fruits'), findsNothing);
  });

  testWidgets('devrait présenter ses options dans une feuille du bas, et la fermer au choix', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_select(presentation: FlSelectPresentation.sheet, log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.text('Kiwi'), matching: find.byType(FlSheet)), findsOneWidget);
    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();
    expect(log, ['kiwi']);
    expect(find.byType(FlSheet), findsNothing);
  });

  testWidgets('devrait présenter ses options dans un dialogue, et le fermer au choix', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_select(presentation: FlSelectPresentation.dialog, log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.text('Fruits'), findsOneWidget);
    await tester.tap(find.text('Poire'));
    await tester.pumpAndSettle();
    expect(log, ['poire']);
    expect(find.text('Fruits'), findsNothing);
  });

  testWidgets('devrait faire défiler trente options dans la place sous le déclencheur, sans déborder', (tester) async {
    int? chosen;
    await tester.pumpWidget(
      overlayApp(
        Align(
          alignment: AlignmentDirectional.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: SizedBox(
              width: 280,
              child: FlSelect<int>(
                label: 'Numéro',
                placeholder: 'Choisir',
                options: [for (var i = 0; i < 30; i++) FlSelectOption(value: i, label: 'Option $i')],
                selection: FlSingleSelection(value: null, onChanged: (value) => chosen = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FlSelect<int>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = tester.getRect(find.ancestor(of: find.text('Option 0'), matching: find.byType(FlShadow)).last);
    expect(list.top, greaterThan(tester.getRect(find.byType(FlSelect<int>)).bottom));
    expect(list.bottom, lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio));
    await tester.scrollUntilVisible(find.text('Option 29'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Option 29'));
    await tester.pumpAndSettle();
    expect(chosen, 29);
  });

  testWidgets('devrait passer d’une option à l’autre aux flèches, et aller aux extrémités par Début et Fin', (
    tester,
  ) async {
    await tester.pumpWidget(overlayApp(_select()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    String? focused() {
      String? found;
      void visit(Element element) {
        if (found != null) return;
        if (element.widget case Semantics(:final properties) when properties.label != null) {
          found = properties.label;
          return;
        }
        element.visitChildren(visit);
      }

      final context = FocusManager.instance.primaryFocus?.context;
      if (context is Element) visit(context);
      return found;
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'Pomme');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), startsWith('Poire'));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(), 'Kiwi');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'Kiwi');
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(), 'Pomme');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(), 'Pomme');
  });

  testWidgets('devrait annoncer une valeur vide et le placeholder en indice sans choix', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_select()));
    final node = tester.getSemantics(_pressable).getSemanticsData();
    expect((node.label, node.value, node.hint), ('Fruit', '', 'Choisir un fruit'));
    semantics.dispose();
  });

  testWidgets('devrait écrire helper sous le déclencheur, puis error à sa place avec un anneau danger', (tester) async {
    Widget select({String? error}) => Align(
      alignment: AlignmentDirectional.topCenter,
      child: SizedBox(
        width: 280,
        child: FlSelect<String>(
          label: 'Fruit',
          showLabel: true,
          required: true,
          placeholder: 'Choisir un fruit',
          helper: 'Pour la livraison',
          error: error,
          options: _fruits,
          selection: FlSingleSelection(value: null, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpWidget(overlayApp(select()));
    final frame = find.descendant(of: _trigger, matching: find.byType(FlInputFrame));
    expect(tester.getRect(find.text('Pour la livraison')).top, greaterThan(tester.getRect(frame).bottom));
    expect(
      tester.renderObject<RenderParagraph>(find.text('Pour la livraison')).text.style?.color,
      _tokens.light.onSurfaceMuted,
    );
    expect(tester.widget<FlInputFrame>(frame).invalid, isFalse);
    expect(tester.widget<FlLabel>(find.byType(FlLabel)).required, isTrue);
    await tester.pumpWidget(overlayApp(select(error: 'Choisissez un fruit')));
    await tester.pumpAndSettle();
    expect(find.text('Pour la livraison'), findsNothing);
    expect(find.text('Choisissez un fruit'), findsOneWidget);
    expect(tester.widget<FlInputFrame>(frame).invalid, isTrue);
  });

  testWidgets('devrait montrer le leading de l’option dans sa ligne et, choisie, dans le déclencheur', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        Align(
          alignment: AlignmentDirectional.topCenter,
          child: SizedBox(
            width: 280,
            child: FlSelect<String>(
              label: 'Livraison',
              placeholder: 'Choisir',
              options: const [
                FlSelectOption(
                  value: 'home',
                  label: 'Domicile',
                  leading: SizedBox(key: Key('home'), width: 16, height: 16),
                ),
                FlSelectOption(
                  value: 'shop',
                  label: 'Magasin',
                  leading: SizedBox(key: Key('shop'), width: 16, height: 16),
                ),
              ],
              selection: FlSingleSelection(value: 'home', onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(find.byKey(const Key('shop')), findsNothing);
    expect(tester.getRect(find.byKey(const Key('home'))).right, lessThan(tester.getRect(find.text('Domicile')).left));
    await tester.tap(_pressable);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop')), findsOneWidget);
    expect(find.byKey(const Key('home')), findsNWidgets(2));
  });
}
