import 'package:fliin_ui/components/number_field/fl_number_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: platform,
      child: OverlayHost(
        child: FocusScope(
          autofocus: true,
          child: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    ),
  ),
);

/// Un nombre à une décimale, point décimal, pour les pas décimaux.
final class _Tenths implements FlNumberFormat {
  const _Tenths();

  @override
  bool get decimal => true;

  @override
  String format(double value) => value.toStringAsFixed(1);

  @override
  double? parse(String text) => double.tryParse(text);
}

/// Un format décimal qui n'affiche que l'entier le plus proche.
final class _Rounded implements FlNumberFormat {
  const _Rounded();

  @override
  bool get decimal => true;

  @override
  String format(double value) => '${value.round()}';

  @override
  double? parse(String text) => double.tryParse(text);
}

class _Host extends StatefulWidget {
  const _Host({
    this.initial = 2,
    this.min = 1,
    this.max = 10,
    this.step = 1,
    this.format,
    this.enabled = true,
    this.error,
  });

  final double initial;
  final double? min;
  final double? max;
  final double step;
  final FlNumberFormat? format;
  final bool enabled;
  final String? error;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  final List<double> changes = [];

  /// La valeur posée par le parent, hors de toute saisie.
  void put(double next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => FlNumberField(
    label: 'Quantité',
    value: value,
    min: widget.min,
    max: widget.max,
    step: widget.step,
    format: widget.format,
    enabled: widget.enabled,
    error: widget.error,
    decrementLabel: 'Diminuer',
    incrementLabel: 'Augmenter',
    onChanged: (next) => setState(() {
      changes.add(next);
      value = next;
    }),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Finder _button(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

Finder get _value => find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.slider == true);

String _shown(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.tap(find.byType(EditableText));
  await tester.pump();
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump();
}

/// Fait sortir le focus du champ.
Future<void> _leave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus!.unfocus();
  await tester.pump();
}

void main() {
  testWidgets('devrait lire semanticLabel sur le seul nœud de valeur, le mot affiché gardé', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FlNumberField(
          label: 'Quantité',
          semanticLabel: 'Quantité, Sac cabas en lin',
          value: 2,
          onChanged: (_) {},
          decrementLabel: 'Diminuer',
          incrementLabel: 'Augmenter',
        ),
      ),
    );
    final values = find.semantics.byPredicate((node) => node.flagsCollection.isSlider);
    expect(values.evaluate().map((node) => node.label), ['Quantité, Sac cabas en lin']);
    expect(find.text('Quantité'), findsOneWidget, reason: 'le mot affiché ne change pas');
    semantics.dispose();
  });

  testWidgets('devrait se lire comme une valeur ajustable nommée, avec ses deux boutons nommés', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Host()));
    expect(
      tester.getSemantics(_value),
      matchesSemantics(
        label: 'Quantité',
        value: '2',
        increasedValue: '3',
        decreasedValue: '1',
        isSlider: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        children: [
          for (final label in ['Diminuer', 'Augmenter'])
            matchesSemantics(label: label, isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
        ],
      ),
    );
    final value = tester.widget<Semantics>(_value).properties;
    value.onIncrease!();
    await tester.pump();
    expect(_host(tester).value, 3);
    tester.widget<Semantics>(_value).properties.onDecrease!();
    await tester.pump();
    expect(_host(tester).value, 2);
    semantics.dispose();
  });

  testWidgets('devrait ajouter et retirer un pas aux boutons, et désactiver le bouton à la borne', (tester) async {
    await tester.pumpWidget(_app(const _Host(initial: 9)));
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).value, 10);
    expect(_shown(tester), '10');
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).changes, [10]);
    expect(tester.widget<Semantics>(_button('Augmenter')).properties.enabled, isFalse);
    await tester.tap(_button('Diminuer'));
    await tester.pump();
    expect(_host(tester).value, 9);
  });

  testWidgets("devrait répéter le pas tant que l'appui dure, après 400 ms puis toutes les 60 ms, jusqu'à la borne", (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Host()));
    final hold = await tester.startGesture(tester.getCenter(_button('Augmenter')));
    await tester.pump();
    expect(_host(tester).value, 3, reason: 'un pas dès l’appui');
    await tester.pump(const Duration(milliseconds: 399));
    expect(_host(tester).value, 3);
    await tester.pump(const Duration(milliseconds: 61));
    expect(_host(tester).value, 4);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_host(tester).value, 6);
    await tester.pump(const Duration(seconds: 2));
    expect(_host(tester).value, 10);
    await hold.up();
    await tester.pump(const Duration(seconds: 1));
    expect(_host(tester).changes.last, 10);
    final once = await tester.startGesture(tester.getCenter(_button('Diminuer')));
    await tester.pump();
    await once.up();
    await tester.pump(const Duration(seconds: 1));
    expect(_host(tester).value, 9, reason: 'le relâché arrête la répétition');
  });

  testWidgets("devrait relâcher l'appui quand le bouton quitte l'arbre, son geste étant rejeté", (tester) async {
    final changes = <double>[];
    Widget field() => FlNumberField(
      label: 'Quantité',
      value: 2,
      max: 100,
      decrementLabel: 'Diminuer',
      incrementLabel: 'Augmenter',
      onChanged: changes.add,
    );
    await tester.pumpWidget(_app(field()));
    final hold = await tester.startGesture(tester.getCenter(_button('Augmenter')));
    await tester.pump(const Duration(milliseconds: 520));
    final before = changes.length;
    expect(before, greaterThan(1), reason: 'la répétition a commencé');
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pump(const Duration(seconds: 1));
    expect(changes, hasLength(before));
    await hold.up();
  });

  testWidgets('devrait continuer de répéter sous un ancêtre à appui long, sans le déclencher', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(_app(GestureDetector(onLongPress: () => longPressed = true, child: const _Host())));
    final hold = await tester.startGesture(tester.getCenter(_button('Augmenter')));
    await tester.pump(const Duration(seconds: 2));
    await hold.up();
    await tester.pump();
    expect(_host(tester).value, 10);
    expect(longPressed, isFalse);
  });

  testWidgets('devrait laisser défiler sans ajouter de pas quand le doigt part en glissant du bouton', (tester) async {
    await tester.pumpWidget(
      _app(SingleChildScrollView(child: Column(children: const [_Host(), SizedBox(height: 2000)]))),
    );
    final drag = await tester.startGesture(tester.getCenter(_button('Augmenter')));
    await drag.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(seconds: 1));
    await drag.up();
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
  });

  testWidgets(
    "devrait compter la quantité tapée sur iOS, sans touche Retour, puis sortir du champ au toucher d'un autre bouton",
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var ordered = false;
      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.iOS,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Host(initial: 1),
              GestureDetector(
                onTap: () => ordered = true,
                child: const SizedBox(height: 48, child: Text('Commander')),
              ),
            ],
          ),
        ),
      );
      await _type(tester, '3');
      expect(_host(tester).changes, [3], reason: 'le pavé numérique n’a pas de touche Retour');
      expect(_shown(tester), '3');
      await tester.tap(find.text('Commander'));
      await tester.pump();
      expect(ordered, isTrue);
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
      expect(_host(tester).value, 3);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('devrait garder le focus et la saisie quand on touche les boutons du champ', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_app(const _Host(), platform: TargetPlatform.iOS));
    await _type(tester, '5');
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).changes, [5, 6]);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('devrait attendre la sortie pour une saisie hors du pas, puis la poser sur le pas', (tester) async {
    await tester.pumpWidget(_app(const _Host(min: 0, max: 100, step: 5, initial: 10)));
    await _type(tester, '17');
    expect(_host(tester).changes, isEmpty);
    await _leave(tester);
    expect(_host(tester).value, 15);
  });

  testWidgets('devrait remplacer la saisie par une valeur nouvelle du parent, comme React Aria', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await _type(tester, '5');
    expect(_host(tester).value, 5);
    _host(tester).put(3);
    await tester.pump();
    expect(_shown(tester), '3');
  });

  testWidgets('devrait refuser NaN et l’infini rendus par un format', (tester) async {
    await tester.pumpWidget(_app(const _Host(format: _Tenths(), step: 0.5)));
    for (final text in ['NaN', 'Infinity']) {
      await _type(tester, text);
      await _leave(tester);
    }
    expect(_host(tester).changes, isEmpty);
    expect(_shown(tester), '2.0');
  });

  testWidgets('devrait ajouter quatre pas de 0,5 depuis la valeur, et non depuis le texte arrondi', (tester) async {
    await tester.pumpWidget(_app(const _Host(step: 0.5, format: _Rounded())));
    for (var i = 0; i < 4; i++) {
      await tester.tap(_button('Augmenter'));
      await tester.pump();
    }
    expect(_host(tester).changes, [2.5, 3, 3.5, 4]);
  });

  testWidgets('devrait refuser un pas décimal avec le format entier', (tester) async {
    await tester.pumpWidget(_app(const _Host(step: 0.5)));
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('devrait ramener une saisie hors bornes à la borne, à la sortie du champ', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await _type(tester, '42');
    expect(_host(tester).changes, isEmpty, reason: 'rien ne compte pendant la saisie');
    await _leave(tester);
    expect(_host(tester).value, 10);
    expect(_shown(tester), '10');
  });

  testWidgets("devrait rendre la valeur d'avant quand la saisie n'est pas un nombre", (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await _type(tester, 'deux');
    await _leave(tester);
    expect(_host(tester).changes, isEmpty);
    expect(_shown(tester), '2');
  });

  testWidgets("devrait compter la saisie à la touche d'action du clavier", (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await _type(tester, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_host(tester).value, 7);
  });

  testWidgets('devrait poser la saisie et les pas sur la grille du pas, comptée depuis la borne basse', (tester) async {
    await tester.pumpWidget(_app(const _Host(min: 0, max: 100, step: 5, initial: 10)));
    await _type(tester, '17');
    await _leave(tester);
    expect(_host(tester).value, 15);
    await _type(tester, '17');
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).value, 20, reason: 'hors de la grille, le pas va au voisin du haut');
  });

  testWidgets('devrait écrire 0,3 et non 0,30000000000000004 avec un pas de 0,1', (tester) async {
    await tester.pumpWidget(_app(const _Host(min: 0, max: 1, step: 0.1, initial: 0.2, format: _Tenths())));
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).value, 0.3);
  });

  testWidgets('devrait ajouter un pas aux flèches, et aller aux bornes à Début et Fin', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    for (final (key, expected) in [
      (LogicalKeyboardKey.arrowUp, 3.0),
      (LogicalKeyboardKey.arrowDown, 2.0),
      (LogicalKeyboardKey.end, 10.0),
      (LogicalKeyboardKey.home, 1.0),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(_host(tester).value, expected, reason: '$key');
      expect(_shown(tester), expected.round().toString());
    }
  });

  testWidgets('devrait écrire et relire les chiffres arabes orientaux', (tester) async {
    await tester.pumpWidget(_app(const _Host(format: FlIntegerFormat(digits: FlDigits.arabicIndic))));
    expect(_shown(tester), '٢');
    await _type(tester, '٧');
    await _leave(tester);
    expect(_host(tester).value, 7);
    expect(_shown(tester), '٧');
  });

  test('devrait choisir les chiffres de la langue, arabes orientaux ou étendus, et ne relire que des entiers', () {
    expect(flDigitsOf(const Locale('ar')), FlDigits.arabicIndic);
    expect(flDigitsOf(const Locale('ar', 'EG')), FlDigits.arabicIndic);
    expect(flDigitsOf(const Locale('ar', 'MA')), FlDigits.latin);
    expect(flDigitsOf(const Locale('fr')), FlDigits.latin);
    expect(flDigitsOf(null), FlDigits.latin);
    expect(flDigitsOf(const Locale('fa')), FlDigits.extendedArabicIndic);
    expect(flDigitsOf(const Locale('ur', 'IN')), FlDigits.extendedArabicIndic);
    expect(flDigitsOf(const Locale('ur')), FlDigits.latin);
    expect(const FlIntegerFormat(digits: FlDigits.extendedArabicIndic).format(12), '۱۲');
    expect(const FlIntegerFormat().parse('۱۲'), 12, reason: 'chiffres persans');
    expect(const FlIntegerFormat().parse('0x10'), isNull);
    expect(const FlIntegerFormat().parse('1e3'), isNull);
    expect(const FlIntegerFormat().parse('−3'), -3, reason: 'signe moins');
  });

  test('devrait écrire et relire un prix, une unité et un pourcentage quand le format est décimal', () {
    const usd = FlDecimalFormat(prefix: r'$', groupSeparator: ',');
    expect(usd.format(1234.5), r'$1,234.50');
    expect(usd.format(-3), r'-$3.00');
    expect(usd.format(-0.001), r'$0.00', reason: 'pas de « -0.00 »');
    expect(usd.parse(r'$1,234.50'), 1234.5);
    expect(usd.parse('1234.5'), 1234.5, reason: 'sans préfixe ni séparateur');
    expect(usd.parse(r'-$3'), -3);
    expect(usd.parse('12abc'), isNull);
    expect(usd.parse('1e3'), isNull);
    expect(usd.decimal, isTrue);

    const eur = FlDecimalFormat(suffix: ' €', decimalSeparator: ',', groupSeparator: ' ');
    expect(eur.format(1234.5), '1 234,50 €');
    expect(eur.parse('1 234,50 €'), 1234.5);
    expect(eur.parse('99,9'), 99.9);

    const kg = FlDecimalFormat(fractionDigits: 0, suffix: ' kg');
    expect(kg.format(1000), '1000 kg');
    expect(kg.parse('1000kg'), 1000);
    expect(kg.decimal, isFalse);

    const percent = FlDecimalFormat.percent();
    expect(percent.format(0.5), '50%');
    expect(percent.parse('57 %'), 0.57);
    expect(percent.decimal, isTrue, reason: 'un pas de 0,01 exige un format décimal');

    const arabic = FlDecimalFormat(decimalSeparator: '٫', digits: FlDigits.arabicIndic);
    expect(arabic.format(2.5), '٢٫٥٠');
    expect(arabic.parse('٢٫٥٠'), 2.5);
    expect(const FlDecimalFormat(), const FlDecimalFormat(), reason: 'un format recréé ne réécrit pas le champ');
  });

  testWidgets('devrait faire avancer un prix d’un pas décimal quand le format est décimal', (tester) async {
    await tester.pumpWidget(_app(const _Host(format: FlDecimalFormat(prefix: r'$'), step: 0.5)));
    await tester.tap(_button('Augmenter'));
    await tester.pump();
    expect(_host(tester).value, 2.5);
    expect(_shown(tester), r'$2.50');
  });

  testWidgets('devrait poser le bouton moins au début de la ligne, à droite en RTL', (tester) async {
    await tester.pumpWidget(_app(const _Host(), direction: TextDirection.rtl));
    expect(tester.getCenter(_button('Diminuer')).dx, greaterThan(tester.getCenter(_button('Augmenter')).dx));
  });

  testWidgets('devrait offrir la cible tactile de la plateforme à chaque bouton', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Host(), platform: TargetPlatform.iOS));
    final rect = tester.getSemantics(_button('Augmenter')).rect;
    expect(rect.width, greaterThanOrEqualTo(FlTokens.defaults.size.hitTargetIos));
    expect(rect.height, greaterThanOrEqualTo(FlTokens.defaults.size.hitTargetIos));
    semantics.dispose();
  });

  testWidgets('devrait ignorer toucher et clavier quand le champ est désactivé', (tester) async {
    await tester.pumpWidget(_app(const _Host(enabled: false)));
    await tester.tap(_button('Augmenter'), warnIfMissed: false);
    await tester.tap(find.byType(EditableText), warnIfMissed: false);
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
  });

  testWidgets("devrait dire l'erreur en indice de la valeur, et l'afficher sous le champ", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Host(error: 'Stock épuisé au-delà de 3')));
    expect(find.text('Stock épuisé au-delà de 3'), findsOneWidget);
    expect(tester.getSemantics(_value).hint, 'Stock épuisé au-delà de 3');
    semantics.dispose();
  });
}
