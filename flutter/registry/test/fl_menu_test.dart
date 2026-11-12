import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/menu/fl_menu.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

final _trigger = find.widgetWithText(FlButton, 'Options');

FlTokens get _tokens => FlTokens.defaults;

Widget _menu(List<String> log) => Align(
  alignment: AlignmentDirectional.topStart,
  child: Padding(
    padding: const EdgeInsetsDirectional.all(40),
    child: FlMenu(
      items: [
        FlMenuItem(label: 'Copier', onPressed: () => log.add('copier')),
        const FlMenuItem(label: 'Coller', onPressed: null),
        FlMenuItem(label: 'Dupliquer', onPressed: () => log.add('dupliquer')),
        const FlMenuDivider(),
        FlSubmenu(
          label: 'Partager',
          items: [
            FlMenuItem(label: 'Par e-mail', onPressed: () => log.add('e-mail')),
            FlMenuItem(label: 'Par message', onPressed: () => log.add('message')),
          ],
        ),
        FlMenuItem(label: 'Supprimer', destructive: true, onPressed: () => log.add('supprimer')),
      ],
      builder: (context, controller) =>
          FlButton(label: 'Options', onPressed: () => controller.isOpen ? controller.close() : controller.open()),
    ),
  ),
);

/// Le premier texte de ce qui a le focus : une ligne de menu, le bouton.
String? _focusedLabel() {
  String? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget case Text(:final data?)) {
      found = data;
      return;
    }
    element.visitChildren(visit);
  }

  final context = FocusManager.instance.primaryFocus?.context;
  if (context is Element) visit(context);
  return found;
}

Color? _textColor(WidgetTester tester, String label) =>
    DefaultTextStyle.of(tester.element(find.text(label))).style.color;

/// L'opacité où se peint [label] : le produit de celles qui l'entourent.
double _opacity(WidgetTester tester, String label) => tester
    .widgetList<Opacity>(find.ancestor(of: find.text(label).first, matching: find.byType(Opacity)))
    .fold(1, (product, opacity) => product * opacity.opacity);

