import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FlTheme> _resolve(WidgetTester tester, Widget Function(Widget probe) wrap) async {
  late FlTheme theme;
  await tester.pumpWidget(
    wrap(
      Builder(
        builder: (context) {
          theme = FlScope.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return theme;
}

void main() {
  testWidgets("devrait choisir compact sur bureau et confortable sur mobile quand aucune densité n'est donnée", (
    tester,
  ) async {
    const expected = {
      TargetPlatform.iOS: FlDensity.comfortable,
      TargetPlatform.android: FlDensity.comfortable,
      TargetPlatform.fuchsia: FlDensity.comfortable,
      TargetPlatform.macOS: FlDensity.compact,
      TargetPlatform.windows: FlDensity.compact,
      TargetPlatform.linux: FlDensity.compact,
    };
    for (final MapEntry(key: platform, value: density) in expected.entries) {
      final theme = await _resolve(tester, (probe) => FlScope(platform: platform, child: probe));
      expect(theme.density, density, reason: platform.name);
    }
  });

  testWidgets('devrait suivre la luminosité de la plateforme quand le scope ne la fixe pas', (tester) async {
    final theme = await _resolve(
      tester,
      (probe) => MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: FlScope(child: probe),
      ),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.colors.surface, FlTokens.defaults.dark.surface);
  });

  testWidgets('devrait préférer la luminosité du scope à celle de la plateforme quand elle est donnée', (tester) async {
    final theme = await _resolve(
      tester,
      (probe) => MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: FlScope(brightness: Brightness.light, child: probe),
      ),
    );
    expect(theme.colors.surface, FlTokens.defaults.light.surface);
  });

  testWidgets("devrait rendre un thème par défaut sans exception quand aucun FlScope n'est posé", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final theme = await _resolve(tester, (probe) => probe);
      expect(theme.platform, TargetPlatform.iOS);
      expect(theme.density, FlDensity.comfortable);
      expect(theme.brightness, Brightness.light);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("devrait résoudre l'échelle iOS sur iOS et l'échelle Android ailleurs, bureau compris", (tester) async {
    const headline = {
      TargetPlatform.iOS: (size: 17.0, lineHeight: 22.0),
      TargetPlatform.android: (size: 16.0, lineHeight: 24.0),
      TargetPlatform.macOS: (size: 16.0, lineHeight: 24.0),
    };
    for (final MapEntry(key: platform, value: expected) in headline.entries) {
      final theme = await _resolve(tester, (probe) => FlScope(platform: platform, child: probe));
      final style = theme.typography.resolve(FlTextRole.headline);
      final strut = theme.typography.strut(FlTextRole.headline);
      expect(style.fontSize, expected.size, reason: platform.name);
      expect(strut.fontSize! * strut.height!, closeTo(expected.lineHeight, 1e-9), reason: platform.name);
      expect(style.fontFamily, isNull);
    }
  });

  testWidgets("devrait hériter du FlScope parent ce qu'un FlScope imbriqué ne fixe pas", (tester) async {
    final custom = FlTokens(
      light: FlTokens.defaults.dark,
      dark: FlTokens.defaults.light,
      shape: FlTokens.defaults.shape,
      shadow: FlTokens.defaults.shadow,
      space: FlTokens.defaults.space,
      size: FlTokens.defaults.size,
      motion: FlTokens.defaults.motion,
      typography: FlTokens.defaults.typography,
    );
    final theme = await _resolve(
      tester,
      (probe) => MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.light),
        child: FlScope(
          tokens: custom,
          brightness: Brightness.dark,
          platform: TargetPlatform.iOS,
          density: FlDensity.spacious,
          child: FlScope(density: FlDensity.compact, child: probe),
        ),
      ),
    );
    expect(theme.tokens, same(custom));
    expect(theme.brightness, Brightness.dark);
    expect(theme.platform, TargetPlatform.iOS);
    expect(theme.density, FlDensity.compact);
    expect(theme.colors.surface, FlTokens.defaults.light.surface);
  });

  testWidgets('devrait choisir la densité par défaut de la plateforme du scope imbriqué quand il la change', (
    tester,
  ) async {
    final theme = await _resolve(
      tester,
      (probe) => FlScope(
        platform: TargetPlatform.macOS,
        child: FlScope(platform: TargetPlatform.iOS, child: probe),
      ),
    );
    expect(theme.density, FlDensity.comfortable);
  });

  testWidgets('devrait garder sa densité sans se reconstruire quand une souris apparaît après le premier frame', (
    tester,
  ) async {
    for (final (platform, density) in [
      (TargetPlatform.android, FlDensity.comfortable),
      (TargetPlatform.macOS, FlDensity.compact),
    ]) {
      final theme = await _resolve(tester, (probe) => FlScope(platform: platform, child: probe));
      var scopeRebuilds = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        if (element.widget is FlScope) scopeRebuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect(WidgetsBinding.instance.mouseTracker.mouseIsConnected, isTrue);
      expect(scopeRebuilds, 0, reason: platform.name);
      expect(theme.density, density, reason: platform.name);
      debugOnRebuildDirtyWidget = null;
      await mouse.removePointer();
    }
  });

  test('devrait donner la densité de la plateforme, web compris, sans regarder le pointeur', () {
    const expected = {
      TargetPlatform.iOS: FlDensity.comfortable,
      TargetPlatform.android: FlDensity.comfortable,
      TargetPlatform.fuchsia: FlDensity.comfortable,
      TargetPlatform.macOS: FlDensity.compact,
      TargetPlatform.windows: FlDensity.compact,
      TargetPlatform.linux: FlDensity.compact,
    };
    for (final MapEntry(key: platform, value: density) in expected.entries) {
      expect(FlDensity.defaultFor(platform), density, reason: platform.name);
    }
  });

  testWidgets('devrait donner 44/48/56 de hauteur de contrôle et 8/12/16 de padding de liste selon la densité', (
    tester,
  ) async {
    const expected = {
      FlDensity.compact: (controlHeight: 44.0, listPadding: 8.0),
      FlDensity.comfortable: (controlHeight: 48.0, listPadding: 12.0),
      FlDensity.spacious: (controlHeight: 56.0, listPadding: 16.0),
    };
    for (final MapEntry(key: density, value: metrics) in expected.entries) {
      final theme = await _resolve(tester, (probe) => FlScope(density: density, child: probe));
      expect((controlHeight: theme.controlHeight, listPadding: theme.listPadding), metrics, reason: density.name);
    }
  });

  testWidgets('devrait prévenir un scope imbriqué quand les demandes du parent changent sans changer son thème', (
    tester,
  ) async {
    late FlTheme theme;
    final child = FlScope(
      platform: TargetPlatform.iOS,
      child: Builder(
        builder: (context) {
          theme = FlScope.of(context);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(FlScope(platform: TargetPlatform.macOS, density: FlDensity.compact, child: child));
    expect(theme.density, FlDensity.compact);
    await tester.pumpWidget(FlScope(platform: TargetPlatform.macOS, child: child));
    expect(theme.density, FlDensity.comfortable);
  });
}
