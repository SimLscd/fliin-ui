import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fliin_ui/components/search_field/fl_search_field.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      child: OverlayHost(
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  ),
);

Widget _iconProbe(BuildContext context) {
  final icon = IconTheme.of(context);
  expect(icon.color, FlTokens.defaults.light.onSurfaceMuted);
  return SizedBox.square(key: const Key('icon'), dimension: icon.size);
}

Finder get _clear => find.descendant(of: find.byType(FlSearchField), matching: find.byType(FlPressable));

void main() {
  testWidgets('devrait poser une pilule compacte quand pill vaut true, et un champ rectangulaire sinon', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlSearchField(label: 'Rechercher', clearLabel: 'Effacer', pill: true)));
    expect(tester.widget<FlInput>(find.byType(FlInput)).compact, isTrue);
    await tester.pumpWidget(_app(const FlSearchField(label: 'Rechercher', clearLabel: 'Effacer')));
    expect(tester.widget<FlInput>(find.byType(FlInput)).compact, isFalse);
  });

  testWidgets("devrait montrer le bouton d'effacement tant que la saisie n'est pas vide, et l'effacer au toucher", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    var cleared = 0;
    await tester.pumpWidget(
      _app(
        FlSearchField(
          label: 'Rechercher',
          clearLabel: 'Effacer la recherche',
          onChanged: changes.add,
          onCleared: () => cleared++,
        ),
      ),
    );
    expect(_clear, findsNothing);
    final empty = tester.getRect(find.byType(EditableText));

    await tester.enterText(find.byType(EditableText), 'pomme');
    await tester.pump();
    expect(_clear, findsOneWidget);
    expect(tester.getRect(find.byType(EditableText)), empty, reason: 'le texte garde sa place');
    expect(tester.getSemantics(_clear).label, 'Effacer la recherche');

    await tester.tap(_clear);
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    expect(changes, ['pomme', '']);
    expect(cleared, 1);
    expect(_clear, findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'devrait poser la loupe au début et le texte à 36 du début, à space.md sans loupe, à 40 de la fin, dans les deux sens',
    (tester) async {
      for (final direction in TextDirection.values) {
        for (final (icon, inset) in [(true, 36.0), (false, FlTokens.defaults.space.md)]) {
          await tester.pumpWidget(
            _app(
              FlSearchField(label: 'Rechercher', clearLabel: 'Effacer', searchIcon: icon),
              direction: direction,
            ),
          );
          final frame = tester.getRect(find.byType(FlInputFrame));
          final text = tester.getRect(find.byType(EditableText));
          final reason = '${direction.name} loupe $icon';
          final start = direction == TextDirection.ltr ? text.left - frame.left : frame.right - text.right;
          final end = direction == TextDirection.ltr ? frame.right - text.right : text.left - frame.left;
          expect(start, inset, reason: reason);
          expect(end, 40, reason: reason);
        }
      }
    },
  );

  testWidgets("devrait garder le focus quand on clique sur le bouton d'effacement, sur bureau comme sur mobile", (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(_app(FlSearchField(key: ValueKey(platform), label: 'Rechercher', clearLabel: 'Effacer')));
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'pomme');
      await tester.pump();
      await tester.tap(_clear);
      await tester.pump();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty, reason: platform.name);
      expect(editable.focusNode.hasFocus, isTrue, reason: platform.name);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('devrait lire désactivé et invalide du FlFieldScope, sauf quand le champ les dit lui-même', (
    tester,
  ) async {
    Widget field({bool? disabled}) => FlFieldScope(
      disabled: true,
      invalid: true,
      child: FlSearchField(label: 'Rechercher', clearLabel: 'Effacer', disabled: disabled),
    );
    await tester.pumpWidget(_app(field()));
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.canRequestFocus, isFalse);
    expect(tester.widget<FlInputFrame>(find.byType(FlInputFrame)).invalid, isTrue);
    await tester.pumpWidget(_app(field(disabled: false)));
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.canRequestFocus, isTrue);
  });

  testWidgets('devrait montrer trailing tant que le champ est vide, puis le bouton d’effacement à sa place', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        FlSearchField(
          label: 'Rechercher',
          clearLabel: 'Effacer',
          controller: controller,
          trailing: const SizedBox(key: Key('kbd'), width: 24, height: 16),
        ),
      ),
    );
    final frame = tester.getRect(find.byType(FlInputFrame));
    expect(frame.right - tester.getRect(find.byKey(const Key('kbd'))).right, FlTokens.defaults.space.sm);
    expect(_clear, findsNothing);
    controller.text = 'thé';
    await tester.pump();
    expect(find.byKey(const Key('kbd')), findsNothing);
    expect(_clear, findsOneWidget);
  });

  testWidgets('devrait remplacer la loupe par icon, à la taille et la couleur de la loupe', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlSearchField(
          label: 'Lieux',
          clearLabel: 'Effacer',
          icon: Builder(builder: _iconProbe),
        ),
      ),
    );
    final theme = FlScope.of(tester.element(find.byType(FlInput)));
    final probe = tester.widget<SizedBox>(find.byKey(const Key('icon')));
    expect(probe.width, theme.size.indicatorIcon);
    expect(find.byType(FlIcon), findsNothing, reason: 'plus de loupe');
  });

  testWidgets('devrait proposer la touche rechercher et rendre la saisie à sa validation', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _app(FlSearchField(label: 'Rechercher', clearLabel: 'Effacer', onSubmitted: submitted.add)),
    );
    expect(tester.widget<EditableText>(find.byType(EditableText)).textInputAction, TextInputAction.search);
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'poire');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, ['poire']);
  });

  testWidgets(
    'devrait pâlir fond, saisie et loupe une fois, retirer le bouton et refuser le focus, quand le champ est désactivé',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'pomme');
      addTearDown(controller.dispose);
      const shot = Key('shot');
      Future<_Pixels> render({required bool disabled}) async {
        await tester.pumpWidget(
          _app(
            RepaintBoundary(
              key: shot,
              child: FlSearchField(
                label: 'Rechercher',
                clearLabel: 'Effacer',
                controller: controller,
                disabled: disabled,
              ),
            ),
          ),
        );
        return _Pixels.of(tester, shot);
      }

      await render(disabled: false);
      expect(_clear, findsOneWidget);
      final disabled = await render(disabled: true);
      expect(_clear, findsNothing, reason: 'le bouton disparaît : il ne pourrait pas servir');
      final alpha = (FlTokens.defaults.size.disabledOpacity * 255).round();
      final loupe = tester.getRect(find.descendant(of: find.byType(Transform), matching: find.byType(CustomPaint)));
      // Pâle sur un fond pâle : ni pleine, ni invisible.
      expect(disabled.maxAlpha(loupe), lessThan(255), reason: 'la loupe pâlit avec le champ');
      final frame = tester.getRect(find.byType(FlInputFrame));
      expect(disabled.alpha(Offset(frame.center.dx, frame.top + 2)), alpha, reason: 'le fond pâlit une fois');
      expect(
        disabled.maxAlpha(tester.getRect(find.byType(EditableText))),
        alpha,
        reason: 'la saisie pâlit avec le fond, une fois',
      );

      expect(tester.getSemantics(find.byType(FlSearchField)), isNot(matchesSemantics(isButton: true)));
      expect(find.bySemanticsLabel('Effacer'), findsNothing, reason: "le bouton n'est pas annoncé");
      expect(controller.text, 'pomme');
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.canRequestFocus, isFalse);
      semantics.dispose();
    },
  );
}

