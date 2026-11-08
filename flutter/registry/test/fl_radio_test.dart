import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';
import 'torture/torture.g.dart';

enum _Delivery { standard, express, pickup }

class _Host extends StatefulWidget {
  const _Host({this.initial, this.disabled = const {}});

  final _Delivery? initial;
  final Set<_Delivery> disabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late _Delivery? value = widget.initial;
  final changes = <_Delivery?>[];

  @override
  Widget build(BuildContext context) => RadioGroup<_Delivery>(
    groupValue: value,
    onChanged: (next) => setState(() {
      changes.add(next);
      value = next;
    }),
    // La cible de chaque radio déborde de 12 au plus : l'écart les sépare.
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        for (final option in _Delivery.values)
          FlRadio(value: option, label: option.name, enabled: !widget.disabled.contains(option)),
      ],
    ),
  );
}

List<_Delivery?> _changes(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).changes;

Finder _radio(_Delivery option) =>
    controlOf(find.byWidgetPredicate((widget) => widget is FlRadio && widget.value == option));

/// Le rond de 24 de l'option, sous son ombre ; la pastille, quand elle est choisie, en est la seconde ombre.
Finder _dot(_Delivery option) => find.descendant(of: _radio(option), matching: find.byType(FlShadow)).first;

Finder _shadows(_Delivery option) => find.descendant(of: _radio(option), matching: find.byType(FlShadow));

double _thumbScale(WidgetTester tester, _Delivery option) => tester
    .widget<Transform>(find.descendant(of: _radio(option), matching: find.byType(Transform)))
    .transform
    .storage[0];

Color? _fill(WidgetTester tester, Finder radio) =>
    (tester.widgetList<DecoratedBox>(find.descendant(of: radio, matching: find.byType(DecoratedBox))).first.decoration
            as ShapeDecoration)
        .color;

