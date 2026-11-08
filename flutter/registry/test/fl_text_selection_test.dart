import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';
import 'support/tokens.dart';
import 'torture/themes.dart';
import 'torture/torture.g.dart';

const _text = 'Rendez-vous demain à midi';
const _wordStart = 12;
const _wordEnd = 18;

Widget _app(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  AlignmentGeometry alignment = Alignment.center,
  double scale = 1,
  bool systemMenu = false,
  FlTokens? tokens,
  FlDensity? density,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      supportsShowingSystemContextMenu: systemMenu,
      padding: padding,
      viewInsets: viewInsets,
    ),
    child: Directionality(
      textDirection: direction,
      child: FlScope(
        tokens: tokens,
        density: density,
        brightness: Brightness.light,
        child: OverlayHost(
          child: Align(
            alignment: alignment,
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    ),
  ),
);

/// Un presse-papiers simulé sur le canal de plateforme, et les appels reçus.
class _Platform {
  _Platform(WidgetTester tester, {this.clipboard}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, _handle);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  String? clipboard;
  final calls = <String>[];

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call.method);
    return switch (call.method) {
      'Clipboard.setData' => clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?,
      'Clipboard.getData' => clipboard == null ? null : {'text': clipboard},
      'Clipboard.hasStrings' => {'value': clipboard?.isNotEmpty ?? false},
      _ => null,
    };
  }
}

EditableTextState _field(WidgetTester tester) => tester.state<EditableTextState>(find.byType(EditableText));

RenderEditable _render(WidgetTester tester) => _field(tester).renderEditable;

Offset _caret(WidgetTester tester, int offset) {
  final render = _render(tester);
  return render.localToGlobal(render.getLocalRectForCaret(TextPosition(offset: offset)).center);
}

/// Les extrémités de la sélection, en bas de ligne, dans le repère global.
List<Offset> _endpoints(WidgetTester tester) {
  final render = _render(tester);
  return [
    for (final point in render.getEndpointsForSelection(_field(tester).textEditingValue.selection))
      render.localToGlobal(point.point),
  ];
}

/// Les poignées peintes par [painter] et visibles : le SDK garde dans
/// l'arbre, à l'opacité nulle, celles qu'il cache.
Finder _painted(String painter) => find.byElementPredicate(
  (element) =>
      element.widget is CustomPaint &&
      (element.widget as CustomPaint).painter.runtimeType.toString() == painter &&
      find
          .ancestor(of: find.byElementPredicate((e) => e == element), matching: find.byType(FadeTransition))
          .evaluate()
          .every((fade) => (fade.widget as FadeTransition).opacity.value > 0),
);

final _toolbar = find.byType(FlTextSelectionToolbar);

Finder _button(String label) => find.descendant(of: _toolbar, matching: find.widgetWithText(FlPressable, label));

List<String> _labels(WidgetTester tester) => [
  for (final pressable in tester.widgetList<FlPressable>(
    find.descendant(of: _toolbar, matching: find.byType(FlPressable)),
  ))
    pressable.label!,
];

/// Un appui long sur « demain » : le mot est sélectionné, poignées et barre
/// apparaissent (Android).
Future<void> _longPressWord(WidgetTester tester) async {
  await tester.longPressAt(_caret(tester, _wordStart + 2));
  await tester.pumpAndSettle();
}

