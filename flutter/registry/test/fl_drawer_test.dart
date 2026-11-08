import 'dart:ui' show SemanticsRole;

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/components/drawer/fl_drawer.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

final _panel = find.byType(FlDrawer);
final _open = find.widgetWithText(FlButton, 'Menu');

/// Le panneau peint, sans la place laissée au voile.
final _box = find
    .descendant(
      of: _panel,
      matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
    )
    .first;

/// Une page avec le bouton qui ouvre le tiroir ; [result] reçoit ce que rend
/// `showFlDrawer`.
Widget _page(
  List<Object?> result, {
  FlDrawerSide side = FlDrawerSide.start,
  String title = 'Navigation',
  bool guarded = false,
  Widget? body,
  List<String> actions = const ['Déconnexion'],
}) => Center(
  child: Builder(
    builder: (context) => FlButton(
      label: 'Menu',
      onPressed: () async => result.add(
        await showFlDrawer<String>(
          context: context,
          side: side,
          barrierLabel: 'Fermer le menu',
          builder: (context) {
            final drawer = FlDrawer(
              title: title,
              closeLabel: 'Fermer',
              actions: [
                for (final label in actions) FlButton(label: label, onPressed: () => Navigator.pop(context, 'out')),
              ],
              child:
                  body ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FlButton(label: 'Accueil', variant: FlButtonVariant.ghost, onPressed: () {}),
                      FlButton(label: 'Réglages', variant: FlButtonVariant.ghost, onPressed: () {}),
                    ],
                  ),
            );
            return guarded ? PopScope<String>(canPop: false, child: drawer) : drawer;
          },
        ),
      ),
    ),
  ),
);

void _surface(WidgetTester tester, Size size, {FakeViewPadding padding = FakeViewPadding.zero}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding;
  addTearDown(tester.view.reset);
}

String? _focusedLabel() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FlPressable>()?.label;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _openByTap(WidgetTester tester) async {
  await tester.tap(_open);
  await tester.pumpAndSettle();
}