/// Les pixels d'un `RepaintBoundary`, au double de la densité, en RGBA
/// non prémultiplié.
class _Pixels {
  _Pixels(this._origin, this._width, this._bytes);

  static const double _ratio = 2;

  static Future<_Pixels> of(WidgetTester tester, Key key) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final width = image.width;
      image.dispose();
      return (width, data!);
    });
    return _Pixels(tester.getTopLeft(find.byKey(key)), bytes!.$1, bytes.$2);
  }

  final Offset _origin;
  final int _width;
  final ByteData _bytes;

  Iterable<(int, int)> _cells(Rect rect) sync* {
    final local = rect.shift(-_origin);
    for (var y = (local.top * _ratio).ceil(); y < (local.bottom * _ratio).floor(); y++) {
      for (var x = (local.left * _ratio).ceil(); x < (local.right * _ratio).floor(); x++) {
        yield (x, y);
      }
    }
  }

  int _at(int x, int y) => _bytes.getUint32((y * _width + x) * 4);

  /// Les couleurs RGBA de [rect], ligne par ligne.
  List<int> region(Rect rect) => [for (final (x, y) in _cells(rect)) _at(x, y)];

  /// L'alpha le plus haut de [rect].
  int maxAlpha(Rect rect) => _cells(rect).map((cell) => _at(cell.$1, cell.$2) & 0xFF).reduce(math.max);

  /// L'alpha du pixel sous [point].
  int alpha(Offset point) =>
      _at(((point.dx - _origin.dx) * _ratio).floor(), ((point.dy - _origin.dy) * _ratio).floor()) & 0xFF;
}
