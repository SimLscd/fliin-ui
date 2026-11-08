import 'dart:ui' show SemanticsRole;

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/components/menu/fl_menu.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

final _content = find.byKey(const Key('content'));
final _trigger = find.widgetWithText(FlButton, 'Filtres');

/// `DEFAULT_OFFSET` de HeroUI : l'écart entre l'ancre et le panneau.
const _gap = 9.0;

/// Un bouton qui ouvre le popover, à [at] dans la page, un bouton dans le
/// contenu pour que le focus ait où aller, et un bouton après le popover.
Widget _page(
  FlPopoverController controller, {
  AlignmentGeometry at = AlignmentDirectional.topStart,
  FlSide side = FlSide.bottom,
  FlAlign align = FlAlign.center,
  Widget? extra,
  List<String>? log,
}) => Align(
  alignment: at,
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlPopover(
          controller: controller,
          label: 'Filtres',
          side: side,
          align: align,
          content: Column(
            key: const Key('content'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Trier par date'),
              FlButton(
                label: 'Appliquer',
                onPressed: () {
                  log?.add('appliquer');
                  controller.close();
                },
              ),
              ?extra,
            ],
          ),
          child: FlButton(label: 'Filtres', onPressed: controller.toggle),
        ),
        FlButton(label: 'Suivant', onPressed: () {}),
      ],
    ),
  ),
);

