import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/dialog/fl_dialog.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';
import 'torture/themes.dart';
import 'torture/torture.g.dart';

final _panel = find.byType(FlDialog);
final _surface = find.descendant(of: _panel, matching: find.byType(DecoratedBox)).first;
final _open = find.widgetWithText(FlButton, 'Supprimer le fichier');
const _title = 'Supprimer « rapport.pdf » ?';
const _body = 'Le fichier ira à la corbeille.';

FlTokens get _tokens => FlTokens.defaults;

Widget _dialog(
  BuildContext context, {
  bool alert = false,
  List<Widget>? actions,
  String body = _body,
  String? closeLabel,
}) => FlDialog(
  title: _title,
  alert: alert,
  closeLabel: closeLabel,
  content: Text(body),
  actions:
      actions ??
      [
        FlButton(label: 'Annuler', variant: FlButtonVariant.secondary, onPressed: () => Navigator.pop(context, false)),
        FlButton(label: 'Supprimer', onPressed: () => Navigator.pop(context, true)),
      ],
);

/// Une page avec un bouton avant et un bouton après celui qui ouvre le
/// dialogue ; [result] reçoit ce que rend `showFlDialog`.
Widget _page(
  List<Object?> result, {
  bool dismissible = true,
  String? barrierLabel = 'Fermer',
  bool alert = false,
  String body = _body,
  String? closeLabel,
}) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FlButton(label: 'Avant', onPressed: () {}),
      Builder(
        builder: (context) => FlButton(
          label: 'Supprimer le fichier',
          onPressed: () async => result.add(
            await showFlDialog<bool>(
              context: context,
              dismissible: dismissible,
              barrierLabel: barrierLabel,
              builder: (context) => _dialog(context, alert: alert, body: body, closeLabel: closeLabel),
            ),
          ),
        ),
      ),
      FlButton(label: 'Après', onPressed: () {}),
    ],
  ),
);

/// Les libellés de l'arbre sémantique tel que le lit un lecteur d'écran.
List<String> _labels(WidgetTester tester) {
  final labels = <String>[];
  bool visit(SemanticsNode node) {
    labels.add(node.label);
    node.visitChildren(visit);
    return true;
  }

  visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return labels;
}

String? _focusedLabel() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FlPressable>()?.label;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Ouvre le dialogue au clavier : Tab jusqu'au bouton, puis Entrée.
Future<void> _openByKeyboard(WidgetTester tester) async {
  await _key(tester, LogicalKeyboardKey.tab);
  await _key(tester, LogicalKeyboardKey.tab);
  expect(_focusedLabel(), 'Supprimer le fichier');
  await _key(tester, LogicalKeyboardKey.enter);
  expect(_panel, findsOneWidget);
}

Future<void> _openByTap(WidgetTester tester) async {
  await tester.tap(_open);
  await tester.pumpAndSettle();
}

