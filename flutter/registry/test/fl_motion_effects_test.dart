import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduced = false, TextDirection direction = TextDirection.ltr}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: direction,
    child: FlScope(
      platform: TargetPlatform.iOS,
      child: Center(child: child),
    ),
  ),
);

const _box = SizedBox(width: 20, height: 20);

double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(FlPop), matching: find.byType(Transform)).first,
  );
  return transform.transform.entry(0, 0);
}

double _opacityOf(WidgetTester tester, Finder of) =>
    // FlPop's fade, which adds no layer when opaque, exposes its alpha.
    ((tester.widget(
          find.descendant(of: of, matching: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Fade')).first,
        ) as dynamic).alpha
        as int) /
    255;

double _shakeOf(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(FlShake), matching: find.byType(Transform)).first)
    .transform
    .getTranslation()
    .x;

Set<String> _texts(WidgetTester tester) => {
  for (final text in tester.widgetList<Text>(
    find.descendant(of: find.byType(FlRollingText), matching: find.byType(Text)),
  ))
    text.data!,
};

void main() {
  group('FlPop', () {
    testWidgets('devrait peindre l’enfant sans calque d’opacité au repos, ni avant ni après son apparition', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const FlPop(child: _box)));
      expect(tester.layers.whereType<OpacityLayer>(), isEmpty);
      await tester.pumpWidget(_app(const FlPop(shown: false, child: _box)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(const FlPop(child: _box)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.layers.whereType<OpacityLayer>(), isNotEmpty);
      await tester.pumpAndSettle();
      expect(tester.layers.whereType<OpacityLayer>(), isEmpty);
    });

    testWidgets('devrait grandir puis dépasser sa taille avant de s’y poser quand il apparaît', (tester) async {
      await tester.pumpWidget(_app(const FlPop(shown: false, child: _box)));
      expect(find.byType(SizedBox).evaluate().any((e) => (e.widget as SizedBox).width == 20), isFalse);
      await tester.pumpWidget(_app(const FlPop(child: _box)));
      await tester.pump(const Duration(milliseconds: 40));
      final early = _scaleOf(tester);
      expect(early, inExclusiveRange(0, 1));
      var peak = early;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (_scaleOf(tester) > peak) peak = _scaleOf(tester);
      }
      expect(peak, greaterThan(1.05), reason: 'the pop spring overshoots');
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), 1);
      expect(_opacityOf(tester, find.byType(FlPop)), 1);
    });

    testWidgets('devrait attendre son délai, caché, avant d’apparaître quand appear est vrai', (tester) async {
      await tester.pumpWidget(_app(const FlPop(appear: true, delay: Duration(milliseconds: 200), child: _box)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacityOf(tester, find.byType(FlPop)), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacityOf(tester, find.byType(FlPop)), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_scaleOf(tester), 1);
    });

    testWidgets('devrait seulement se fondre, sans changer d’échelle, quand le mouvement est réduit', (tester) async {
      await tester.pumpWidget(_app(const FlPop(shown: false, child: _box), reduced: true));
      await tester.pumpWidget(_app(const FlPop(child: _box), reduced: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_scaleOf(tester), 1);
      expect(_opacityOf(tester, find.byType(FlPop)), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.byType(FlPop)), 1);
    });

    testWidgets('devrait rétrécir et ne plus rien occuper quand il se cache', (tester) async {
      await tester.pumpWidget(_app(const FlPop(child: _box)));
      await tester.pumpWidget(_app(const FlPop(shown: false, child: _box)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_scaleOf(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byWidget(_box), findsNothing);
    });
  });

  group('FlShake', () {
    testWidgets('devrait partir vers le début de la ligne, osciller, puis revenir à sa place quand il s’active', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const FlShake(active: false, child: _box)));
      await tester.pumpWidget(_app(const FlShake(active: true, child: _box)));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_shakeOf(tester), lessThan(-2));
      final amplitude = FlTokens.defaults.space.xs * 1.5;
      var right = 0.0;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shakeOf(tester).abs(), lessThanOrEqualTo(amplitude + 0.01));
        if (_shakeOf(tester) > right) right = _shakeOf(tester);
      }
      expect(right, greaterThan(1), reason: 'it swings back past its place');
      await tester.pumpAndSettle();
      expect(_shakeOf(tester), 0);
    });

    testWidgets('devrait partir vers la droite quand la page s’écrit de droite à gauche', (tester) async {
      await tester.pumpWidget(_app(const FlShake(active: false, child: _box), direction: TextDirection.rtl));
      await tester.pumpWidget(_app(const FlShake(active: true, child: _box), direction: TextDirection.rtl));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_shakeOf(tester), greaterThan(2));
    });

    testWidgets('devrait rester immobile quand le mouvement est réduit', (tester) async {
      await tester.pumpWidget(_app(const FlShake(active: false, child: _box), reduced: true));
      await tester.pumpWidget(_app(const FlShake(active: true, child: _box), reduced: true));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shakeOf(tester), 0);
      }
    });
  });

  group('FlRollingText', () {
    const style = TextStyle(fontSize: 20);

    testWidgets('devrait montrer l’ancien et le nouveau chiffre à mi-course, puis le seul texte au repos', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const FlRollingText('12', style: style)));
      expect(_texts(tester), {'12'});
      await tester.pumpWidget(_app(const FlRollingText('13', style: style)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_texts(tester), containsAll(['1', '2', '3']));
      expect(tester.getSemantics(find.byType(FlRollingText)).label, '13');
      await tester.pumpAndSettle();
      expect(_texts(tester), {'13'});
    });

    testWidgets('devrait faire monter le chiffre qui croît et descendre celui qui décroît', (tester) async {
      double topOf(String digit) => tester.getTopLeft(find.text(digit)).dy;
      await tester.pumpWidget(_app(const FlRollingText('4', style: style)));
      final line = tester.getTopLeft(find.text('4')).dy;
      await tester.pumpWidget(_app(const FlRollingText('5', style: style)));
      await tester.pump(const Duration(milliseconds: 40));
      expect(topOf('4'), lessThan(line), reason: 'the old face leaves upwards');
      expect(topOf('5'), greaterThan(line), reason: 'the new face comes from below');
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(const FlRollingText('4', style: style)));
      await tester.pump(const Duration(milliseconds: 40));
      expect(topOf('5'), greaterThan(line), reason: 'shrinking, the old face leaves downwards');
      expect(topOf('4'), lessThan(line));
    });

    testWidgets('devrait passer par les chiffres intermédiaires quand la valeur saute', (tester) async {
      await tester.pumpWidget(_app(const FlRollingText('2', style: style)));
      await tester.pumpWidget(_app(const FlRollingText('8', style: style)));
      final seen = <String>{};
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        seen.addAll(_texts(tester));
      }
      expect(seen, containsAll(['4', '5', '6']));
    });

    testWidgets('devrait changer d’un coup quand le mouvement est réduit', (tester) async {
      await tester.pumpWidget(_app(const FlRollingText('12', style: style), reduced: true));
      await tester.pumpWidget(_app(const FlRollingText('13', style: style), reduced: true));
      expect(_texts(tester), {'13'});
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('devrait changer d’un coup un texte sans chiffre ou écrit de droite à gauche', (tester) async {
      await tester.pumpWidget(_app(const FlRollingText('12', style: style)));
      await tester.pumpWidget(_app(const FlRollingText('١٣', style: style)));
      expect(_texts(tester), {'١٣'});
      await tester.pumpWidget(_app(const FlRollingText('—', style: style)));
      expect(_texts(tester), {'—'});
    });
  });
}