Future<void> _open(WidgetTester tester, FlPopoverController controller) async {
  controller.open();
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Le panneau dessiné, sous son ombre.
Rect _panel(WidgetTester tester) => _rect(tester, find.ancestor(of: _content, matching: find.byType(FlShadow)).last);

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.ancestor(of: _content, matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

String? _focusedLabel() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FlButton>()?.label;

void main() {
  testWidgets('devrait s’ouvrir sous l’ancre, à 9 points et centré sur elle, quand le contrôleur l’ouvre', (
    tester,
  ) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, at: AlignmentDirectional.topCenter)));
    expect(_content, findsNothing);
    await _open(tester, controller);
    expect(controller.isOpen, isTrue);
    expect(_panel(tester).top, closeTo(_rect(tester, _trigger).bottom + _gap, 0.5));
    expect(_panel(tester).center.dx, closeTo(_rect(tester, _trigger).center.dx, 0.5));
  });

  testWidgets('devrait se poser du côté demandé', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, at: AlignmentDirectional.center, side: FlSide.end)));
    await _open(tester, controller);
    expect(_panel(tester).left, closeTo(_rect(tester, _trigger).right + _gap, 0.5));
  });

  testWidgets('devrait s’annoncer comme un dialogue nommé par son libellé quand il est ouvert', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    await _open(tester, controller);
    final node = tester.getSemantics(find.ancestor(of: _content, matching: find.byType(Semantics)).first);
    expect(node.getSemanticsData().role, SemanticsRole.dialog);
    expect(node.label, 'Filtres');
    semantics.dispose();
  });

  testWidgets('devrait se poser au-dessus de l’ancre quand il ne tient pas dessous', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, at: AlignmentDirectional.bottomStart)));
    await _open(tester, controller);
    expect(_panel(tester).bottom, closeTo(_rect(tester, _trigger).top - _gap, 0.5));
  });

  testWidgets('devrait aligner son bord de début sur celui de l’ancre en RTL', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, align: FlAlign.start), direction: TextDirection.rtl));
    await _open(tester, controller);
    expect(_panel(tester).right, closeTo(_rect(tester, _trigger).right, 0.5));
  });

  testWidgets('devrait se fermer au toucher en dehors et rester ouvert au toucher dedans', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    await _open(tester, controller);
    await tester.tap(find.text('Trier par date'));
    await tester.pumpAndSettle();
    expect(_content, findsOneWidget);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(_content, findsNothing);
  });

  testWidgets('devrait ignorer le toucher pendant qu’il se ferme', (tester) async {
    final log = <String>[];
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, log: log)));
    await _open(tester, controller);
    final apply = tester.getCenter(find.text('Appliquer'));
    controller.close();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_content, findsOneWidget);
    await tester.tapAt(apply);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
  });

  testWidgets('devrait se fermer et non se rouvrir quand on touche son ancre', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('devrait rester ouvert quand on choisit l’action d’un menu ouvert depuis son contenu', (tester) async {
    final log = <String>[];
    final controller = FlPopoverController();
    await tester.pumpWidget(
      overlayApp(
        _page(
          controller,
          extra: FlMenu(
            items: [FlMenuItem(label: 'Trier', onPressed: () => log.add('trier'))],
            builder: (context, menu) => FlButton(label: 'Ordre', onPressed: menu.open),
          ),
        ),
      ),
    );
    await _open(tester, controller);
    await tester.tap(find.text('Ordre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trier'));
    await tester.pumpAndSettle();
    expect(log, ['trier']);
    expect(controller.isOpen, isTrue);
  });

  testWidgets('devrait rester ouvert quand on touche un popover ouvert depuis son contenu', (tester) async {
    final controller = FlPopoverController();
    final inner = FlPopoverController();
    await tester.pumpWidget(
      overlayApp(
        _page(
          controller,
          extra: FlPopover(
            controller: inner,
            label: 'Détail',
            content: const Text('Plus récent'),
            child: FlButton(label: 'Détail', onPressed: inner.open),
          ),
        ),
      ),
    );
    await _open(tester, controller);
    await tester.tap(find.text('Détail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus récent'));
    await tester.pumpAndSettle();
    expect(inner.isOpen, isTrue);
    expect(controller.isOpen, isTrue);
  });

  testWidgets('devrait se fermer quand son ancre défile hors de l’écran', (tester) async {
    final controller = FlPopoverController();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      overlayApp(ListView(controller: scroll, children: [_page(controller), const SizedBox(height: 2000)])),
    );
    await _open(tester, controller);
    scroll.jumpTo(60);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(_panel(tester).top, closeTo(_rect(tester, _trigger).bottom + _gap, 0.5));
    scroll.jumpTo(400);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(_content, findsNothing);
  });

  testWidgets('devrait prendre le focus à l’ouverture, se fermer à Échap et rendre le focus à l’ancre', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final anchor = FocusManager.instance.primaryFocus;
    expect(_focusedLabel(), 'Filtres');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(FocusScope.of(tester.element(_content)).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), 'Appliquer');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, anchor);
    await tester.pumpAndSettle();
    expect(_content, findsNothing);
  });

  testWidgets('devrait se fermer quand Tab sort du popover, sans retenir le focus', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), 'Appliquer');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(_focusedLabel(), isNot('Appliquer'));
  });

  testWidgets('devrait rester ouvert, le focus dans le panneau, quand la vue reprend le focus comme sous Flutter web', (
    tester,
  ) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayView(_page(controller)));
    await _open(tester, controller);
    await regainViewFocus(tester);
    expect(controller.isOpen, isTrue);
    expect(_content, findsOneWidget);
    expect(FocusScope.of(tester.element(_content)).hasFocus, isTrue);
  });

  testWidgets('devrait partir de l’ancre et se fondre à l’ouverture quand le mouvement n’est pas réduit', (
    tester,
  ) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller)));
    controller.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final settled = _rect(tester, _trigger).bottom + _gap;
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_panel(tester).top, lessThan(settled - 0.5));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(_panel(tester).top, closeTo(settled, 0.5));
  });

  testWidgets('devrait apparaître en fondu sans se déplacer quand le mouvement est réduit', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller), disableAnimations: true));
    controller.open();
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short4 ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_panel(tester).top, closeTo(_rect(tester, _trigger).bottom + _gap, 0.5));
    await tester.pump(FlTokens.defaults.motion.short4 ~/ 2);
    expect(_opacity(tester), 1);
  });

  testWidgets('devrait rester à 12 points du bord quand l’ancre est contre lui', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(overlayApp(_page(controller, align: FlAlign.end)));
    await _open(tester, controller);
    expect(_panel(tester).left, closeTo(12, 0.5));
  });

  testWidgets('devrait montrer titre et texte, et se fermer par son bouton de fermeture', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(
      overlayApp(
        Center(
          child: FlPopover(
            controller: controller,
            label: 'Aide',
            title: 'Information',
            description: 'Lire la documentation.',
            closeLabel: 'Fermer',
            child: FlButton(label: 'Aide', onPressed: controller.toggle),
          ),
        ),
      ),
    );
    await _open(tester, controller);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('Lire la documentation.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(find.text('Information'), findsNothing);
  });

  for (final title in ['Information', null]) {
    testWidgets(
      'devrait laisser la place du bouton de fermeture au texte quand le titre est ${title == null ? 'absent' : 'plus bas que le bouton'}',
      (tester) async {
        final controller = FlPopoverController();
        await tester.pumpWidget(
          overlayApp(
            Center(
              child: FlPopover(
                controller: controller,
                label: 'Aide',
                title: title,
                description: 'Lire la documentation avant de commencer, puis revenir ici pour la suite.',
                closeLabel: 'Fermer',
                width: 280,
                child: FlButton(label: 'Aide', onPressed: controller.toggle),
              ),
            ),
          ),
        );
        await _open(tester, controller);
        final close = _rect(tester, find.byType(FlCloseButton));
        final text = _rect(tester, find.byType(FlPopoverDescription));
        expect(close.overlaps(text), isFalse, reason: 'bouton $close, texte $text');
      },
    );
  }

  testWidgets('devrait s’ouvrir dans une feuille du bas quand la présentation est sheet', (tester) async {
    final controller = FlPopoverController();
    await tester.pumpWidget(
      overlayApp(
        Center(
          child: FlPopover(
            controller: controller,
            label: 'Aide',
            title: 'Information',
            presentation: FlPopoverPresentation.sheet,
            barrierLabel: 'Fermer la feuille',
            content: const Text('Contenu'),
            child: FlButton(label: 'Aide', onPressed: controller.toggle),
          ),
        ),
      ),
    );
    await _open(tester, controller);
    expect(controller.isOpen, isTrue);
    expect(find.text('Contenu'), findsOneWidget);
    expect(find.ancestor(of: find.text('Contenu'), matching: find.byType(FlSheet)), findsOneWidget);
    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(find.text('Contenu'), findsNothing);
  });

  testWidgets('devrait laisser le focus à l’ancre et ne pas s’annoncer comme un dialogue quand takesFocus est faux', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = FlPopoverController();
    final anchor = FocusNode();
    addTearDown(anchor.dispose);
    await tester.pumpWidget(
      overlayApp(
        FlPopover(
          controller: controller,
          label: 'Suggestions',
          takesFocus: false,
          content: Column(
            key: const Key('content'),
            mainAxisSize: MainAxisSize.min,
            children: [FlButton(label: 'Paris', onPressed: () {})],
          ),
          child: Focus(focusNode: anchor, child: const SizedBox(width: 200, height: 40)),
        ),
      ),
    );
    anchor.requestFocus();
    await tester.pump();
    await _open(tester, controller);
    expect(anchor.hasPrimaryFocus, isTrue);
    expect(controller.isOpen, isTrue);
    final node = tester.getSemantics(find.ancestor(of: _content, matching: find.byType(Semantics)).first);
    expect(node.getSemanticsData().role, SemanticsRole.none);
    expect(node.label, 'Suggestions');
    await regainViewFocus(tester);
    expect(anchor.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), isNull, reason: 'Tab ne passe pas dans le panneau');
    semantics.dispose();
  });

  testWidgets('devrait poser le contenu à space.md sous le titre et le texte, et collé en haut sans eux', (
    tester,
  ) async {
    for (final title in [null, 'Filtres']) {
      final controller = FlPopoverController();
      await tester.pumpWidget(
        overlayApp(
          Center(
            child: FlPopover(
              key: ValueKey(title),
              controller: controller,
              label: 'Filtres',
              title: title,
              description: title == null ? null : 'Les plus récents',
              content: const SizedBox(key: Key('body'), width: 120, height: 20),
              child: FlButton(label: 'Ouvrir', onPressed: controller.toggle),
            ),
          ),
        ),
      );
      await _open(tester, controller);
      final body = tester.getRect(find.byKey(const Key('body')));
      if (title == null) {
        final panel = tester.getRect(
          find.ancestor(of: find.byKey(const Key('body')), matching: find.byType(FlShadow)).last,
        );
        // The panel's padding, inside its hairline (Yoga counts the border in the box).
        expect(body.top - panel.top, FlTokens.defaults.space.lg + FlTokens.defaults.size.border);
      } else {
        expect(body.top - tester.getRect(find.text('Les plus récents')).bottom, FlTokens.defaults.space.md);
      }
    }
  });
}