void _surfaceSize(WidgetTester tester, Size size, {FakeViewPadding padding = FakeViewPadding.zero}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('devrait s’annoncer comme un dialogue qui porte et nomme sa route, page masquée', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    expect(
      tester.getSemantics(_surface),
      isSemantics(role: SemanticsRole.dialog, label: _title, scopesRoute: true, namesRoute: true),
    );
    expect(_labels(tester), isNot(contains('Avant')));
    expect(_labels(tester), contains('Annuler'));
    expect(_labels(tester).where((label) => label == _title), hasLength(1));
    semantics.dispose();
  });

  testWidgets('devrait s’annoncer comme une alerte quand alert est vrai', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_page([], alert: true)));
    await _openByTap(tester);
    expect(tester.getSemantics(_surface), isSemantics(role: SemanticsRole.alertDialog));
    semantics.dispose();
  });

  testWidgets('devrait rendre la valeur de l’action choisie', (tester) async {
    final result = <Object?>[];
    await tester.pumpWidget(overlayApp(_page(result)));
    await _openByTap(tester);
    await tester.tap(find.widgetWithText(FlButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(result, [true]);
    expect(_panel, findsNothing);
  });

  testWidgets('devrait voiler la page de scrim à scrimOpacity, centré, sans dépasser dialogMaxWidth', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    final veil = _tokens.light.scrim.withValues(alpha: _tokens.light.scrim.a * _tokens.size.scrimOpacity);
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == veil),
      ),
      findsOneWidget,
    );
    final panel = tester.getRect(_surface);
    expect(panel.center, const Offset(400, 300));
    expect(panel.width, _tokens.size.dialogMaxWidth);
  });

  testWidgets('devrait recolorer le voile quand l’app passe en sombre, dialogue ouvert', (tester) async {
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: brightness,
        builder: (context, value, _) => WidgetsApp(
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, builder) =>
              PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
          home: _page([]),
          builder: (context, navigator) => FlScope(brightness: value, child: navigator!),
        ),
      ),
    );
    await _openByTap(tester);
    brightness.value = Brightness.dark;
    await tester.pumpAndSettle();
    final veil = _tokens.dark.scrim.withValues(alpha: _tokens.dark.scrim.a * _tokens.size.scrimOpacity);
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == veil),
      ),
      findsOneWidget,
    );
  });

  testWidgets('devrait rester hors de l’encoche et de l’indicateur d’accueil', (tester) async {
    _surfaceSize(tester, const Size(390, 600), padding: const FakeViewPadding(top: 59, bottom: 34));
    await tester.pumpWidget(overlayApp(_page([], body: List.filled(30, _body).join(' '))));
    await _openByTap(tester);
    final panel = tester.getRect(_surface);
    expect(panel.top, greaterThanOrEqualTo(59 + _tokens.space.lg));
    expect(panel.bottom, lessThanOrEqualTo(600 - 34 - _tokens.space.lg));
  });

  testWidgets('devrait rester au-dessus du clavier', (tester) async {
    _surfaceSize(tester, const Size(390, 600));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpWidget(overlayApp(_page([], body: List.filled(30, _body).join(' '))));
    await _openByTap(tester);
    expect(tester.getRect(_surface).bottom, lessThanOrEqualTo(300 - _tokens.space.lg));
  });

  testWidgets(
    'devrait montrer au moins trois lignes de corps, ou le corps entier, à 2,0× sous torture A dans 390 × 640',
    (tester) async {
      await loadTortureFonts();
      _surfaceSize(tester, const Size(390, 640));
      for (final body in [_body, List.filled(12, _body).join(' ')]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(390, 640), textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FlScope(
                tokens: tortureA,
                platform: TargetPlatform.iOS,
                child: Navigator(
                  key: ValueKey(body),
                  onGenerateInitialRoutes: (navigator, _) => [
                    PageRouteBuilder<void>(pageBuilder: (context, _, _) => const SizedBox.expand()),
                    FlDialogRoute<void>(
                      context: navigator.context,
                      barrierLabel: 'Fermer',
                      builder: (context) => FlDialog(
                        title: 'Supprimer définitivement « rapport annuel 2026.pdf » ?',
                        content: Text(body),
                        actions: [FlButton(label: 'Annuler', onPressed: () {})],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final viewport = tester.getRect(find.descendant(of: _panel, matching: find.byType(SingleChildScrollView)));
        final paragraph = tester.renderObject<RenderParagraph>(find.text(body));
        final line = paragraph.getFullHeightForCaret(TextPosition(offset: 0));
        final whole = tester.getRect(find.text(body)).bottom - viewport.top;
        expect(
          viewport.height,
          greaterThanOrEqualTo(whole < 3 * line ? whole : 3 * line),
          reason: body.length.toString(),
        );
        expect(tester.takeException(), isNull);
        if (whole > viewport.height) {
          await tester.pumpAndSettle();
          expect(
            find.byType(RawScrollbar),
            paints..something(
              (method, arguments) =>
                  method == #drawRRect &&
                  (arguments.last as Paint).color.toARGB32() == tortureA.light.onSurfaceMuted.toARGB32(),
            ),
            reason: 'la barre de défilement dit qu’il y a une suite',
          );
        }
      }
    },
  );

  testWidgets('devrait garder Tab dans le dialogue', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByKeyboard(tester);
    final seen = <String?>{};
    for (var i = 0; i < 5; i++) {
      await _key(tester, LogicalKeyboardKey.tab);
      seen.add(_focusedLabel());
    }
    expect(seen, {'Annuler', 'Supprimer'});
  });

  testWidgets('devrait se fermer à Échap et rendre le focus au bouton qui l’a ouvert', (tester) async {
    final result = <Object?>[];
    await tester.pumpWidget(overlayApp(_page(result)));
    await _openByKeyboard(tester);
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_panel, findsNothing);
    expect(result, [null]);
    expect(_focusedLabel(), 'Supprimer le fichier');
  });

  testWidgets('devrait se fermer à Échap et au retour même sans voile qui ferme', (tester) async {
    await tester.pumpWidget(overlayApp(_page([], barrierLabel: null)));
    await _openByKeyboard(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_panel, findsNothing);
    await _openByTap(tester);
    expect(_panel, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('devrait se fermer au toucher sur le voile quand barrierLabel est donné', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('devrait ignorer voile, Échap et retour quand il n’est pas dismissible', (tester) async {
    await tester.pumpWidget(overlayApp(_page([], dismissible: false, barrierLabel: null)));
    await _openByKeyboard(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.escape);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await tester.tap(find.widgetWithText(FlButton, 'Annuler'));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('devrait refuser un dialogue qui ne se ferme pas et n’a pas d’action', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        Builder(
          builder: (context) => FlButton(
            label: 'Ouvrir',
            onPressed: () => showFlDialog<void>(
              context: context,
              dismissible: false,
              builder: (context) => _dialog(context, actions: const []),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('devrait couvrir tout l’écran depuis un navigateur imbriqué', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Navigator(onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (context, _, _) => _page([]))),
          ),
        ),
      ),
    );
    await _openByTap(tester);
    expect(tester.getRect(find.byType(FlPopupOverlay).last), const Rect.fromLTWH(0, 0, 800, 600));
  });

  testWidgets('devrait se poser de 1,04 à 1 en apparaissant, en motion.duration.short4', (tester) async {
    final motion = _tokens.motion;
    await tester.pumpWidget(overlayApp(_page([])));
    await tester.tap(_open);
    await tester.pump();
    await tester.pump(motion.short4 ~/ 2);
    final route = ModalRoute.of(tester.element(_panel))!;
    expect(route.animation!.value, closeTo(0.5, 0.01));
    final growing = tester.getRect(_surface);
    await tester.pump(motion.short4 ~/ 2);
    expect(route.animation!.value, 1);
    await tester.pumpAndSettle();
    final settled = tester.getRect(_surface);
    expect((growing.center - settled.center).distance, lessThan(0.5));
    expect(growing.width / settled.width, inExclusiveRange(1, 1.04));
  });

  testWidgets('devrait apparaître en fondu de motion.duration.short4 sur place quand Android réduit les animations', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(overlayApp(_page([])));
    await tester.tap(_open);
    await tester.pump();
    await tester.pump(_tokens.motion.short4 ~/ 2);
    final route = ModalRoute.of(tester.element(_panel))!;
    expect(route.animation!.value, closeTo(0.5, 0.01));
    final moving = tester.getRect(find.text('Annuler')).top;
    await tester.pump(_tokens.motion.short4 ~/ 2);
    expect(route.animation!.value, 1);
    expect(tester.getRect(find.text('Annuler')).top, moving);
  });

  testWidgets('devrait se fermer sans valeur quand on le glisse vers le bas au-delà d’un dixième de sa course', (
    tester,
  ) async {
    final result = <Object?>[];
    await tester.pumpWidget(overlayApp(_page(result)));
    await _openByTap(tester);
    await tester.drag(_surface, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(result, [null]);
  });

  testWidgets('devrait revenir en place quand on le lâche avant un dixième de sa course', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    final rest = tester.getRect(_surface);
    await tester.drag(_surface, const Offset(0, 25));
    await tester.pump();
    expect(tester.getRect(_surface).top, greaterThan(rest.top));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(tester.getRect(_surface), rest);
  });

  testWidgets('ne devrait pas se glisser quand il n’est pas dismissible, ni sous mouvement réduit', (tester) async {
    for (final (dismissible, reduced) in [(false, false), (true, true)]) {
      await tester.pumpWidget(
        overlayApp(_page([], dismissible: dismissible, barrierLabel: null), disableAnimations: reduced),
      );
      await _openByTap(tester);
      final rest = tester.getRect(_surface);
      await tester.drag(_surface, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      expect(tester.getRect(_surface), rest);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('devrait se fermer sans valeur par son bouton de fermeture, posé en tête à la fin', (tester) async {
    final result = <Object?>[];
    await tester.pumpWidget(overlayApp(_page(result, closeLabel: 'Fermer le dialogue')));
    await _openByTap(tester);
    final close = find.bySemanticsLabel('Fermer le dialogue');
    expect(tester.getRect(close).right, lessThanOrEqualTo(tester.getRect(_surface).right));
    expect(tester.getRect(close).top, lessThan(tester.getRect(find.text(_title)).top));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(result, [null]);
  });

  testWidgets('devrait peindre le panneau de HeroUI : surfaceOverlay sans bordure, titre textLg moyen', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    final decoration = tester.widget<DecoratedBox>(_surface).decoration as ShapeDecoration;
    expect(decoration.color, _tokens.light.surfaceOverlay);
    expect(decoration.shape, isA<FlContinuousBorder>());
    final title = tester.renderObject<RenderParagraph>(find.text(_title)).text.style!;
    expect(title.fontSize, _tokens.typography.ios.textLg.size);
    expect(title.fontWeight, _tokens.typography.weight.medium);
    expect(title.color, _tokens.light.onSurface);
  });

  testWidgets('devrait rapprocher le texte du titre à space.sm, l’icône à space.md, les actions à space.lg', (
    tester,
  ) async {
    await tester.pumpWidget(
      overlayApp(
        Builder(
          builder: (context) => FlDialog(
            icon: const SizedBox(key: Key('icon'), width: 20, height: 20),
            title: _title,
            content: const Text(_body),
            actions: [FlButton(label: 'Supprimer', onPressed: () {})],
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text(_title));
    final disc = tester.getRect(
      find.ancestor(of: find.byKey(const Key('icon')), matching: find.byType(SizedBox)).first,
    );
    expect(title.top - disc.bottom, _tokens.space.md);
    expect(tester.getRect(find.text(_body)).top - title.bottom, _tokens.space.sm);
    expect(
      tester.getRect(find.byType(FlButton)).top - tester.getRect(find.byType(SingleChildScrollView)).bottom,
      _tokens.space.lg,
    );
  });

  testWidgets('devrait empiler les actions sur toute la largeur, dans l’ordre donné, quand actionsLayout est stacked', (
    tester,
  ) async {
    await tester.pumpWidget(
      overlayApp(
        Builder(
          builder: (context) => FlDialog(
            title: _title,
            actionsLayout: FlDialogActionsLayout.stacked,
            actions: [
              FlButton(label: 'Activer', onPressed: () {}),
              FlButton(label: 'Plus tard', variant: FlButtonVariant.ghost, onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    final panel = tester.getRect(_surface);
    final first = tester.getRect(find.widgetWithText(FlButton, 'Activer'));
    final second = tester.getRect(find.widgetWithText(FlButton, 'Plus tard'));
    expect(first.width, panel.width - 2 * _tokens.space.xl);
    expect(second.width, first.width);
    expect(second.top - first.bottom, _tokens.space.sm);
  });

  testWidgets('devrait colorer le disque de l’icône selon iconTone', (tester) async {
    final colors = _tokens.light;
    for (final (tone, fill) in [
      (FlDialogIconTone.accent, colors.accentSoft),
      (FlDialogIconTone.success, colors.successSoft),
      (FlDialogIconTone.warning, colors.warningSoft),
      (FlDialogIconTone.danger, colors.dangerSoft),
    ]) {
      await tester.pumpWidget(
        overlayApp(
          Builder(
            builder: (context) => FlDialog(
              key: ValueKey(tone),
              icon: const SizedBox(key: Key('icon')),
              iconTone: tone,
              title: _title,
              actions: [FlButton(label: 'OK', onPressed: () {})],
            ),
          ),
        ),
      );
      final disc = tester.widget<DecoratedBox>(
        find.ancestor(of: find.byKey(const Key('icon')), matching: find.byType(DecoratedBox)).first,
      );
      expect((disc.decoration as ShapeDecoration).color, fill, reason: '$tone');
    }
  });
}