void main() {
  for (final (direction, side, left) in [
    (TextDirection.ltr, FlDrawerSide.start, true),
    (TextDirection.rtl, FlDrawerSide.start, false),
    (TextDirection.ltr, FlDrawerSide.end, false),
    (TextDirection.rtl, FlDrawerSide.end, true),
  ]) {
    testWidgets('devrait poser un panneau de 320 sur toute la hauteur, contre le bord ${left ? 'gauche' : 'droit'}, '
        'quand il vient de ${side.name} en ${direction.name}', (tester) async {
      _surface(tester, const Size(390, 844));
      await tester.pumpWidget(overlayApp(_page([], side: side), direction: direction));
      await tester.tap(_open);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final moving = tester.getRect(_box);
      expect(left ? moving.left < 0 : moving.right > 390, isTrue, reason: 'il entre par son bord');
      await tester.pumpAndSettle();
      expect(tester.getRect(_box), left ? const Rect.fromLTWH(0, 0, 320, 844) : const Rect.fromLTWH(70, 0, 320, 844));
    });
  }

  testWidgets('devrait faire 384 de large sur une tablette et jamais plus de 85 % de l’écran', (tester) async {
    for (final (width, expected) in [(800.0, 384.0), (360.0, 306.0)]) {
      _surface(tester, Size(width, 700));
      await tester.pumpWidget(overlayApp(_page([])));
      await _openByTap(tester);
      expect(tester.getSize(_box).width, expected);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('devrait garder son contenu hors de la zone sûre du côté de l’écran qu’il touche', (tester) async {
    _surface(tester, const Size(844, 390), padding: const FakeViewPadding(left: 47, top: 20, bottom: 21));
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    expect(tester.getSize(_box).width, 384 + 47);
    expect(tester.getTopLeft(find.text('Navigation')).dx, 47 + 20);
    expect(tester.getTopLeft(find.text('Navigation')).dy, greaterThanOrEqualTo(20 + 24));
    expect(tester.getBottomRight(find.widgetWithText(FlButton, 'Déconnexion')).dy, 390 - 21 - 24);
  });

  testWidgets('devrait se fermer au toucher du voile, à Échap et au retour, et rendre le focus au bouton', (
    tester,
  ) async {
    final result = <Object?>[];
    await tester.pumpWidget(overlayApp(_page(result)));
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focusedLabel(), 'Menu');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_panel, findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_panel, findsNothing);
    expect(_focusedLabel(), 'Menu');

    await _openByTap(tester);
    await tester.tapAt(const Offset(780, 300));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await _openByTap(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await _openByTap(tester);
    await tester.tap(find.widgetWithText(FlButton, 'Déconnexion'));
    await tester.pumpAndSettle();
    expect(result, [null, null, null, 'out']);
  });

  testWidgets('devrait garder Tab dans le panneau', (tester) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.enter);
    final seen = <String?>{};
    for (var i = 0; i < 8; i++) {
      await _key(tester, LogicalKeyboardKey.tab);
      seen.add(_focusedLabel());
    }
    expect(seen, {'Fermer', 'Accueil', 'Réglages', 'Déconnexion'});
  });

  for (final direction in TextDirection.values) {
    testWidgets('devrait se fermer glissé vers son bord au-delà de 30 % en ${direction.name}, et revenir en deçà', (
      tester,
    ) async {
      _surface(tester, const Size(390, 844));
      await tester.pumpWidget(overlayApp(_page([]), direction: direction));
      await _openByTap(tester);
      final outward = direction == TextDirection.ltr ? -1.0 : 1.0;
      final start = tester.getCenter(find.text('Navigation'));

      await tester.timedDragFrom(start, Offset(outward * 64, 0), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      expect(tester.getRect(_box).width, 320);
      expect(
        direction == TextDirection.ltr ? tester.getRect(_box).left : tester.getRect(_box).right,
        direction == TextDirection.ltr ? 0 : 390,
      );

      await tester.timedDragFrom(start, Offset(outward * 120, 0), const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
    });
  }

  testWidgets('devrait se fermer lancé vers son bord, même sur une courte distance', (tester) async {
    _surface(tester, const Size(390, 844));
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    await tester.flingFrom(tester.getCenter(find.text('Navigation')), const Offset(-60, 0), 1500);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets("devrait s'annoncer comme un dialogue nommé par son titre, qui nomme sa route", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    final node = tester.getSemantics(find.descendant(of: _panel, matching: find.byType(Semantics)).first);
    expect(node.label, 'Navigation');
    expect(node.role, SemanticsRole.dialog);
    expect(node.flagsCollection.scopesRoute, isTrue);
    expect(node.flagsCollection.namesRoute, isTrue);
    expect(find.bySemanticsLabel('Fermer le menu'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait apparaître en fondu sur place en mouvement réduit', (tester) async {
    _surface(tester, const Size(390, 844));
    await tester.pumpWidget(overlayApp(_page([]), disableAnimations: true));
    await tester.tap(_open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(_box).left, 0);
    final fade = tester.widget<FadeTransition>(find.ancestor(of: _panel, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('devrait garder ses actions au-dessus du clavier, comme FlDialog (relecture M1)', (tester) async {
    _surface(tester, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpWidget(overlayApp(_page([], actions: const ['Appliquer'])));
    await _openByTap(tester);
    expect(tester.getBottomRight(find.widgetWithText(FlButton, 'Appliquer')).dy, lessThanOrEqualTo(844 - 300 - 24));
  });

  testWidgets('devrait revenir ouvert par le ressort quand un PopScope refuse la sortie glissée (relecture M2)', (
    tester,
  ) async {
    _surface(tester, const Size(390, 844));
    await tester.pumpWidget(overlayApp(_page([], guarded: true)));
    await _openByTap(tester);
    await tester.timedDragFrom(
      tester.getCenter(find.text('Navigation')),
      const Offset(-200, 0),
      const Duration(milliseconds: 900),
    );
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(tester.getRect(_box), const Rect.fromLTWH(0, 0, 320, 844));
  });

  testWidgets('devrait défiler au lieu de déborder à 2,0 en paysage, titre long et deux actions (relecture M3)', (
    tester,
  ) async {
    _surface(tester, const Size(844, 390));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(844, 390), textScaler: TextScaler.linear(2)),
        child: overlayApp(
          _page(
            [],
            title: 'Réglages du compte et de la confidentialité',
            actions: const ['Se déconnecter', 'Changer de compte'],
          ),
        ),
      ),
    );
    await _openByTap(tester);
    expect(tester.takeException(), isNull);
    final out = find.widgetWithText(FlButton, 'Changer de compte');
    await tester.scrollUntilVisible(out, 40, scrollable: find.byType(Scrollable).last);
    expect(tester.getRect(out).bottom, lessThanOrEqualTo(390));
  });

  testWidgets('devrait créer la présence du panneau une fois, partagée par le voile et le panneau (relecture B4)', (
    tester,
  ) async {
    await tester.pumpWidget(overlayApp(_page([])));
    await tester.tap(_open);
    await tester.pump();
    final veil = tester.widget<FlPopupOverlay>(find.byType(FlPopupOverlay)).animation;
    Listenable slide() => tester
        .widget<AnimatedBuilder>(
          find.ancestor(of: find.byType(FractionalTranslation), matching: find.byType(AnimatedBuilder)).first,
        )
        .animation;
    expect(identical(slide(), veil), isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(identical(slide(), veil), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('devrait ignorer le glisser en mouvement réduit, comme FlDialog (relecture B5)', (tester) async {
    _surface(tester, const Size(390, 844));
    await tester.pumpWidget(overlayApp(_page([]), disableAnimations: true));
    await _openByTap(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Navigation')));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(tester.getRect(_box).left, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'devrait suivre le doigt point pour point avec la zone sûre du bord, en ${direction.name} (relecture B6)',
      (tester) async {
        _surface(tester, const Size(844, 390), padding: const FakeViewPadding(left: 47, right: 47));
        await tester.pumpWidget(overlayApp(_page([], side: FlDrawerSide.end), direction: direction));
        await _openByTap(tester);
        final before = tester.getRect(_box);
        final outward = direction == TextDirection.ltr ? 1.0 : -1.0;
        final gesture = await tester.startGesture(tester.getCenter(find.text('Navigation')));
        await gesture.moveBy(Offset(outward * 30, 0));
        await gesture.moveBy(Offset(outward * 60, 0));
        await tester.pump();
        expect(tester.getRect(_box).left - before.left, moreOrLessEquals(outward * 90, epsilon: 0.5));
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('devrait revenir lâché à 25 % et sortir lâché à 40 %, seuil de 30 % (relecture B11)', (tester) async {
    _surface(tester, const Size(390, 844));
    await tester.pumpWidget(overlayApp(_page([])));
    await _openByTap(tester);
    Future<void> slide(double by) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text('Navigation')));
      await gesture.moveBy(const Offset(-30, 0));
      for (var moved = 0.0; moved < by; moved += 10) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await slide(50);
    expect(_panel, findsOneWidget);
    await slide(100);
    expect(_panel, findsNothing);
  });

  testWidgets('devrait garder son contenu hors de la zone sûre du côté de fin en RTL', (tester) async {
    _surface(tester, const Size(844, 390), padding: const FakeViewPadding(left: 47));
    await tester.pumpWidget(overlayApp(_page([], side: FlDrawerSide.end), direction: TextDirection.rtl));
    await _openByTap(tester);
    expect(tester.getRect(_box), const Rect.fromLTWH(0, 0, 384 + 47, 390));
    expect(tester.getTopLeft(find.byType(FlCloseButton)).dx, 47 + 20);
    expect(tester.getTopRight(find.text('Navigation')).dx, closeTo(431 - 20, 1));
  });
}