double _indicatorOpacity(WidgetTester tester, Finder radio) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.descendant(of: radio, matching: find.byType(FlShadow)).first,
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets(
    "devrait s'annoncer comme une option cochée d'un groupe exclusif, activée et étiquetée, quand elle est choisie",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(initial: _Delivery.express)));
      expect(
        tester.getSemantics(_radio(_Delivery.express)),
        matchesSemantics(
          label: 'express',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    "devrait s'annoncer sélectionnée ou non, avec l'indice de Flutter et sans action de focus, quand la plateforme est iOS",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(initial: _Delivery.express), platform: TargetPlatform.iOS));
      expect(
        tester.getSemantics(_radio(_Delivery.standard)),
        matchesSemantics(
          label: 'standard',
          hint: const DefaultWidgetsLocalizations().radioButtonUnselectedLabel,
          hasCheckedState: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(_radio(_Delivery.express)),
        matchesSemantics(
          label: 'express',
          hasCheckedState: true,
          isChecked: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets("devrait s'annoncer désactivée, sans action, et ignorer le toucher quand enabled est faux", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(disabled: {_Delivery.pickup})));
    await tester.tap(_radio(_Delivery.pickup), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_changes(tester), isEmpty);
    expect(
      tester.getSemantics(_radio(_Delivery.pickup)),
      matchesSemantics(label: 'pickup', hasCheckedState: true, isInMutuallyExclusiveGroup: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets("devrait nommer le RadioGroup attendu en debug quand une option activée n'en a pas au-dessus", (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const FlRadio(value: _Delivery.standard, label: 'standard')));
    expect(
      tester.takeException(),
      isA<AssertionError>().having((e) => '${e.message}', 'message', contains('RadioGroup<_Delivery>')),
    );
  });

  testWidgets("devrait nommer le type attendu quand le RadioGroup au-dessus est d'un autre type", (tester) async {
    await tester.pumpWidget(
      toggleApp(
        RadioGroup<_Delivery?>(
          groupValue: null,
          onChanged: (_) {},
          child: const FlRadio(value: _Delivery.standard, label: 'standard'),
        ),
      ),
    );
    expect(
      tester.takeException(),
      isA<AssertionError>().having((e) => '${e.message}', 'message', contains('RadioGroup<_Delivery>')),
    );
  });

  testWidgets(
    "devrait se déclarer désactivée sans erreur quand elle est désactivée et qu'aucun RadioGroup ne l'entoure",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const FlRadio(value: _Delivery.standard, label: 'standard', enabled: false)));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(controlOf(find.byType(FlRadio<_Delivery>))),
        matchesSemantics(
          label: 'standard',
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets('devrait choisir son option et poser sa pastille quand on la touche', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(_shadows(_Delivery.express), findsOneWidget);
    await tester.tap(_radio(_Delivery.express));
    await tester.pumpAndSettle();
    expect(_changes(tester), [_Delivery.express]);
    expect(_shadows(_Delivery.express), findsNWidgets(2));
    expect(tester.getSize(_shadows(_Delivery.express).last), const Size.square(10));
  });

  testWidgets('devrait choisir quand on touche la marge de la cible hors du cercle', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final circle = tester.getRect(_dot(_Delivery.standard));
    await tester.tapAt(circle.centerLeft - const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(_changes(tester), [_Delivery.standard]);
  });

  testWidgets(
    "devrait entrer dans le groupe à Tab sur l'option choisie, montrer l'anneau, et suivre les flèches en sautant l'option désactivée",
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host(initial: _Delivery.express, disabled: {_Delivery.standard})));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_radio(_Delivery.express), focusRingPainted);
      expect(_radio(_Delivery.pickup), isNot(focusRingPainted));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_radio(_Delivery.pickup), focusRingPainted);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_changes(tester), [_Delivery.pickup, _Delivery.express, _Delivery.pickup]);
    },
  );

  testWidgets("devrait choisir l'option focalisée avec Espace quand aucune n'est choisie", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_changes(tester), [_Delivery.standard]);
  });

  testWidgets("devrait faire entrer la pastille de l'échelle 1,5 à 1 en 300 ms quand le mouvement n'est pas réduit", (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(_radio(_Delivery.express));
    await tester.pump();
    expect(_thumbScale(tester, _Delivery.express), 1.5);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_thumbScale(tester, _Delivery.express), inExclusiveRange(1, 1.5));
    await tester.pump(const Duration(milliseconds: 160));
    expect(_thumbScale(tester, _Delivery.express), 1);
  });

  testWidgets('devrait poser la pastille à sa taille, sans échelle, quand Reduce Motion iOS est actif', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    await tester.tap(_radio(_Delivery.express));
    await tester.pump();
    expect(_thumbScale(tester, _Delivery.express), 1);
  });

  testWidgets('devrait garder le rond de 24 de HeroUI, et la cible de la plateforme, dans chaque densité', (
    tester,
  ) async {
    for (final tokens in [FlTokens.defaults, tortureB]) {
      for (final (platform, guideline, target) in [
        (TargetPlatform.android, androidTapTargetGuideline, tokens.size.hitTargetAndroid),
        (TargetPlatform.iOS, iOSTapTargetGuideline, tokens.size.hitTargetIos),
      ]) {
        for (final density in FlDensity.values) {
          final reason = '${platform.name} ${density.name}';
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            toggleApp(
              RadioGroup<_Delivery>(
                groupValue: _Delivery.standard,
                onChanged: (_) {},
                child: const FlRadio(value: _Delivery.standard, label: 'standard'),
              ),
              platform: platform,
              density: density,
              tokens: tokens,
            ),
          );
          expect(tester.getSize(_dot(_Delivery.standard)), const Size.square(24), reason: reason);
          final rect = tester.getSemantics(_radio(_Delivery.standard)).rect;
          expect(rect.width, greaterThanOrEqualTo(target), reason: reason);
          expect(rect.height, greaterThanOrEqualTo(target), reason: reason);
          await expectLater(tester, meetsGuideline(guideline), reason: reason);
          semantics.dispose();
        }
      }
    }
  });

  testWidgets(
    'devrait peindre field, control en secondary, selected choisie, et danger choisie ou son fond quand elle est invalide',
    (tester) async {
      final colors = FlTokens.defaults.light;
      for (final (variant, selected, invalid, fill) in [
        (FlRadioVariant.primary, false, false, colors.field),
        (FlRadioVariant.secondary, false, false, colors.control),
        (FlRadioVariant.primary, true, false, colors.selected),
        (FlRadioVariant.primary, false, true, colors.field),
        (FlRadioVariant.primary, true, true, colors.danger),
      ]) {
        await tester.pumpWidget(
          toggleApp(
            RadioGroup<_Delivery>(
              groupValue: selected ? _Delivery.standard : null,
              onChanged: (_) {},
              child: FlRadio(value: _Delivery.standard, label: 'standard', variant: variant, invalid: invalid),
            ),
          ),
        );
        expect(_fill(tester, _radio(_Delivery.standard)), fill, reason: '${variant.name} $selected $invalid');
      }
    },
  );

  // Le radio invalide non choisi de HeroUI n'avait ni fond ni anneau (ADR 0014
  // §11) ; l'habillage Izydesk, sans exception de contraste, le cerne de
  // `danger` sur son fond habituel, comme la case (ADR 0019 §6).
  testWidgets('devrait se cerner de danger, sur son fond, quand elle est invalide et non choisie', (tester) async {
    for (final variant in FlRadioVariant.values) {
      await tester.pumpWidget(
        toggleApp(
          RadioGroup<_Delivery>(
            groupValue: null,
            onChanged: (_) {},
            child: FlRadio(value: _Delivery.standard, label: 'standard', variant: variant, invalid: true),
          ),
        ),
      );
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: _radio(_Delivery.standard), matching: find.byType(DecoratedBox)),
      );
      expect(boxes, hasLength(1), reason: variant.name);
      final decoration = boxes.single.decoration as ShapeDecoration;
      expect(
        decoration.color,
        variant == FlRadioVariant.primary ? FlTokens.defaults.light.field : FlTokens.defaults.light.control,
        reason: variant.name,
      );
      expect(
        decoration.shape,
        CircleBorder(
          side: BorderSide(width: FlTokens.defaults.size.border, color: FlTokens.defaults.light.danger),
        ),
        reason: variant.name,
      );
      expect(_shadows(_Delivery.standard), findsOneWidget, reason: variant.name);
    }
  });

  testWidgets(
    'devrait cerner le rond vide d’un filet border sous l’ombre field, et peindre la pastille onSelected sans contour une fois choisie',
    (tester) async {
      final tokens = FlTokens.defaults;
      for (final selected in [false, true]) {
        await tester.pumpWidget(
          toggleApp(
            RadioGroup<_Delivery>(
              groupValue: selected ? _Delivery.standard : null,
              onChanged: (_) {},
              child: const FlRadio(value: _Delivery.standard, label: 'standard'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final decorations = [
          for (final box in tester.widgetList<DecoratedBox>(
            find.descendant(of: _radio(_Delivery.standard), matching: find.byType(DecoratedBox)),
          ))
            box.decoration as ShapeDecoration,
        ];
        expect(
          decorations.first.shape,
          selected
              ? const CircleBorder()
              : CircleBorder(
                  side: BorderSide(width: tokens.size.border, color: tokens.light.border),
                ),
        );
        if (selected) expect(decorations.last.color, tokens.light.onSelected);
      }
    },
  );

  testWidgets('devrait passer à disabledOpacity quand elle est désactivée seule', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(disabled: {_Delivery.pickup})));
    expect(_indicatorOpacity(tester, _radio(_Delivery.pickup)), FlTokens.defaults.size.disabledOpacity);
    expect(_indicatorOpacity(tester, _radio(_Delivery.standard)), 1);
  });

  testWidgets("devrait garder l'option choisie, sans onChanged, quand on la touche de nouveau", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(initial: _Delivery.express)));
    await tester.tap(_radio(_Delivery.express));
    await tester.pumpAndSettle();
    expect(_changes(tester), isEmpty);
  });

  group('FlRadioGroup', () {
    Widget group({
      bool disabled = false,
      bool invalid = false,
      bool? pickupDisabled,
      ValueChanged<_Delivery?>? onChanged,
    }) => SizedBox(
      width: 240,
      child: FlRadioGroup<_Delivery>(
        groupValue: _Delivery.express,
        onChanged: onChanged ?? (_) {},
        disabled: disabled,
        invalid: invalid,
        children: [
          const FlRadioGroupItem(value: _Delivery.standard, label: 'Standard'),
          const FlRadioGroupItem(value: _Delivery.express, label: 'Express'),
          FlRadioGroupItem(value: _Delivery.pickup, label: 'Pickup', disabled: pickupDisabled),
        ],
      ),
    );

    Finder item(_Delivery option) =>
        controlOf(find.byWidgetPredicate((widget) => widget is FlRadioGroupItem && widget.value == option));

    testWidgets('devrait empiler des lignes de 44 à 4 d’écart, le radio avant chaque libellé', (tester) async {
      await tester.pumpWidget(toggleApp(group(), platform: TargetPlatform.iOS));
      final rows = [for (final option in _Delivery.values) tester.getRect(item(option))];
      expect([for (final row in rows) row.height], [44, 44, 44]);
      expect(rows[1].top - rows[0].bottom, 4);
      final radio = tester.getRect(
        find.descendant(of: item(_Delivery.standard), matching: find.byType(FlShadow)).first,
      );
      expect(radio.left, rows[0].left);
      expect(tester.getRect(find.text('Standard')).left, radio.right + 12);
    });

    testWidgets('devrait choisir une option quand on touche son libellé, et la lire sous son libellé', (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <_Delivery?>[];
      await tester.pumpWidget(toggleApp(group(onChanged: changes.add), platform: TargetPlatform.iOS));
      await tester.tap(find.text('Pickup'));
      expect(changes, [_Delivery.pickup]);
      final node = tester.getSemantics(item(_Delivery.pickup));
      expect(node.label, 'Pickup');
      expect(node.rect.height, greaterThanOrEqualTo(44));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('devrait pâlir les libellés et les radios, et ne rien choisir, quand le groupe est désactivé', (
      tester,
    ) async {
      final changes = <_Delivery?>[];
      await tester.pumpWidget(toggleApp(group(disabled: true, onChanged: changes.add)));
      await tester.tap(find.text('Pickup'), warnIfMissed: false);
      expect(changes, isEmpty);
      final label = find.ancestor(of: find.text('Pickup'), matching: find.byType(Opacity)).first;
      expect(tester.widget<Opacity>(label).opacity, FlTokens.defaults.size.disabledOpacity);
      expect(_indicatorOpacity(tester, item(_Delivery.pickup)), FlTokens.defaults.size.disabledOpacity);
    });

    testWidgets('devrait laisser une option dire son propre état, désactivée ou non, avant celui du groupe', (
      tester,
    ) async {
      final changes = <_Delivery?>[];
      await tester.pumpWidget(toggleApp(group(disabled: true, pickupDisabled: false, onChanged: changes.add)));
      await tester.tap(find.text('Pickup'));
      expect(changes, [_Delivery.pickup]);
      await tester.pumpWidget(toggleApp(group(pickupDisabled: true, onChanged: changes.add)));
      await tester.tap(find.text('Pickup'), warnIfMissed: false);
      expect(changes, [_Delivery.pickup]);
    });

    testWidgets(
      'devrait garder la droite pour l’option suivante et la gauche pour la précédente quand le sens est RTL, comme le RadioGroup de Flutter',
      (tester) async {
        final changes = <_Delivery?>[];
        await tester.pumpWidget(toggleApp(group(onChanged: changes.add), direction: TextDirection.rtl));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(item(_Delivery.express), focusRingPainted);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(changes, [_Delivery.pickup, _Delivery.express, _Delivery.standard]);
      },
    );

    testWidgets('devrait passer les radios à danger, et garder les libellés onSurface, quand le groupe est invalide', (
      tester,
    ) async {
      await tester.pumpWidget(toggleApp(group(invalid: true)));
      final colors = FlTokens.defaults.light;
      expect(
        tester
            .widget<RichText>(find.descendant(of: item(_Delivery.standard), matching: find.byType(RichText)))
            .text
            .style
            ?.color,
        colors.onSurface,
      );
      expect(_fill(tester, item(_Delivery.express)), colors.danger);
      expect(_fill(tester, item(_Delivery.standard)), colors.field);
    });
  });

  testWidgets('devrait lire la description en indice et la poser sous le libellé, en textSm onSurfaceMuted', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 300,
          child: FlRadioGroup<_Delivery>(
            groupValue: _Delivery.standard,
            onChanged: (_) {},
            children: const [
              FlRadioGroupItem(value: _Delivery.standard, label: 'Standard', description: '4 à 10 jours ouvrés'),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.text('4 à 10 jours ouvrés')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('Standard')).bottom),
    );
    final style = tester.widget<Text>(find.text('4 à 10 jours ouvrés')).style!;
    expect(style.color, FlTokens.defaults.light.onSurfaceMuted);
    expect(style.fontSize, FlTokens.defaults.typography.ios.textSm.size);
    expect(tester.getSemantics(find.bySemanticsLabel('Standard')).hint, '4 à 10 jours ouvrés');
    semantics.dispose();
  });

  testWidgets('devrait poser les options côte à côte, à leur largeur, quand direction est horizontale', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 300,
          child: FlRadioGroup<_Delivery>(
            groupValue: _Delivery.standard,
            onChanged: (_) {},
            direction: Axis.horizontal,
            children: const [
              FlRadioGroupItem(value: _Delivery.standard, label: 'S'),
              FlRadioGroupItem(value: _Delivery.express, label: 'M'),
            ],
          ),
        ),
      ),
    );
    final first = tester.getRect(find.byType(FlRadioGroupItem<_Delivery>).first);
    final second = tester.getRect(find.byType(FlRadioGroupItem<_Delivery>).last);
    expect(second.top, first.top);
    expect(second.left - first.right, FlTokens.defaults.space.lg);
    expect(first.width, lessThan(150));
    await tester.tap(find.text('M'));
  });
}