/// Un double toucher sur « demain » : le geste de sélection d'un mot sur iOS.
Future<void> _doubleTapWord(WidgetTester tester, {int at = _wordStart + 2}) async {
  final position = _caret(tester, at);
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

Rect _barRect(WidgetTester tester) =>
    tester.getRect(find.descendant(of: _toolbar, matching: find.byType(DecoratedBox)).first);

/// Le cadre visible du champ.
Rect _frameRect(WidgetTester tester) => tester.getRect(find.byType(FlInputFrame));

/// Sélectionne « demain » du geste de la plateforme et attend la barre.
Future<void> _selectWord(WidgetTester tester) =>
    defaultTargetPlatform == TargetPlatform.iOS ? _doubleTapWord(tester) : _longPressWord(tester);

/// Le coin du quart carré d'une goutte, sa pointe, dans le repère global :
/// le coin haut-gauche de la boîte avant sa rotation.
Offset _tip(WidgetTester tester, Element drop) => (drop.renderObject! as RenderBox).localToGlobal(Offset.zero);

void main() {
  late TextEditingController controller;
  setUp(() => controller = TextEditingController(text: _text));
  tearDown(() => controller.dispose());

  group('poignées', () {
    testWidgets(
      'devrait poser la pointe de chaque goutte sur une extrémité de la sélection après un appui long sur Android',
      (tester) async {
        _Platform(tester);
        await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
        await _longPressWord(tester);
        expect(controller.selection, const TextSelection(baseOffset: 12, extentOffset: 18));
        final drops = _painted('_DropPainter').evaluate().toList();
        expect(drops, hasLength(2));
        final tips = [for (final drop in drops) _tip(tester, drop)];
        final ends = _endpoints(tester);
        for (final end in ends) {
          expect(tips.any((tip) => (tip - end).distance < 0.01), isTrue, reason: 'pointe sur $end, pointes $tips');
        }
        final size = FlTokens.defaults.size.selectionHandleAndroid;
        expect(
          tester.getSize(find.ancestor(of: _painted('_DropPainter'), matching: find.byType(SizedBox)).first),
          Size.square(size),
        );
      },
    );

    testWidgets('devrait poser la pointe de la goutte du curseur sous le curseur après un toucher sur Android', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await tester.tapAt(_caret(tester, _wordStart));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
      final drops = _painted('_DropPainter').evaluate().toList();
      expect(drops, hasLength(1));
      final [caret] = _endpoints(tester);
      expect(_tip(tester, drops.single), offsetMoreOrLessEquals(caret, epsilon: 0.01));
    });

    testWidgets('devrait poser les gouttes sur la sélection quand le texte va de droite à gauche', (tester) async {
      _Platform(tester);
      controller.text = 'موعدنا غدا عند الظهر';
      await tester.pumpWidget(
        _app(
          FlTextField(label: 'موعد', controller: controller),
          direction: TextDirection.rtl,
        ),
      );
      await tester.longPressAt(_caret(tester, 8));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);
      final tips = [for (final drop in _painted('_DropPainter').evaluate()) _tip(tester, drop)];
      expect(tips, hasLength(2));
      for (final end in _endpoints(tester)) {
        expect(tips.any((tip) => (tip - end).distance < 0.01), isTrue, reason: 'pointe sur $end, pointes $tips');
      }
    });

    testWidgets('devrait dresser la tige iOS sur la ligne sélectionnée, pastille en haut au début et en bas à la fin', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _doubleTapWord(tester);
      expect(controller.selection, const TextSelection(baseOffset: 12, extentOffset: 18));
      final knobs = _painted('_KnobPainter').evaluate().map((e) => (e.renderObject! as RenderBox)).toList()
        ..sort((a, b) => a.localToGlobal(Offset.zero).dx.compareTo(b.localToGlobal(Offset.zero).dx));
      expect(knobs, hasLength(2));
      final [start, end] = _endpoints(tester);
      final line = _render(tester).preferredLineHeight;
      final knob = FlTokens.defaults.size.selectionKnobIos;
      final first = knobs.first.localToGlobal(Offset.zero) & knobs.first.size;
      final last = knobs.last.localToGlobal(Offset.zero) & knobs.last.size;
      expect(first.bottomCenter, offsetMoreOrLessEquals(start));
      expect(first.height, line + knob);
      expect(last.topCenter, offsetMoreOrLessEquals(end - Offset(0, line)));
      expect(last.height, line + knob);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('devrait laisser saisir une goutte à une demi-cible de la plateforme de son centre', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      final drops = _painted('_DropPainter')
          .evaluate()
          .map((e) => tester.getCenter(find.byElementPredicate((x) => x == e)));
      final right = drops.reduce((a, b) => a.dx > b.dx ? a : b);
      final hitTarget = FlScope.of(tester.element(find.byType(EditableText))).hitTarget;
      final gesture = await tester.startGesture(right + Offset(hitTarget / 2 - 1, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(Offset(_caret(tester, _text.length).dx - right.dx, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selection.extentOffset, greaterThan(_wordEnd));
    });

    testWidgets('devrait sélectionner sans poignées ni barre quand on sélectionne à la souris', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      final gesture = await tester.startGesture(_caret(tester, _wordStart), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_caret(tester, _wordEnd));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);
      expect(_painted('_DropPainter'), findsNothing);
      expect(_toolbar, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('devrait ne montrer ni poignées ni barre quand le champ est désactivé', (tester) async {
      _Platform(tester, clipboard: 'x');
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller, enabled: false)));
      await tester.longPressAt(_caret(tester, _wordStart + 2));
      await tester.pumpAndSettle();
      expect(_painted('_DropPainter'), findsNothing);
      expect(_toolbar, findsNothing);
    });
  });

  group('barre', () {
    testWidgets('devrait copier la sélection dans le presse-papiers quand on touche Copy', (tester) async {
      final platform = _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      expect(_labels(tester), ['Cut', 'Copy', 'Share', 'Select all']);
      await tester.tap(_button('Copy'));
      await tester.pumpAndSettle();
      expect(platform.clipboard, 'demain');
      expect(controller.text, _text);
    });

    testWidgets('devrait couper la sélection quand on touche Cut', (tester) async {
      final platform = _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      await tester.tap(_button('Cut'));
      await tester.pumpAndSettle();
      expect(platform.clipboard, 'demain');
      expect(controller.text, 'Rendez-vous  à midi');
    });

    testWidgets('devrait coller le presse-papiers à la place de la sélection quand on touche Paste', (tester) async {
      _Platform(tester, clipboard: 'jeudi');
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      expect(_labels(tester), ['Cut', 'Copy', 'Paste', 'Share', 'Select all']);
      await tester.tap(_button('Paste'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Rendez-vous jeudi à midi');
    });

    testWidgets('devrait tout sélectionner quand on touche Select all', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      await tester.tap(_button('Select all'));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: _text.length));
    });

    testWidgets('devrait ne proposer ni couper ni coller quand le champ est en lecture seule', (tester) async {
      _Platform(tester, clipboard: 'jeudi');
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => EditableText(
              controller: controller,
              focusNode: focus,
              readOnly: true,
              style: const TextStyle(fontSize: 17),
              cursorColor: const Color(0xFF000000),
              backgroundCursorColor: const Color(0xFF000000),
              selectionControls: FlTextSelectionControls(FlScope.of(context)),
              contextMenuBuilder: flTextContextMenuBuilder(context),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      _field(tester)
        ..userUpdateTextEditingValue(
          controller.value.copyWith(selection: const TextSelection(baseOffset: 12, extentOffset: 18)),
          SelectionChangedCause.longPress,
        )
        ..showToolbar();
      await tester.pumpAndSettle();
      expect(_labels(tester), ['Copy', 'Share', 'Select all']);
    });

    testWidgets('devrait se poser au-dessus de la sélection, centrée, sans couvrir les poignées', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      final bar = tester.getRect(find.descendant(of: _toolbar, matching: find.byType(DecoratedBox)).first);
      final [start, end] = _endpoints(tester);
      final lineTop = start.dy - _render(tester).preferredLineHeight;
      expect(bar.bottom, lessThanOrEqualTo(lineTop));
      expect(bar.center.dx, moreOrLessEquals((start.dx + end.dx) / 2, epsilon: 0.5));
    });

    testWidgets('devrait se retourner sous la sélection et ses poignées quand le champ est en haut de l’écran', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(
        _app(
          FlTextField(label: 'Note', controller: controller),
          alignment: Alignment.topCenter,
        ),
      );
      await _longPressWord(tester);
      final bar = tester.getRect(find.descendant(of: _toolbar, matching: find.byType(DecoratedBox)).first);
      final dropBottom = _painted('_DropPainter').evaluate().map((e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(box.size.bottomRight(Offset.zero)).dy;
      });
      final [start, _] = _endpoints(tester);
      expect(bar.top, greaterThan(start.dy + FlTokens.defaults.size.selectionHandleAndroid - 0.01));
      expect(bar.top, greaterThanOrEqualTo(dropBottom.reduce((a, b) => a > b ? a : b) - 0.01));
    });

    testWidgets('devrait ranger les actions de droite à gauche quand le champ est dans une zone de droite à gauche', (
      tester,
    ) async {
      _Platform(tester);
      // La barre est posée dans l'overlay racine, de gauche à droite ici : elle suit le champ.
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: FlTextField(label: 'Note', controller: controller),
          ),
        ),
      );
      await _longPressWord(tester);
      final cut = tester.getCenter(_button('Cut'));
      final copy = tester.getCenter(_button('Copy'));
      expect(cut.dx, greaterThan(copy.dx));
      expect(cut.dy, copy.dy);
    });

    testWidgets('devrait passer à la ligne sans déborder quand le texte est à 2.0×', (tester) async {
      _Platform(tester);
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller), scale: 2));
      // À 2.0×, « demain » défile hors du champ : le premier mot.
      await _doubleTapWord(tester, at: 2);
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 6));
      expect(tester.takeException(), isNull);
      final rows = {for (final label in _labels(tester)) tester.getRect(_button(label)).top};
      expect(rows.length, greaterThan(1));
      final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      for (final label in _labels(tester)) {
        final rect = tester.getRect(_button(label));
        expect(
          screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
          reason: '$label $rect',
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('devrait annoncer chaque action comme un bouton nommé et activé', (tester) async {
      final semantics = tester.ensureSemantics();
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      expect(
        tester.getSemantics(_button('Copy')),
        matchesSemantics(
          label: 'Copy',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('devrait se fermer à Échap depuis le champ, et quand le focus quitte le champ pour un bouton', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_toolbar, findsNothing);

      _field(tester).showToolbar();
      await tester.pumpAndSettle();
      expect(_toolbar, findsOneWidget);
      Focus.of(tester.element(find.descendant(of: _button('Copy'), matching: find.byType(Text)))).requestFocus();
      await tester.pumpAndSettle();
      expect(_toolbar, findsNothing);
    });

    testWidgets('devrait s’ouvrir en liste sous le pointeur au clic droit sur bureau', (tester) async {
      _Platform(tester, clipboard: 'jeudi');
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      final at = _caret(tester, _wordStart + 2);
      await tester.tapAt(at, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_toolbar, findsOneWidget);
      final labels = _labels(tester);
      expect(labels, ['Paste', 'Select all']);
      final rects = [for (final label in labels) tester.getRect(_button(label))];
      expect({for (final rect in rects) rect.left}, hasLength(1));
      expect(rects.first.top, greaterThan(at.dy));
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('menu du système iOS', () {
    testWidgets('devrait demander le menu d’édition du système plutôt que la barre dessinée quand iOS le permet', (
      tester,
    ) async {
      final platform = _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller), systemMenu: true));
      await _doubleTapWord(tester);
      expect(platform.calls, contains('ContextMenu.showSystemContextMenu'));
      expect(_toolbar, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('devrait dessiner la barre sur iOS quand le système ne propose pas son menu', (tester) async {
      final platform = _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _doubleTapWord(tester);
      expect(platform.calls, isNot(contains('ContextMenu.showSystemContextMenu')));
      expect(_labels(tester), containsAllInOrder(['Cut', 'Copy']));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('barre et cadre du champ', () {
    for (final theme in flTestThemes) {
      testWidgets('devrait laisser le cadre du champ visible sous la barre, sous le thème ${theme.id}', (tester) async {
        _Platform(tester);
        await tester.pumpWidget(
          _app(
            FlTextField(label: 'Note', controller: controller),
            tokens: theme.tokens,
            density: theme.density,
          ),
        );
        await _selectWord(tester);
        expect(_barRect(tester).bottom, lessThanOrEqualTo(_frameRect(tester).top - theme.tokens.space.xs + 0.01));
      }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

      testWidgets(
        'devrait laisser le cadre du champ visible au-dessus de la barre retournée, sous le thème ${theme.id}',
        (tester) async {
          _Platform(tester);
          await tester.pumpWidget(
            _app(
              FlTextField(label: 'Note', controller: controller),
              tokens: theme.tokens,
              density: theme.density,
              alignment: Alignment.topCenter,
            ),
          );
          await _selectWord(tester);
          expect(_barRect(tester).top, greaterThanOrEqualTo(_frameRect(tester).bottom + theme.tokens.space.xs - 0.01));
        },
        variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
      );
    }

    testWidgets('devrait laisser la pastille iOS du début visible sous la barre', (tester) async {
      _Platform(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      // Sans cadre : seule la pastille écarte la barre de la sélection.
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => EditableText(
              controller: controller,
              focusNode: focus,
              showSelectionHandles: true,
              style: const TextStyle(fontSize: 17),
              cursorColor: const Color(0xFF000000),
              backgroundCursorColor: const Color(0xFF000000),
              selectionControls: FlTextSelectionControls(FlScope.of(context)),
              contextMenuBuilder: flTextContextMenuBuilder(context),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      _field(tester)
        ..userUpdateTextEditingValue(
          controller.value.copyWith(
            selection: const TextSelection(baseOffset: _wordStart, extentOffset: _wordEnd),
          ),
          SelectionChangedCause.longPress,
        )
        ..showToolbar();
      await tester.pumpAndSettle();
      final knobTop = _painted('_KnobPainter')
          .evaluate()
          .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)).top)
          .reduce((a, b) => a < b ? a : b);
      expect(_barRect(tester).bottom, lessThanOrEqualTo(knobTop - FlTokens.defaults.space.xs + 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('devrait rester dans la zone sûre, hors de l’encoche et au-dessus du clavier', (tester) async {
      _Platform(tester);
      const padding = EdgeInsets.only(top: 59);
      const keyboard = EdgeInsets.only(bottom: 300);
      await tester.pumpWidget(
        _app(
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 70),
            child: FlTextField(label: 'Note', controller: controller),
          ),
          alignment: Alignment.topCenter,
          padding: padding,
          viewInsets: keyboard,
        ),
      );
      await _longPressWord(tester);
      final bar = _barRect(tester);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(bar.top, greaterThanOrEqualTo(padding.top));
      expect(bar.bottom, lessThanOrEqualTo(height - keyboard.bottom));
    });

    testWidgets('devrait reprendre le thème du champ quand l’overlay racine est sous un autre thème', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(
        _app(
          FlScope(
            tokens: tortureB,
            child: FlTextField(label: 'Note', controller: controller),
          ),
        ),
      );
      await _longPressWord(tester);
      final panel = tester.widget<DecoratedBox>(
        find.descendant(of: _toolbar, matching: find.byType(DecoratedBox)).first,
      );
      expect(tortureB.shape.radiusCard, isNot(FlTokens.defaults.shape.radiusCard));
      expect((panel.decoration as BoxDecoration).borderRadius, BorderRadius.circular(tortureB.shape.radiusCard));
    });

    testWidgets('devrait écrire ses actions dans le style de texte du champ, pas dans celui de l’overlay racine', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(
        _app(
          DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Champ'),
            child: FlTextField(label: 'Note', controller: controller),
          ),
        ),
      );
      await _longPressWord(tester);
      final copy = tester.renderObject<RenderParagraph>(
        find.descendant(of: _button('Copy'), matching: find.byType(RichText)),
      );
      expect(copy.text.style?.fontFamily, 'Champ');
    });

    testWidgets('devrait cacher la barre quand la page défile et le champ sort de l’écran', (tester) async {
      _Platform(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 600,
            child: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 300),
                FlTextField(label: 'Note', controller: controller),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await _longPressWord(tester);
      expect(_toolbar, findsOneWidget);
      // Au doigt, lentement : un `jumpTo` finit son défilement avant le
      // layout, et la barre remontrée lirait l'ancienne position du champ.
      await tester.timedDragFrom(const Offset(400, 500), const Offset(0, -330), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (_toolbar.evaluate().isNotEmpty) {
        final bar = _barRect(tester);
        expect(bar.top >= 0 && bar.bottom <= height, isTrue, reason: '$bar');
      }
      await tester.timedDragFrom(const Offset(400, 500), const Offset(0, -300), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(500));
      expect(_toolbar, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('gestes et cas', () {
    testWidgets('devrait montrer puis cacher la barre quand on touche la goutte du curseur', (tester) async {
      _Platform(tester, clipboard: 'x');
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await tester.tapAt(_caret(tester, _wordStart));
      await tester.pumpAndSettle();
      expect(_toolbar, findsNothing);
      final drop = _painted('_DropPainter');
      await tester.tapAt(tester.getCenter(drop));
      await tester.pumpAndSettle();
      expect(_toolbar, findsOneWidget);
      await tester.tapAt(tester.getCenter(drop));
      await tester.pumpAndSettle();
      expect(_toolbar, findsNothing);
    });

    testWidgets('devrait garder la pointe sur la sélection et saisir la goutte à toute la cible quand elle passe 48', (
      tester,
    ) async {
      _Platform(tester);
      final tokens = tokensWithAndroidTarget(56);
      await tester.pumpWidget(
        _app(
          FlTextField(label: 'Note', controller: controller),
          tokens: tokens,
        ),
      );
      await _longPressWord(tester);
      final drops = _painted('_DropPainter').evaluate().toList();
      final ends = _endpoints(tester);
      for (final drop in drops) {
        final tip = _tip(tester, drop);
        expect(ends.any((end) => (tip - end).distance < 0.01), isTrue, reason: 'pointe $tip, extrémités $ends');
      }
      final right = drops
          .map((e) => tester.getCenter(find.byElementPredicate((x) => x == e)))
          .reduce((a, b) => a.dx > b.dx ? a : b);
      final gesture = await tester.startGesture(right + const Offset(56 / 2 - 1, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(Offset(_caret(tester, _text.length).dx - right.dx, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selection.extentOffset, greaterThan(_wordEnd));
    });

    testWidgets('devrait cacher les poignées quand la sélection change au clavier', (tester) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      expect(_painted('_DropPainter'), findsNWidgets(2));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(controller.selection.extentOffset, _wordEnd + 1);
      expect(_painted('_DropPainter'), findsNothing);
    });

    testWidgets('devrait ne proposer ni copier ni couper quand la saisie est masquée', (tester) async {
      _Platform(tester, clipboard: 'x');
      controller.text = 'motdepasse';
      await tester.pumpWidget(_app(FlTextField(label: 'Mot de passe', controller: controller, obscureText: true)));
      await tester.longPressAt(_caret(tester, 3));
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);
      expect(_labels(tester), isNot(contains('Copy')));
      expect(_labels(tester), isNot(contains('Cut')));
      expect(_labels(tester), contains('Paste'));
    }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

    for (final direction in TextDirection.values) {
      testWidgets('devrait aligner la liste du clic droit sur le pointeur, du côté du début (${direction.name})', (
        tester,
      ) async {
        _Platform(tester, clipboard: 'x');
        await tester.pumpWidget(
          _app(
            FlTextField(label: 'Note', controller: controller),
            direction: direction,
          ),
        );
        final at = _caret(tester, _wordStart + 2);
        await tester.tapAt(at, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        final bar = _barRect(tester);
        expect(direction == TextDirection.ltr ? bar.left : bar.right, moreOrLessEquals(at.dx, epsilon: 0.5));
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }

    testWidgets('devrait fermer la liste du clic droit quand on sélectionne en glissant à la souris', (tester) async {
      _Platform(tester, clipboard: 'x');
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await tester.tapAt(_caret(tester, _wordStart), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_toolbar, findsOneWidget);
      final gesture = await tester.startGesture(_caret(tester, 2), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(_caret(tester, 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);
      expect(_toolbar, findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('devrait fermer la barre et cacher les poignées quand le champ est désactivé pendant la sélection', (
      tester,
    ) async {
      _Platform(tester);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller)));
      await _longPressWord(tester);
      expect(_toolbar, findsOneWidget);
      await tester.pumpWidget(_app(FlTextField(label: 'Note', controller: controller, enabled: false)));
      await tester.pumpAndSettle();
      expect(_toolbar, findsNothing);
      expect(_painted('_DropPainter'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('géométrie des poignées iOS', () {
    const line = 20.0;
    final theme = FlTheme(
      tokens: FlTokens.defaults,
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      density: FlDensity.comfortable,
      reduceMotion: false,
    );
    final controls = FlTextSelectionControls(theme);
    final knob = FlTokens.defaults.size.selectionKnobIos;

    /// Le centre de la pastille, relatif à l'ancre de la poignée, posée en bas
    /// de la ligne.
    Future<Offset> knobFromAnchor(WidgetTester tester, TextSelectionHandleType type) async {
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: Builder(builder: (context) => controls.buildHandle(context, type, line)),
        ),
      );
      final paint = find.byType(CustomPaint).last;
      final origin = tester.getTopLeft(paint);
      final size = tester.getSize(paint);
      final center = Offset(size.width / 2, type == TextSelectionHandleType.left ? knob / 2 : size.height - knob / 2);
      expect(tester.renderObject(paint), paints..circle(x: center.dx, y: center.dy, radius: knob / 2));
      return origin + center - controls.getHandleAnchor(type, line);
    }

    testWidgets('devrait poser la pastille du début au-dessus de la ligne', (tester) async {
      expect(await knobFromAnchor(tester, TextSelectionHandleType.left), Offset(0, -line - knob / 2));
    });

    testWidgets('devrait poser la pastille de fin sous la ligne', (tester) async {
      expect(await knobFromAnchor(tester, TextSelectionHandleType.right), Offset(0, knob / 2));
    });

    test('devrait centrer la zone du curseur sur sa ligne', () {
      final size = controls.getHandleSize(line);
      final anchor = controls.getHandleAnchor(TextSelectionHandleType.collapsed, line);
      expect(size.center(Offset.zero) - anchor, const Offset(0, -line / 2));
    });

    test('devrait comparer deux contrôles par ce qu’ils dessinent, pas par l’identité des jetons', () {
      final copy = FlTheme(
        tokens: tokensWithAndroidTarget(FlTokens.defaults.size.hitTargetAndroid),
        brightness: Brightness.light,
        platform: TargetPlatform.iOS,
        density: FlDensity.comfortable,
        reduceMotion: false,
      );
      expect(FlTextSelectionControls(copy), FlTextSelectionControls(theme));
    });
  });
}