Future<void> _openByTap(WidgetTester tester) async {
  await tester.tap(_trigger);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('devrait s’ouvrir sous le bouton au toucher, à 9 points de lui', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    expect(find.text('Copier'), findsNothing);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.ancestor(of: find.text('Copier'), matching: find.byType(FlShadow)).last);
    expect(menu.top, closeTo(tester.getRect(_trigger).bottom + 9, 0.5));
    expect(menu.width, greaterThanOrEqualTo(_tokens.size.menuMinWidth));
  });

  testWidgets('devrait s’annoncer comme un menu d’éléments, l’élément sans action désactivé', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_menu([])));
    await _openByTap(tester);
    final copy = tester.getSemantics(find.text('Copier'));
    expect(
      copy,
      isSemantics(role: SemanticsRole.menuItem, label: 'Copier', isButton: true, isEnabled: true, hasTapAction: true),
    );
    expect(tester.getSemantics(find.text('Coller')), isSemantics(label: 'Coller', isEnabled: false));
    expect(
      tester.getSemantics(find.text('Partager')),
      isSemantics(label: 'Partager', hasExpandedState: true, isExpanded: false),
    );
    var parent = copy.parent;
    while (parent != null && parent.getSemanticsData().role != SemanticsRole.menu) {
      parent = parent.parent;
    }
    expect(parent, isNotNull);
    semantics.dispose();
  });

  testWidgets('devrait fermer le menu puis exécuter l’action choisie', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_menu(log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dupliquer'));
    await tester.pumpAndSettle();
    expect(log, ['dupliquer']);
    expect(find.text('Copier'), findsNothing);
  });

  testWidgets('devrait ignorer le toucher sur un élément désactivé', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_menu(log)));
    await _openByTap(tester);
    await tester.tap(find.text('Coller'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('Coller'), findsOneWidget);
  });

  testWidgets('devrait écrire l’action destructive en danger et pâlir la désactivée', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await _openByTap(tester);
    expect(_textColor(tester, 'Supprimer'), _tokens.light.danger);
    expect(_textColor(tester, 'Copier'), _tokens.light.onSurface);
    expect(_opacity(tester, 'Coller'), _tokens.size.disabledOpacity);
    expect(_opacity(tester, 'Copier'), 1);
  });

  testWidgets('devrait se fermer au toucher en dehors', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.text('Copier'), findsNothing);
  });

  testWidgets(
    'devrait focaliser la première action, passer la désactivée aux flèches et rendre le focus au bouton à Échap',
    (tester) async {
      await tester.pumpWidget(overlayApp(_menu([])));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), 'Options');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_focusedLabel(), 'Copier');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Dupliquer');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'Copier');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_focusedLabel(), 'Options');
      await tester.pumpAndSettle();
      expect(find.text('Copier'), findsNothing);
    },
  );

  testWidgets(
    'devrait garder le focus sur sa ligne, au menu comme au sous-menu, quand la vue reprend le focus comme sous Flutter web',
    (tester) async {
      await tester.pumpWidget(overlayView(_menu([])));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(_focusedLabel(), 'Copier');
      await regainViewFocus(tester);
      expect(_focusedLabel(), 'Copier');
      await tester.tap(find.text('Partager'));
      await tester.pumpAndSettle();
      expect(_focusedLabel(), 'Par e-mail');
      await regainViewFocus(tester);
      expect(_focusedLabel(), 'Par e-mail');
    },
  );

  testWidgets('devrait garder Tab dans le menu ouvert', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.enter);
    for (var i = 0; i < 6; i++) {
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), isNot('Options'));
    }
  });

  testWidgets('devrait déplier le sous-menu sous sa ligne et exécuter son action en fermant tout', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_menu(log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partager'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Par e-mail')).top, greaterThan(tester.getRect(find.text('Partager').last).bottom));
    expect(_opacity(tester, 'Copier'), 0.4);
    await tester.tap(find.text('Par message'));
    await tester.pumpAndSettle();
    expect(log, ['message']);
    expect(find.text('Copier'), findsNothing);
    expect(find.text('Par e-mail'), findsNothing);
  });

  testWidgets('devrait replier le sous-menu au toucher du menu hors de sa carte, le menu restant ouvert', (
    tester,
  ) async {
    await tester.pumpWidget(overlayApp(_menu([]), direction: TextDirection.rtl));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partager'));
    await tester.pumpAndSettle();
    expect(find.text('Par e-mail'), findsOneWidget);
    await tester.tap(find.text('Copier'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Par e-mail'), findsNothing);
    expect(find.text('Copier'), findsOneWidget);
    expect(_opacity(tester, 'Copier'), 1);
  });

  testWidgets(
    'devrait ouvrir le sous-menu à la flèche de fin et le refermer à la flèche de début en rendant le focus',
    (tester) async {
      await tester.pumpWidget(overlayApp(_menu([])));
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.enter);
      for (var i = 0; i < 2; i++) {
        await _key(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_focusedLabel(), 'Partager');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focusedLabel(), 'Par e-mail');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Par e-mail'), findsNothing);
      expect(find.text('Copier'), findsOneWidget);
      expect(_focusedLabel(), 'Partager');
    },
  );

  testWidgets('devrait partir de l’ancre au ressort, et seulement se fondre en mouvement réduit', (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(overlayApp(_menu([]), disableAnimations: reduced));
      await tester.tap(_trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final moving = tester.getRect(find.text('Copier')).top;
      await tester.pumpAndSettle();
      final settled = tester.getRect(find.text('Copier')).top;
      expect(moving == settled, reduced, reason: 'mouvement réduit : $reduced');
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('devrait fermer seulement le sous-menu à Échap et rendre le focus à sa ligne', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedLabel(), 'Par e-mail');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Par e-mail'), findsNothing);
    expect(find.text('Copier'), findsOneWidget);
    expect(_focusedLabel(), 'Partager');
  });

  testWidgets('devrait aller à la première et à la dernière action avec Début et Fin', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.end);
    expect(_focusedLabel(), 'Supprimer');
    await _key(tester, LogicalKeyboardKey.home);
    expect(_focusedLabel(), 'Copier');
  });

  testWidgets('devrait ignorer le toucher sur une action pendant que le menu se ferme', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(overlayApp(_menu(log)));
    await _openByTap(tester);
    final copy = tester.getCenter(find.text('Copier'));
    await tester.tapAt(const Offset(700, 500));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Copier'), findsOneWidget);
    await tester.tapAt(copy);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
  });

  testWidgets('devrait appeler l’action pendant la sortie, le menu encore dans l’arbre, puis le retirer', (
    tester,
  ) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      overlayApp(
        FlMenu(
          items: [FlMenuItem(label: 'Copier', onPressed: () => seen.add(find.text('Copier').evaluate().isNotEmpty))],
          builder: (context, controller) => FlButton(label: 'Options', onPressed: controller.open),
        ),
      ),
    );
    await _openByTap(tester);
    await tester.tap(find.text('Copier'));
    expect(seen, [true]);
    await tester.pumpAndSettle();
    expect(find.text('Copier'), findsNothing);
  });

  testWidgets('devrait cocher une option multiple sans fermer, et fermer au choix d’une option unique', (tester) async {
    var styles = <String>{'gras'};
    var align = <String>{'gauche'};
    await tester.pumpWidget(
      overlayApp(
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: FlMenu(
              items: [
                FlMenuGroup<String>(
                  selection: FlMenuSelection.multiple,
                  selected: styles,
                  onChanged: (value) => setState(() => styles = value),
                  options: const [
                    FlMenuOption(value: 'gras', label: 'Gras'),
                    FlMenuOption(value: 'italique', label: 'Italique'),
                  ],
                ),
                FlMenuGroup<String>(
                  selected: align,
                  indicator: FlMenuIndicator.dot,
                  onChanged: (value) => setState(() => align = value),
                  options: const [
                    FlMenuOption(value: 'gauche', label: 'Gauche'),
                    FlMenuOption(value: 'centre', label: 'Centre'),
                  ],
                ),
              ],
              builder: (context, controller) => FlButton(label: 'Options', onPressed: controller.open),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await _openByTap(tester);
    expect(tester.getSemantics(find.text('Gras')), isSemantics(role: SemanticsRole.menuItemCheckbox, isChecked: true));
    await tester.tap(find.text('Italique'));
    await tester.pumpAndSettle();
    expect(styles, {'gras', 'italique'});
    expect(find.text('Gras'), findsOneWidget);
    await tester.tap(find.text('Gras'));
    await tester.pumpAndSettle();
    expect(styles, {'italique'});
    await tester.tap(find.text('Centre'));
    await tester.pumpAndSettle();
    expect(align, {'centre'});
    expect(find.text('Gras'), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait rétrécir une ligne pressée sur le fond control', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([])));
    await _openByTap(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Copier')));
    await tester.pumpAndSettle();
    final scale = tester.widget<AnimatedScale>(
      find.ancestor(of: find.text('Copier'), matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, 0.98);
    final fill = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('Copier'), matching: find.byType(DecoratedBox)).first,
    );
    expect((fill.decoration as ShapeDecoration).color, _tokens.light.control);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('devrait présenter ses lignes dans une feuille du bas', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      overlayApp(
        Center(
          child: FlMenu(
            presentation: FlMenuPresentation.sheet,
            label: 'Options',
            barrierLabel: 'Fermer',
            items: [FlMenuItem(label: 'Copier', onPressed: () => log.add('copier'))],
            builder: (context, controller) => FlButton(label: 'Options', onPressed: controller.open),
          ),
        ),
      ),
    );
    await _openByTap(tester);
    expect(find.ancestor(of: find.text('Copier'), matching: find.byType(FlSheet)), findsOneWidget);
    await tester.tap(find.text('Copier'));
    await tester.pumpAndSettle();
    expect(log, ['copier']);
    expect(find.text('Copier'), findsNothing);
  });

  testWidgets('devrait réunir les lignes de la feuille sur une carte de la base avec grouped', (tester) async {
    Future<void> open({required bool grouped}) async {
      await tester.pumpWidget(
        overlayApp(
          Center(
            child: FlMenu(
              presentation: FlMenuPresentation.sheet,
              grouped: grouped,
              label: 'Options',
              barrierLabel: 'Fermer',
              items: [FlMenuItem(label: 'Copier', onPressed: () {})],
              builder: (context, controller) => FlButton(label: 'Options', onPressed: controller.open),
            ),
          ),
        ),
      );
      await _openByTap(tester);
    }

    bool onBase() => find
        .ancestor(of: find.text('Copier'), matching: find.byType(DecoratedBox))
        .evaluate()
        .map((e) => (e.widget as DecoratedBox).decoration)
        .any((d) => d is ShapeDecoration && d.color == _tokens.light.background);
    await open(grouped: true);
    expect(onBase(), isTrue);
    await tester.tap(find.text('Copier'));
    await tester.pumpAndSettle();
    await open(grouped: false);
    expect(onBase(), isFalse, reason: 'sur la feuille elle-même par défaut');
  });

  testWidgets('devrait déplier le sous-menu à la flèche gauche et le replier à la droite en RTL', (tester) async {
    await tester.pumpWidget(overlayApp(_menu([]), direction: TextDirection.rtl));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedLabel(), 'Partager');
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Par e-mail'), findsNothing, reason: 'la flèche de début ne déplie pas');
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focusedLabel(), 'Par e-mail');
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Par e-mail'), findsNothing);
    expect(_focusedLabel(), 'Partager');
  });

  testWidgets('devrait tourner le chevron du sous-menu ouvert vers le bas quand le texte va de droite à gauche', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(overlayApp(_menu([]), direction: direction));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partager'));
      await tester.pumpAndSettle();
      final chevron = tester.renderObject<RenderBox>(
        find.descendant(of: find.byType(FlIcon), matching: find.byType(CustomPaint)).last,
      );
      // Le tracé de chevronRight pointe vers +x dans sa boîte.
      final transform = chevron.getTransformTo(null);
      final tip =
          MatrixUtils.transformPoint(transform, const Offset(1, 0)) -
          MatrixUtils.transformPoint(transform, Offset.zero);
      expect(tip.dy, greaterThan(0.9 * tip.distance), reason: direction.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('devrait poser le leading d’une option entre l’indicateur et le titre', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(40),
            child: FlMenu(
              items: [
                FlMenuGroup<String>(
                  selected: const {'list'},
                  onChanged: (_) {},
                  options: const [
                    FlMenuOption(
                      value: 'list',
                      label: 'Liste',
                      leading: SizedBox(key: Key('icon'), width: 16, height: 16),
                    ),
                  ],
                ),
              ],
              builder: (context, controller) => FlButton(label: 'Options', onPressed: controller.open),
            ),
          ),
        ),
      ),
    );
    await _openByTap(tester);
    final icon = tester.getRect(find.byKey(const Key('icon')));
    final title = tester.getRect(find.text('Liste'));
    expect(title.left - icon.right, _tokens.space.xs * 2.5);
    expect(icon.center.dy, closeTo(title.center.dy, 0.5));
  });
}
