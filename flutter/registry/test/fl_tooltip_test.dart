import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/tooltip/fl_tooltip.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

const _message = 'Enregistrer le brouillon';
final _bubble = find.text(_message);
final _button = find.byType(FlButton);

/// L'`offset` de `Tooltip` sans flèche chez HeroUI React v3.
const _gap = 3.0;

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.ancestor(of: _bubble, matching: find.byType(Opacity)).first).opacity;

Widget _tooltip({AlignmentGeometry at = Alignment.center, FlTooltipController? controller}) => Align(
  alignment: at,
  child: FlTooltip(
    message: _message,
    controller: controller,
    child: FlButton(label: 'Enregistrer', onPressed: () {}),
  ),
);

void main() {
  testWidgets('devrait porter le message comme sémantique tooltip du nœud qui entoure l’enfant', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_tooltip()));
    final button = tester.getSemantics(_button);
    expect(button, isSemantics(label: 'Enregistrer', isButton: true));
    expect(button.parent, isSemantics(tooltip: _message));
    semantics.dispose();
  });

  testWidgets('devrait apparaître au-dessus de l’enfant à l’appui long puis disparaître après le relâcher', (
    tester,
  ) async {
    await tester.pumpWidget(overlayApp(_tooltip()));
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump(kLongPressTimeout);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    final bubble = tester.getRect(find.ancestor(of: _bubble, matching: find.byType(DecoratedBox)).first);
    expect(bubble.bottom, closeTo(tester.getRect(_button).top - _gap, 0.5));
    expect(bubble.center.dx, closeTo(tester.getCenter(_button).dx, 0.5));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('devrait se poser dessous quand l’enfant est collé en haut', (tester) async {
    final controller = FlTooltipController();
    await tester.pumpWidget(overlayApp(_tooltip(at: Alignment.topCenter, controller: controller)));
    controller.show();
    await tester.pumpAndSettle();
    final bubble = tester.getRect(find.ancestor(of: _bubble, matching: find.byType(DecoratedBox)).first);
    expect(bubble.top, closeTo(tester.getRect(_button).bottom + _gap, 0.5));
  });

  testWidgets('devrait apparaître au survol de la souris et disparaître quand elle sort', (tester) async {
    await tester.pumpWidget(overlayApp(_tooltip()));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_button));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('devrait apparaître au focus clavier et disparaître quand le focus part', (tester) async {
    await tester.pumpWidget(overlayApp(_tooltip()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('devrait rester cachée quand l’enfant prend le focus au toucher', (tester) async {
    await tester.pumpWidget(overlayApp(_tooltip()));
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('devrait se fermer à Échap sans perdre le focus, et laisser passer Échap quand elle est fermée', (
    tester,
  ) async {
    var outer = 0;
    await tester.pumpWidget(
      overlayApp(
        Actions(
          actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => outer++)},
          child: _tooltip(),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(FocusManager.instance.primaryFocus, focused);
    expect(outer, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(outer, 1);
  });

  testWidgets('devrait entrer en short3, en fondu, en grandissant et en montant depuis l’enfant', (tester) async {
    await tester.pumpWidget(overlayApp(_tooltip()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short3 ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    final moving = tester.getRect(_bubble);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    final settled = tester.getRect(_bubble);
    expect(moving.width, lessThan(settled.width));
    expect(moving.center.dy, greaterThan(settled.center.dy));
  });

  testWidgets('devrait apparaître en fondu seul, sans bouger, quand le mouvement est réduit', (tester) async {
    await tester.pumpWidget(overlayApp(_tooltip(), disableAnimations: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short3 ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    final moving = tester.getRect(_bubble);
    await tester.pumpAndSettle();
    expect(tester.getRect(_bubble), moving);
  });

  testWidgets('devrait se montrer en fondu et se cacher par son contrôleur', (tester) async {
    final controller = FlTooltipController();
    await tester.pumpWidget(overlayApp(_tooltip(controller: controller)));
    controller.show();
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short3 ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    controller.hide();
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('devrait garder la bulle hors de l’arbre sémantique, le message n’étant lu qu’une fois', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = FlTooltipController();
    await tester.pumpWidget(overlayApp(_tooltip(controller: controller)));
    controller.show();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(_message), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait s’écarter de space.xs de plus et peindre une pointe vers l’enfant quand arrow est vrai', (
    tester,
  ) async {
    final controller = FlTooltipController();
    await tester.pumpWidget(
      overlayApp(
        Center(
          child: FlTooltip(
            message: _message,
            arrow: true,
            controller: controller,
            child: FlButton(label: 'Enregistrer', onPressed: () {}),
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
    final bubble = tester.getRect(find.ancestor(of: _bubble, matching: find.byType(DecoratedBox)).first);
    expect(bubble.bottom, closeTo(tester.getRect(_button).top - _gap - FlTokens.defaults.space.xs, 0.5));
    final paint = tester.widget<CustomPaint>(find.ancestor(of: _bubble, matching: find.byType(CustomPaint)).first);
    expect(paint.foregroundPainter, isNotNull);
  });

  testWidgets('devrait montrer content dans la bulle et garder message pour le lecteur d’écran', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = FlTooltipController();
    await tester.pumpWidget(
      overlayApp(
        Center(
          child: FlTooltip(
            message: 'Jane Doe, jane@example.com',
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Jane Doe'), Text('jane@example.com')],
            ),
            controller: controller,
            child: FlButton(label: 'Profil', onPressed: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSemantics(_button).parent, isSemantics(tooltip: 'Jane Doe, jane@example.com'));
    controller.show();
    await tester.pumpAndSettle();
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
    expect(find.text('Jane Doe, jane@example.com'), findsNothing);
    final style = DefaultTextStyle.of(tester.element(find.text('Jane Doe'))).style;
    expect(style.color, FlTokens.defaults.light.onSurface);
    semantics.dispose();
  });
}
