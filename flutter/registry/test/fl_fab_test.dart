import 'dart:ui' show SemanticsRole;

import 'package:fliin_ui/components/fab/fl_fab.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

Widget _plus() => FlIcon(FlIcons.plus);

/// Un groupe qui tient son état, et note l'action choisie.
class _Group extends StatelessWidget {
  const _Group({this.layout = FlFabLayout.dial, this.chosen, this.enabled = true, this.extended = false});

  final FlFabLayout layout;
  final ValueChanged<String>? chosen;
  final bool enabled;
  final bool extended;

  @override
  Widget build(BuildContext context) => FlFabGroup(
    label: 'Créer',
    barrierLabel: 'Fermer',
    icon: _plus(),
    layout: layout,
    enabled: enabled,
    extended: extended,
    actions: [
      FlFabAction(label: 'Événement', icon: FlIcon(FlIcons.calendar), onPressed: () => chosen?.call('Événement')),
      FlFabAction(label: 'Note', icon: FlIcon(FlIcons.pencil), onPressed: () => chosen?.call('Note')),
      FlFabAction(label: 'Archive', icon: FlIcon(FlIcons.inbox), onPressed: null),
    ],
  );
}

void main() {
  group('FlFab', () {
    testWidgets('devrait appeler onPressed quand on le touche', (tester) async {
      var presses = 0;
      await tester.pumpWidget(toggleApp(FlFab(label: 'Ajouter', icon: _plus(), onPressed: () => presses++)));
      await tester.tap(find.byType(FlFab));
      expect(presses, 1);
    });

    testWidgets('devrait s’activer à la barre d’espace quand il a le focus clavier', (tester) async {
      var presses = 0;
      await tester.pumpWidget(toggleApp(FlFab(label: 'Ajouter', icon: _plus(), onPressed: () => presses++)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(presses, 1);
    });

    testWidgets('devrait s’annoncer par son libellé, en bouton, quand il ne montre que son icône', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(FlFab(label: 'Ajouter', icon: _plus(), onPressed: () {})));
      expect(find.text('Ajouter'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Ajouter')),
        isSemantics(label: 'Ajouter', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('devrait s’annoncer désactivé quand onPressed est nul', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(FlFab(label: 'Ajouter', icon: _plus(), onPressed: null)));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Ajouter')),
        isSemantics(label: 'Ajouter', isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('devrait être rond à la taille de ses jetons quand il n’est pas étendu', (tester) async {
      final size = FlTokens.defaults.size;
      for (final (fab, extent) in [
        (FlFabSize.sm, size.controlCompact),
        (FlFabSize.md, size.controlSpacious),
        (FlFabSize.lg, size.controlSpacious + FlTokens.defaults.space.sm),
      ]) {
        await tester.pumpWidget(
          toggleApp(
            FlFab(key: ValueKey(fab), label: 'Ajouter', icon: _plus(), size: fab, onPressed: () {}),
            platform: TargetPlatform.macOS,
          ),
        );
        expect(tester.getSize(find.byType(DecoratedBox).first), Size.square(extent), reason: '$fab');
      }
    });

    testWidgets('devrait montrer son libellé et s’élargir quand il est étendu', (tester) async {
      await tester.pumpWidget(toggleApp(FlFab(label: 'Écrire', icon: _plus(), extended: true, onPressed: () {})));
      await tester.pumpAndSettle();
      expect(find.text('Écrire'), findsOneWidget);
      final box = tester.getSize(find.byType(DecoratedBox).first);
      expect(box.height, FlTokens.defaults.size.controlSpacious);
      expect(box.width, greaterThan(box.height));
    });

    testWidgets('devrait replier son libellé quand extended passe à faux', (tester) async {
      Widget fab(bool extended) =>
          toggleApp(FlFab(label: 'Écrire', icon: _plus(), extended: extended, onPressed: () {}));
      await tester.pumpWidget(fab(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(fab(false));
      await tester.pump(const Duration(milliseconds: 50));
      final midway = tester.getSize(find.byType(DecoratedBox).first).width;
      await tester.pumpAndSettle();
      final folded = tester.getSize(find.byType(DecoratedBox).first).width;
      expect(folded, FlTokens.defaults.size.controlSpacious);
      expect(midway, greaterThan(folded));
      expect(find.text('Écrire'), findsNothing);
    });

    testWidgets('devrait se poser dans le coin du bas, du côté où finit le texte, quand placement est bottomEnd', (
      tester,
    ) async {
      final inset = FlTokens.defaults.space.lg;
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          toggleApp(
            FlFab(label: 'Ajouter', icon: _plus(), placement: FlFabPlacement.bottomEnd, onPressed: () {}),
            direction: direction,
            platform: TargetPlatform.macOS,
          ),
        );
        final screen = tester.getRect(find.byType(FlScope));
        final fab = tester.getRect(find.byType(DecoratedBox).first);
        expect(fab.bottom, screen.bottom - inset);
        if (direction == TextDirection.ltr) {
          expect(fab.right, screen.right - inset);
        } else {
          expect(fab.left, screen.left + inset);
        }
      }
    });

    testWidgets('devrait rester au-dessus de la zone sûre quand il est posé en bas', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: toggleApp(
            FlFab(label: 'Ajouter', icon: _plus(), placement: FlFabPlacement.bottomCenter, onPressed: () {}),
            platform: TargetPlatform.macOS,
          ),
        ),
      );
      final screen = tester.getRect(find.byType(FlScope));
      final fab = tester.getRect(find.byType(DecoratedBox).first);
      expect(fab.bottom, screen.bottom - 34 - FlTokens.defaults.space.lg);
      expect(fab.center.dx, screen.center.dx);
    });
  });

  group('FlFabGroup', () {
    testWidgets('devrait ne construire aucune action quand il est fermé', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group()));
      expect(find.text('Note'), findsNothing);
      expect(find.bySemanticsLabel('Fermer'), findsNothing);
    });

    testWidgets('devrait déplier ses actions quand on touche le déclencheur', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group()));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Événement'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      final trigger = tester.getRect(find.bySemanticsLabel('Créer'));
      expect(tester.getRect(find.text('Note')).bottom, lessThan(trigger.top));
      expect(tester.getRect(find.text('Événement')).bottom, lessThan(tester.getRect(find.text('Note')).top));
    });

    testWidgets('devrait se fermer puis lancer l’action quand on en choisit une', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(toggleApp(_Group(chosen: chosen.add)));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Note'));
      await tester.pumpAndSettle();
      expect(chosen, ['Note']);
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait lancer l’action quand on touche son libellé', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(toggleApp(_Group(chosen: chosen.add)));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Événement'));
      await tester.pumpAndSettle();
      expect(chosen, ['Événement']);
    });

    testWidgets('devrait rester ouvert quand on touche une action désactivée', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group()));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('devrait se fermer quand on touche le voile', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group()));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait se fermer quand on retouche le déclencheur', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group()));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait donner le focus à la première action à l’ouverture, et se fermer à Échap', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(toggleApp(_Group(chosen: chosen.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(chosen, ['Événement']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait annoncer le déclencheur déplié et les actions en éléments de menu', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Group()));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Créer')),
        isSemantics(label: 'Créer', isButton: true, hasExpandedState: true, isExpanded: false),
      );
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Créer')),
        isSemantics(label: 'Créer', isButton: true, hasExpandedState: true, isExpanded: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Note')).role, SemanticsRole.menuItem);
      expect(find.bySemanticsLabel('Fermer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('devrait suivre open et demander le changement quand l’app tient l’état', (tester) async {
      final asked = <bool>[];
      Widget group(bool open) => toggleApp(
        FlFabGroup(
          label: 'Créer',
          barrierLabel: 'Fermer',
          icon: _plus(),
          open: open,
          onOpenChange: asked.add,
          actions: [FlFabAction(label: 'Note', icon: FlIcon(FlIcons.pencil), onPressed: () {})],
        ),
      );
      await tester.pumpWidget(group(false));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      expect(asked, [true]);
      expect(find.text('Note'), findsNothing);

      await tester.pumpWidget(group(true));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsOneWidget);
      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();
      expect(asked, [true, false]);
      expect(find.text('Note'), findsOneWidget);

      await tester.pumpWidget(group(false));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait ouvrir un panneau de lignes quand layout est menu', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(toggleApp(_Group(layout: FlFabLayout.menu, chosen: chosen.add)));
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pumpAndSettle();
      final first = tester.getRect(find.text('Événement'));
      final second = tester.getRect(find.text('Note'));
      expect(first.left, second.left);
      expect(first.bottom, lessThan(second.top));
      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();
      expect(chosen, ['Note']);
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait rester fermé quand il est désactivé', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group(enabled: false)));
      await tester.tap(find.bySemanticsLabel('Créer'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('devrait replier le libellé du déclencheur étendu quand il s’ouvre', (tester) async {
      await tester.pumpWidget(toggleApp(const _Group(extended: true)));
      expect(find.text('Créer'), findsOneWidget);
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Créer'), findsNothing);
    });

    testWidgets('devrait poser ses actions sans les déplacer quand les animations sont réduites', (tester) async {
      await tester.pumpWidget(
        MediaQuery(data: const MediaQueryData(disableAnimations: true), child: toggleApp(const _Group())),
      );
      await tester.tap(find.bySemanticsLabel('Créer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final early = tester.getRect(find.text('Note'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Note')), early);
    });
  });
}
