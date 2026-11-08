import 'dart:ui' show CheckedState, SemanticsRole, Tristate;

import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// La palette de démonstration : les sept teintes de la doc de HeroUI, plus
/// un blanc et un noir, les deux bouts qui éprouvent le filet et l’anneau.
const palette = [
  ('Rose', Color(0xFFF43F5E)),
  ('Fuchsia', Color(0xFFD946EF)),
  ('Violet', Color(0xFF8B5CF6)),
  ('Bleu', Color(0xFF3B82F6)),
  ('Cyan', Color(0xFF06B6D4)),
  ('Émeraude', Color(0xFF10B981)),
  ('Citron vert', Color(0xFF84CC16)),
  ('Blanc', Color(0xFFFAFAFA)),
  ('Noir', Color(0xFF18181B)),
];

class _Host extends StatefulWidget {
  const _Host({this.initial, this.disabled = const {}, this.enabled = true});

  final String? initial;
  final Set<String> disabled;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? value = widget.initial;
  final changes = <String>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: FlColorSwatchPicker<String>(
      semanticLabel: 'Couleur',
      value: value,
      enabled: widget.enabled,
      onChanged: (next) => setState(() {
        changes.add(next);
        value = next;
      }),
      items: [
        for (final (name, color) in palette)
          FlColorSwatchItem(value: name, color: color, label: name, disabled: widget.disabled.contains(name)),
      ],
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Finder _swatch(String name) => find.bySemanticsLabel(name);

void main() {
  testWidgets('devrait choisir la teinte touchée, et ignorer une teinte désactivée', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(disabled: {'Cyan'})));
    await tester.tap(_swatch('Bleu'));
    await tester.pumpAndSettle();
    await tester.tap(_swatch('Cyan'));
    await tester.pumpAndSettle();
    expect(_host(tester).changes, ['Bleu']);
    semantics.dispose();
  });

  testWidgets(
    "devrait s'annoncer comme un groupe de radios nommé, chaque teinte sous son nom, quand le lecteur d'écran le lit",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(initial: 'Violet')));
      final group = tester.getSemantics(find.byType(FlColorSwatchPicker<String>));
      expect(group.label, 'Couleur');
      final names = <String>[];
      final checked = <CheckedState>[];
      void visit(SemanticsNode node) {
        if (node.flagsCollection.isInMutuallyExclusiveGroup) {
          names.add(node.label);
          checked.add(node.flagsCollection.isChecked);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(group);
      expect(names, [for (final (name, _) in palette) name]);
      expect(checked.where((c) => c == CheckedState.isTrue), hasLength(1));
      expect(checked[2], CheckedState.isTrue);
      semantics.dispose();
    },
  );

  testWidgets(
    'devrait choisir la voisine aux flèches, sauter une teinte désactivée et revenir au début après la dernière',
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host(initial: 'Blanc', disabled: {'Noir'})));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_host(tester).changes, ['Rose', 'Blanc', 'Citron vert']);
    },
  );

  testWidgets('devrait ne rien choisir quand le groupe est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(enabled: false)));
    await tester.tap(_swatch('Rose'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_host(tester).changes, isEmpty);
  });

  testWidgets('devrait toucher une pastille de 32 dans une cible de 44 sur iOS et de 48 sur Android', (tester) async {
    for (final (platform, target) in [(TargetPlatform.iOS, 44.0), (TargetPlatform.android, 48.0)]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(), platform: platform));
      final rect = tester.getSemantics(_swatch('Violet')).rect;
      expect(rect.width, greaterThanOrEqualTo(target));
      expect(rect.height, greaterThanOrEqualTo(target));
      semantics.dispose();
    }
  });

  testWidgets(
    'devrait cerner la teinte choisie d’un anneau de sa teinte au bord de sa boîte, et la réduire dedans sous une coche (HeroUI v3)',
    (tester) async {
      for (final (size, shape) in [
        (FlColorSwatchSize.md, FlColorSwatchShape.circle),
        (FlColorSwatchSize.xl, FlColorSwatchShape.square),
      ]) {
        await tester.pumpWidget(
          toggleApp(
            FlColorSwatchPicker<int>(
              key: ValueKey(size),
              semanticLabel: 'Couleur',
              value: 0,
              size: size,
              shape: shape,
              onChanged: (_) {},
              items: const [
                FlColorSwatchItem(value: 0, color: Color(0xFF8B5CF6), label: 'Violet'),
                FlColorSwatchItem(value: 1, color: Color(0xFF3B82F6), label: 'Bleu'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final swatches = find.descendant(
          of: find.byType(FlColorSwatchPicker<int>),
          matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == size.extent && w.height == size.extent),
        );
        expect(swatches, findsNWidgets(2), reason: 'les deux pastilles à leur taille');
        final reach = -size.ring / 2;
        final box = Offset.zero & tester.getSize(swatches.first);
        final rings = <Rect>[];
        final painted = find.descendant(
          of: find.byType(FlColorSwatchPicker<int>),
          matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null),
        );
        expect(painted, findsOneWidget, reason: 'seule la teinte choisie porte un anneau et une coche');
        final scales = [
          for (final t in tester.widgetList<Transform>(find.descendant(of: painted, matching: find.byType(Transform))))
            t.transform.storage[0],
        ];
        expect(scales, contains(closeTo(0.77, 1e-6)), reason: size.name);
        expect(
          tester.renderObject(painted),
          paints..everything((method, arguments) {
            final paint = arguments.isEmpty ? null : arguments.last;
            if (paint is! Paint || paint.style != PaintingStyle.stroke || paint.color.toARGB32() != 0xFF8B5CF6) {
              return true;
            }
            expect(paint.strokeWidth, size.ring, reason: size.name);
            if (method == #drawCircle) {
              rings.add(Rect.fromCircle(center: arguments[0] as Offset, radius: arguments[1] as double));
            } else if (method == #drawRRect) {
              rings.add((arguments[0] as RRect).outerRect);
            }
            return true;
          }),
        );
        expect(rings, [box.inflate(reach)], reason: size.name);
      }
    },
  );

  testWidgets('devrait nommer le nœud radioGroup lui-même, sans conteneur à part (relecture B2)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(initial: 'Bleu')));
    final group = tester.getSemantics(find.byType(FlColorSwatchPicker<String>));
    expect(group.role, SemanticsRole.radioGroup);
    expect(group.label, 'Couleur');
    semantics.dispose();
  });

  testWidgets('devrait garder le focus sur sa teinte quand l’app en insère une devant (relecture B3)', (tester) async {
    final semantics = tester.ensureSemantics();
    var shown = palette.take(4).toList();
    late StateSetter update;
    await tester.pumpWidget(
      toggleApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return FlColorSwatchPicker<String>(
              semanticLabel: 'Couleur',
              value: 'Bleu',
              onChanged: (_) {},
              items: [for (final (name, color) in shown) FlColorSwatchItem(value: name, color: color, label: name)],
            );
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    bool focused(String name) => tester.getSemantics(_swatch(name)).flagsCollection.isFocused == Tristate.isTrue;
    expect(focused('Bleu'), isTrue);
    update(() => shown = [('Noir', const Color(0xFF18181B)), ...shown]);
    await tester.pumpAndSettle();
    expect(focused('Bleu'), isTrue);
    expect(focused('Rose'), isFalse);
    semantics.dispose();
  });

  testWidgets('devrait cerner d’un filet la seule teinte qui se confond avec le fond', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        FlColorSwatchPicker<String>(
          semanticLabel: 'Couleur',
          value: null,
          onChanged: (_) {},
          items: const [
            FlColorSwatchItem(value: 'Bleu', color: Color(0xFF3B82F6), label: 'Bleu'),
            FlColorSwatchItem(value: 'Blanc', color: Color(0xFFFAFAFA), label: 'Blanc'),
          ],
        ),
      ),
    );
    var edges = 0;
    expect(
      find.byType(FlColorSwatchPicker<String>),
      paints..everything((method, arguments) {
        final paint = arguments.whereType<Paint>().firstOrNull;
        if (paint != null && paint.style == PaintingStyle.stroke && (paint.color.a - 0.1).abs() < 0.01) edges++;
        return true;
      }),
    );
    expect(edges, 1);
  });
}
