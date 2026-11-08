import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';
import 'torture/torture.g.dart';

/// Un interrupteur que le parent tient à jour, comme dans une vraie app.
class _Host extends StatefulWidget {
  const _Host({super.key, this.accept = true});

  final bool accept;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool value = false;
  final changes = <bool>[];

  @override
  Widget build(BuildContext context) => FlSwitch(
    value: value,
    label: 'Wi-Fi',
    onChanged: (next) {
      changes.add(next);
      if (widget.accept) setState(() => value = next);
    },
  );
}

/// La piste : la boîte découpée à sa forme, la première quand un fondu en
/// superpose deux.
Finder get _track => find.descendant(of: find.byType(FlSwitch), matching: find.byType(ClipPath)).first;

/// Les pouces peints, chacun sous son ombre.
Finder get _thumbs => find.descendant(of: find.byType(FlSwitch), matching: find.byType(FlShadow));

Rect _thumb(WidgetTester tester) => tester.getRect(_thumbs.last);

/// Les couleurs de la piste puis du pouce.
(Color, Color) _colors(WidgetTester tester) {
  final boxes = tester
      .widgetList<DecoratedBox>(find.descendant(of: find.byType(FlSwitch), matching: find.byType(DecoratedBox)))
      .map((box) => (box.decoration as ShapeDecoration).color!)
      .toList();
  return (boxes.first, boxes.last);
}

double _scale(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(FlSwitch), matching: find.byType(Transform)).first)
    .transform
    .storage[0];

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.descendant(of: find.byType(FlSwitch), matching: find.byType(Opacity)).first).opacity;

void main() {
  testWidgets("devrait s'annoncer comme un interrupteur activé, basculé et étiqueté quand il est allumé", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(FlSwitch(value: true, label: 'Wi-Fi', onChanged: (_) {})));
    expect(
      tester.getSemantics(controlOf(find.byType(FlSwitch))),
      matchesSemantics(
        label: 'Wi-Fi',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer désactivé, sans action, et ignorer le toucher quand onChanged est nul", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const FlSwitch(value: false, label: 'Wi-Fi', onChanged: null)));
    await tester.tap(find.byType(FlSwitch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(controlOf(find.byType(FlSwitch))),
      matchesSemantics(label: 'Wi-Fi', hasToggledState: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer désactivé quand un FlFieldScope désactivé l'entoure, onChanged donné", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <bool>[];
    await tester.pumpWidget(
      toggleApp(
        FlFieldScope(
          disabled: true,
          child: FlSwitch(value: false, label: 'Wi-Fi', onChanged: changes.add),
        ),
      ),
    );
    await tester.tap(find.byType(FlSwitch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(
      tester.getSemantics(controlOf(find.byType(FlSwitch))),
      matchesSemantics(label: 'Wi-Fi', hasToggledState: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets("devrait basculer et glisser le pouce jusqu'au bout quand on le touche", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final track = tester.getRect(_track);
    expect(_thumb(tester).left - track.left, 2);
    await tester.tap(find.byType(FlSwitch));
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true]);
    expect(track.right - _thumb(tester).right, closeTo(2, 0.01));
  });

  testWidgets('devrait basculer quand on touche la marge de la cible hors de la piste', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final track = tester.getRect(_track);
    await tester.tapAt(track.topCenter - const Offset(0, 8));
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true]);
  });

  testWidgets("devrait prendre le focus à Tab, montrer l'anneau et basculer avec Espace puis Entrée", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(find.byType(FlSwitch), isNot(focusRingPainted));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(FlSwitch), focusRingPainted);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true, false]);
  });

  testWidgets("devrait s'allumer quand on glisse le pouce au-delà du milieu vers la fin", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final track = tester.getRect(_track);
    await tester.drag(find.byType(FlSwitch), Offset(track.width * 0.6, 0));
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true]);
    expect(track.right - _thumb(tester).right, closeTo(2, 0.1));
  });

  testWidgets("devrait revenir à l'arrêt sans appeler onChanged quand on lâche le pouce avant le milieu", (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final track = tester.getRect(_track);
    final gesture = await tester.startGesture(_thumb(tester).center);
    await gesture.moveBy(Offset(kDragSlopDefault + 1, 0));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();
    expect(_thumb(tester).left - track.left, greaterThan(2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, isEmpty);
    expect(_thumb(tester).left - track.left, closeTo(2, 0.1));
  });

  testWidgets("devrait ramener le pouce à value quand le parent refuse le changement d'un glisser", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(accept: false)));
    final track = tester.getRect(_track);
    await tester.drag(find.byType(FlSwitch), Offset(track.width, 0));
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true]);
    expect(_thumb(tester).left - track.left, closeTo(2, 0.1));
  });

  testWidgets('devrait placer le pouce allumé à gauche et s’allumer en glissant vers la gauche quand le sens est RTL', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    final track = tester.getRect(_track);
    expect(track.right - _thumb(tester).right, closeTo(2, 0.1));
    await tester.drag(find.byType(FlSwitch), Offset(-track.width, 0));
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, [true]);
    expect(_thumb(tester).left - track.left, closeTo(2, 0.1));
  });

  testWidgets("devrait animer le pouce par le ressort quand le mouvement n'est pas réduit", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.byType(FlSwitch));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets(
    'devrait passer la piste de switchTrack à selected, sans contour, sous un pouce switchThumb, en clair et en '
    'sombre (canvas)',
    (tester) async {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.light ? FlTokens.defaults.light : FlTokens.defaults.dark;
        for (final (value, track) in [(false, colors.switchTrack), (true, colors.selected)]) {
          await tester.pumpWidget(
            WidgetsApp(
              color: colors.surface,
              builder: (context, _) => FlScope(
                brightness: brightness,
                platform: TargetPlatform.iOS,
                child: Center(
                  child: FlSwitch(value: value, label: 'Wi-Fi', onChanged: (_) {}),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(_colors(tester), (track, colors.switchThumb), reason: '${brightness.name} $value');
          final shape =
              (tester
                              .widget<DecoratedBox>(
                                find.descendant(of: find.byType(FlSwitch), matching: find.byType(DecoratedBox)).first,
                              )
                              .decoration
                          as ShapeDecoration)
                      .shape
                  as FlContinuousBorder;
          expect(shape.side, BorderSide.none, reason: '${brightness.name} $value');
        }
      }
    },
  );

  /// Le mouvement réduit ne déplace rien : pendant 150 ms, le pouce d'avant
  /// reste et le nouveau apparaît en fondu à sa place, sans position
  /// intermédiaire.
  Future<void> expectFadeWithoutTranslation(WidgetTester tester) async {
    final track = tester.getRect(_track);
    await tester.tap(find.byType(FlSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(
      [for (final thumb in _thumbs.evaluate()) tester.getRect(find.byWidget(thumb.widget)).left - track.left],
      [2, 18],
    );
    final fade = tester.widgetList<Opacity>(find.descendant(of: find.byType(FlSwitch), matching: find.byType(Opacity)));
    expect(fade.last.opacity, closeTo(0.5, 0.05));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_thumbs, findsOneWidget);
    expect(track.right - _thumb(tester).right, 2);
  }

  testWidgets('devrait poser le pouce à sa place en fondu de 150 ms quand Reduce Motion iOS est actif', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    await expectFadeWithoutTranslation(tester);
  });

  testWidgets(
    'devrait poser le pouce en fondu de 150 ms, sans le réduire à 5 %, quand Android supprime les animations',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        MediaQuery(data: const MediaQueryData(disableAnimations: true), child: toggleApp(const _Host())),
      );
      await expectFadeWithoutTranslation(tester);
    },
  );

  testWidgets(
    'devrait garder la piste de 48 × 24 et le pouce de 28 × 20 de HeroUI, et la cible de la plateforme, dans chaque densité',
    (tester) async {
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
                FlSwitch(value: false, label: 'Wi-Fi', onChanged: (_) {}),
                platform: platform,
                density: density,
                tokens: tokens,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.getSize(_track), const Size(48, 24), reason: reason);
            expect(_thumb(tester).size, const Size(28, 20), reason: reason);
            final rect = tester.getSemantics(controlOf(find.byType(FlSwitch))).rect;
            expect(rect.width, greaterThanOrEqualTo(target), reason: reason);
            expect(rect.height, greaterThanOrEqualTo(target), reason: reason);
            await expectLater(tester, meetsGuideline(guideline), reason: reason);
            semantics.dispose();
          }
        }
      }
    },
  );

  testWidgets('devrait passer à disabledOpacity quand il est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const FlSwitch(value: true, label: 'Wi-Fi', onChanged: null)));
    expect(_opacity(tester), FlTokens.defaults.size.disabledOpacity);
    await tester.pumpWidget(toggleApp(FlSwitch(value: true, label: 'Wi-Fi', onChanged: (_) {})));
    expect(_opacity(tester), 1);
  });

  testWidgets('devrait rétrécir à 0,96 pendant que le doigt appuie, puis revenir à 1 au relâché', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(FlSwitch)));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(0.96, 0.001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
  });

  testWidgets('devrait étirer le pouce de space.xs vers le côté où il irait, pendant l’appui', (tester) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    final size = FlTokens.defaults.size;
    final xs = FlTokens.defaults.space.xs;
    for (final value in [false, true]) {
      await tester.pumpWidget(
        toggleApp(FlSwitch(value: value, label: 'Wi-Fi', onChanged: (_) {}, statesController: states)),
      );
      await tester.pumpAndSettle();
      final rest = _thumb(tester);
      states.update(WidgetState.pressed, true);
      await tester.pumpAndSettle();
      final pressed = _thumb(tester);
      expect(pressed.width, closeTo((rest.width + xs) * size.controlPressedScale, 0.01), reason: '$value');
      // Éteint, il s'étire vers la fin ; allumé, vers le début.
      if (value) {
        expect(pressed.center.dx, lessThan(rest.center.dx), reason: 'allumé');
      } else {
        expect(pressed.center.dx, greaterThan(rest.center.dx), reason: 'éteint');
      }
      states.update(WidgetState.pressed, false);
      await tester.pumpAndSettle();
      expect(_thumb(tester).width, closeTo(rest.width, 0.01));
    }
  });

  testWidgets('devrait rétrécir quand son statesController est pressé, comme sous un doigt', (tester) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      toggleApp(FlSwitch(value: false, label: 'Wi-Fi', onChanged: (_) {}, statesController: states)),
    );
    states.update(WidgetState.pressed, true);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(0.96, 0.001));
    states.update(WidgetState.pressed, false);
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
  });

  testWidgets('devrait rester à l’échelle 1 sous un doigt quand Reduce Motion iOS est actif', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(FlSwitch)));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('devrait ramener le pouce à value quand le parent désactive l’interrupteur pendant un glisser', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      toggleApp(
        ValueListenableBuilder(
          valueListenable: enabled,
          builder: (context, on, _) => FlSwitch(value: false, label: 'Wi-Fi', onChanged: on ? (_) {} : null),
        ),
      ),
    );
    final track = tester.getRect(_track);
    final gesture = await tester.startGesture(_thumb(tester).center);
    await gesture.moveBy(Offset(kDragSlopDefault + 1, 0));
    await gesture.moveBy(Offset(track.width * 0.2, 0));
    await tester.pump();
    expect(_thumb(tester).left - track.left, greaterThan(3));
    enabled.value = false;
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_thumb(tester).left - track.left, closeTo(2, 0.1));
  });

  testWidgets('devrait rester éteint, sans onChanged, quand on lâche le pouce à 40 % de la course', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final track = tester.getRect(_track);
    const travel = 48.0 - 28 - 2 * 2;
    final gesture = await tester.startGesture(_thumb(tester).center);
    await gesture.moveBy(Offset(kDragSlopDefault + 1, 0));
    await tester.pump();
    await gesture.moveBy(Offset(track.left + 2 + 0.4 * travel - _thumb(tester).left, 0));
    await tester.pump();
    expect((_thumb(tester).left - track.left - 2) / travel, closeTo(0.4, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.state<_HostState>(find.byType(_Host)).changes, isEmpty);
    expect(_thumb(tester).left - track.left, closeTo(2, 0.1));
  });

  testWidgets('devrait emporter la vitesse du doigt quand on lance le pouce au lieu de le poser', (tester) async {
    Future<double> firstFrameAfterRelease(Duration step) async {
      await tester.pumpWidget(toggleApp(_Host(key: UniqueKey())));
      final gesture = await tester.startGesture(_thumb(tester).center);
      var time = Duration.zero;
      for (var i = 0; i < 11; i++) {
        time += step;
        await gesture.moveBy(const Offset(2, 0), timeStamp: time);
      }
      await gesture.up(timeStamp: time + step);
      await tester.pump();
      final released = _thumb(tester).left;
      await tester.pump(const Duration(milliseconds: 16));
      return _thumb(tester).left - released;
    }

    final placed = await firstFrameAfterRelease(const Duration(milliseconds: 100));
    final flung = await firstFrameAfterRelease(const Duration(milliseconds: 2));
    expect(flung, greaterThan(placed + 1));
  });

  testWidgets('devrait garder sa place de 48 × 24, la cible hors de la mise en page, quand un FlFieldScope l’entoure', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        FlFieldScope(
          child: FlSwitch(value: false, label: 'Wi-Fi', onChanged: (_) {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlSwitch)), const Size(48, 24));
  });

  testWidgets('devrait mettre la piste et le pouce aux trois quarts en sm et aux cinq quarts en lg', (tester) async {
    for (final (size, track, thumb) in [
      (FlSwitchSize.sm, const Size(36, 18), const Size(21, 15)),
      (FlSwitchSize.md, const Size(48, 24), const Size(28, 20)),
      (FlSwitchSize.lg, const Size(60, 30), const Size(35, 25)),
    ]) {
      await tester.pumpWidget(toggleApp(FlSwitch(value: false, label: 'Wi-Fi', size: size, onChanged: (_) {})));
      expect(tester.getSize(find.byType(FlSwitch)), track, reason: size.name);
      expect(_thumb(tester).size, thumb, reason: size.name);
    }
  });

  testWidgets('devrait poser thumbIcon dans le pouce, selected allumé et onSurfaceMuted éteint', (tester) async {
    final colors = FlTokens.defaults.light;
    Widget icon(bool on) => Builder(
      builder: (context) {
        final theme = IconTheme.of(context);
        return SizedBox.square(
          key: Key(on ? 'on' : 'off'),
          dimension: theme.size,
          child: ColoredBox(color: theme.color!),
        );
      },
    );
    await tester.pumpWidget(toggleApp(FlSwitch(value: true, label: 'Son', thumbIcon: icon, onChanged: (_) {})));
    expect(tester.getSize(find.byKey(const Key('on'))), const Size.square(12));
    expect(
      tester
          .widget<ColoredBox>(find.descendant(of: find.byKey(const Key('on')), matching: find.byType(ColoredBox)))
          .color,
      colors.selected,
    );
    expect(_thumb(tester).center, tester.getCenter(find.byKey(const Key('on'))));
    await tester.pumpWidget(toggleApp(FlSwitch(value: false, label: 'Son', thumbIcon: icon, onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ColoredBox>(find.descendant(of: find.byKey(const Key('off')), matching: find.byType(ColoredBox)))
          .color,
      colors.onSurfaceMuted,
    );
  });
}
