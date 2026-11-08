import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  FlDensity? density,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: platform,
      density: density,
      child: FocusScope(
        autofocus: true,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  ),
);

FlTokens get _tokens => FlTokens.defaults;

const _leading = SizedBox(key: Key('leading'), width: 40, height: 40);
const _trailing = SizedBox(key: Key('trailing'), width: 20, height: 20);

Rect _rect(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

void main() {
  testWidgets(
    "devrait s'annoncer comme un seul élément avec titre et sous-titre, sans action, quand onPressed est nul",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const FlListRow(title: 'Wi-Fi', subtitle: 'Maison')));
      expect(
        tester.getSemantics(find.byType(FlListRow)),
        matchesSemantics(label: 'Wi-Fi\nMaison', textDirection: TextDirection.ltr),
      );
      semantics.dispose();
    },
  );

  testWidgets("devrait s'annoncer comme un bouton activé et focalisable quand onPressed est fourni", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', subtitle: 'Maison', onPressed: () {})));
    expect(
      tester.getSemantics(find.byType(FlListRow)),
      matchesSemantics(
        label: 'Wi-Fi\nMaison',
        textDirection: TextDirection.ltr,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait garder un trailing interactif comme nœud distinct, avec sa propre action, sous la ligne', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var trailingTaps = 0;
    var rowTaps = 0;
    await tester.pumpWidget(
      _app(
        FlListRow(
          title: 'Notifications',
          onPressed: () => rowTaps++,
          trailing: Semantics(
            container: true,
            label: 'Activer',
            onTap: () => trailingTaps++,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => trailingTaps++, child: _trailing),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Activer')),
      matchesSemantics(label: 'Activer', hasTapAction: true),
    );
    await tester.tap(find.byKey(const Key('trailing')));
    expect((trailingTaps, rowTaps), (1, 0));
    await tester.tap(find.text('Notifications'));
    expect((trailingTaps, rowTaps), (1, 1));
    semantics.dispose();
  });

  testWidgets("devrait s'activer avec Tab puis Entrée et Espace, et montrer l'anneau de focus", (tester) async {
    var presses = 0;
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', onPressed: () => presses++)));
    final ring = paints..rrect(color: _tokens.light.focusRing, style: PaintingStyle.stroke);
    expect(find.byType(FlListRow), isNot(ring));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(FlListRow), ring);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, 2);
  });

  testWidgets('devrait colorer le fond sans rétrécir la ligne quand elle est pressée', (tester) async {
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', onPressed: () {})));
    final before = tester.getRect(find.text('Wi-Fi'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Wi-Fi')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Wi-Fi')), before);
    expect(find.byType(FlListRow), paints..rect(color: _tokens.light.surfacePressed));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(FlListRow), isNot(paints..rect(color: _tokens.light.surfacePressed)));
  });

  testWidgets('devrait poser le contenu à la marge de liste de la densité, haut d’un contrôle plus space.sm au moins', (
    tester,
  ) async {
    for (final density in FlDensity.values) {
      await tester.pumpWidget(
        _app(
          const FlListRow(title: 'Wi-Fi', trailing: _trailing),
          density: density,
        ),
      );
      final metrics = _tokens.size.metricsFor(density);
      final padding = metrics.listPadding;
      final line = _tokens.typography.android.textBase.lineHeight;
      final height = math.max(
        math.max(_tokens.size.hitTargetAndroid, metrics.controlHeight + _tokens.space.sm),
        line + 2 * padding,
      );
      expect(tester.getSize(find.byType(FlListRow)).height, height, reason: density.name);
      expect(tester.getRect(find.text('Wi-Fi')).top, (height - line) / 2, reason: density.name);
      expect(tester.getRect(find.text('Wi-Fi')).top, greaterThanOrEqualTo(padding), reason: density.name);
    }
  });

  testWidgets(
    'devrait garder sa hauteur de liste quand un interrupteur est au bout, sa cible hors de la mise en page',
    (tester) async {
      await tester.pumpWidget(
        _app(
          FlListRow(
            title: 'Wi-Fi',
            trailing: FlSwitch(value: true, label: 'Wi-Fi', onChanged: (_) {}),
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      final track = tester.getSize(find.byType(FlSwitch)).height;
      expect(track, 24);
      final line = _tokens.typography.ios.textBase.lineHeight;
      expect(
        tester.getSize(find.byType(FlListRow)).height,
        math.max(track, line) + 2 * 16,
        reason: '56 : p-4 de HeroUI autour du titre de 24, et non 44 + 2 × 16 = 76',
      );
    },
  );

  testWidgets('devrait garder la cible de la plateforme quand la ligne pressable est compacte', (tester) async {
    for (final (platform, guideline) in [
      (TargetPlatform.android, androidTapTargetGuideline),
      (TargetPlatform.iOS, iOSTapTargetGuideline),
    ]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          FlListRow(title: 'Wi-Fi', onPressed: () {}),
          platform: platform,
          density: FlDensity.compact,
        ),
      );
      await expectLater(tester, meetsGuideline(guideline), reason: platform.name);
      semantics.dispose();
    }
  });

  testWidgets('devrait placer leading au début, trailing à la fin et centrer les deux quand le sens change', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          const FlListRow(title: 'Wi-Fi', leading: _leading, trailing: _trailing),
          direction: direction,
        ),
      );
      final row = tester.getRect(find.byType(FlListRow));
      final leading = _rect(tester, 'leading');
      final trailing = _rect(tester, 'trailing');
      final title = tester.getRect(find.text('Wi-Fi'));
      final gutter = _tokens.space.lg;
      if (direction == TextDirection.ltr) {
        expect(leading.left, row.left + gutter);
        expect(trailing.right, row.right - gutter);
        expect(title.left, leading.right + _tokens.space.md);
      } else {
        expect(leading.right, row.right - gutter);
        expect(trailing.left, row.left + gutter);
        expect(title.right, leading.left - _tokens.space.md);
      }
      expect(leading.center.dy, row.center.dy, reason: direction.name);
      expect(trailing.center.dy, row.center.dy, reason: direction.name);
    }
  });

  testWidgets(
    'devrait séparer les lignes du groupe d’un filet retiré de 16 au début, jusqu’au bord de fin, sur la surface',
    (tester) async {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          _app(
            const FlListGroup(
              variant: FlSurfaceVariant.secondary,
              children: [
                FlListRow(key: Key('a'), title: 'Wi-Fi'),
                FlListRow(key: Key('b'), title: 'Bluetooth'),
              ],
            ),
            platform: TargetPlatform.iOS,
            direction: direction,
          ),
        );
        expect(tester.widget<FlSurface>(find.byType(FlSurface)).variant, FlSurfaceVariant.secondary);
        final group = tester.getRect(find.byType(FlListGroup));
        final line = tester.getRect(find.byType(FlSeparator));
        expect(find.byType(FlSeparator), findsOneWidget);
        final (start, end) = direction == TextDirection.ltr
            ? (line.left - group.left, group.right - line.right)
            : (group.right - line.right, line.left - group.left);
        expect(start, 16, reason: direction.name);
        expect(end, 0, reason: direction.name);
        expect(line.top, tester.getRect(find.byKey(const Key('a'))).bottom, reason: direction.name);
        expect(tester.getRect(find.byKey(const Key('b'))).top, line.bottom, reason: direction.name);
        expect(tester.getRect(find.byKey(const Key('a'))).width, group.width, reason: direction.name);
      }
    },
  );

  testWidgets('devrait ne tirer aucun filet quand separators est faux', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlListGroup(
          separators: false,
          children: [
            FlListRow(title: 'Wi-Fi'),
            FlListRow(title: 'Bluetooth'),
          ],
        ),
      ),
    );
    expect(find.byType(FlSeparator), findsNothing);
  });

  testWidgets('devrait écrire le titre en textBase normal et le sous-titre en textSm atténué', (tester) async {
    await tester.pumpWidget(_app(const FlListRow(title: 'Wi-Fi', subtitle: 'Maison')));
    final title = tester.widget<Text>(find.text('Wi-Fi')).style!;
    expect(title.fontSize, _tokens.typography.android.textBase.size);
    expect(title.fontWeight, _tokens.typography.weight.normal);
    expect(title.color, _tokens.light.onSurface);
    final subtitle = tester.widget<Text>(find.text('Maison')).style!;
    expect(subtitle.fontSize, _tokens.typography.android.textSm.size);
    expect(subtitle.color, _tokens.light.onSurfaceMuted);
  });

  testWidgets('devrait tourner le chevron vers le sens de lecture, à 16 et atténué', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          const FlListRow(title: 'Wi-Fi', trailing: FlListRowChevron()),
          direction: direction,
        ),
      );
      final chevron = find.byType(FlListRowChevron);
      expect(tester.getSize(chevron), const Size.square(16));
      expect(IconTheme.of(tester.element(chevron)).color, _tokens.light.onSurfaceMuted);
      final flip = tester.widget<Transform>(find.descendant(of: chevron, matching: find.byType(Transform)));
      expect(flip.transform.entry(0, 0), direction == TextDirection.rtl ? -1 : 1, reason: direction.name);
    }
  });

  testWidgets(
    'devrait passer la valeur sous le titre au-delà de 1,5× et laisser l’indicateur en bout de ligne, centré',
    (tester) async {
      for (final (scale, stacked) in [(1.5, false), (1.6, true), (2.0, true)]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: _app(const FlListRow(title: 'Wi-Fi', value: 'Oui', trailing: _trailing)),
          ),
        );
        final row = tester.getRect(find.byType(FlListRow));
        final title = tester.getRect(find.text('Wi-Fi'));
        final value = tester.getRect(find.text('Oui'));
        final indicator = _rect(tester, 'trailing');
        expect(value.top >= title.bottom, stacked, reason: '$scale');
        if (stacked) expect(value.left, title.left, reason: '$scale');
        expect(indicator.right, row.right - _tokens.space.lg, reason: '$scale');
        expect(indicator.center.dy, row.center.dy, reason: '$scale');
      }
    },
  );

  testWidgets(
    'devrait donner la même hauteur aux lignes pressable et non pressable, et couvrir la ligne du fond pressé, en compact',
    (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final leading in [null, const SizedBox(width: 16, height: 16)]) {
          final reason = '${platform.name} ${leading == null ? 'sans' : 'avec'} début';
          await tester.pumpWidget(
            _app(
              Column(
                children: [
                  FlListRow(key: const Key('a'), title: 'Wi-Fi', leading: leading, onPressed: () {}),
                  FlListRow(key: const Key('b'), title: 'Wi-Fi', leading: leading),
                ],
              ),
              platform: platform,
              density: FlDensity.compact,
            ),
          );
          final pressable = tester.getRect(find.byKey(const Key('a')));
          final plain = tester.getRect(find.byKey(const Key('b')));
          expect(pressable.height, plain.height, reason: reason);
          expect(plain.top, pressable.bottom, reason: reason);
          final gesture = await tester.startGesture(pressable.center);
          await tester.pump();
          expect(
            find.byKey(const Key('a')),
            paints..rect(rect: Offset.zero & pressable.size, color: _tokens.light.surfacePressed),
            reason: reason,
          );
          await gesture.up();
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets('devrait se déclarer désactivé, se griser et ignorer le toucher quand enabled est faux', (tester) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', enabled: false, onPressed: () => presses++)));
    expect(
      tester.getSemantics(find.byType(FlListRow)),
      matchesSemantics(label: 'Wi-Fi', textDirection: TextDirection.ltr, isButton: true, hasEnabledState: true),
    );
    await tester.tap(find.byType(FlListRow), warnIfMissed: false);
    expect(presses, 0);
    expect(tester.widget<Text>(find.text('Wi-Fi')).style!.color, _tokens.light.onDisabled);

    await tester.pumpWidget(_app(const FlListRow(title: 'Wi-Fi', value: 'Maison', enabled: false)));
    expect(
      tester.getSemantics(find.byType(FlListRow)),
      matchesSemantics(label: 'Wi-Fi\nMaison', textDirection: TextDirection.ltr, hasEnabledState: true),
    );
    expect(tester.widget<Text>(find.text('Maison')).style!.color, _tokens.light.onDisabled);
    semantics.dispose();
  });

  testWidgets("devrait dessiner l'anneau de focus dans le bord de la ligne", (tester) async {
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', onPressed: () {})));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final size = tester.getSize(find.byType(FlListRow));
    expect(
      find.byType(FlListRow),
      paints..rrect(
        rrect: RRect.fromRectAndRadius((Offset.zero & size).deflate(_tokens.size.focusRing / 2), Radius.zero),
        color: _tokens.light.focusRing,
        style: PaintingStyle.stroke,
      ),
    );
  });

  RenderBox layoutOf(WidgetTester tester) =>
      tester.renderObject<RenderBox>(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RowLayout'));

  testWidgets('devrait aligner la ligne de base du titre sur celle de ses voisins dans une Row', (tester) async {
    final style = _tokens.typography.android.resolve(FlTextRole.textBase);
    final strut = _tokens.typography.android.strut(FlTextRole.textBase);
    await tester.pumpWidget(
      _app(
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Ab', style: style, strutStyle: strut),
            const Expanded(
              child: FlListRow(title: 'Wi-Fi', subtitle: 'Maison', leading: _leading),
            ),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.text('Wi-Fi')).top, tester.getRect(find.text('Ab')).top);
  });

  testWidgets('devrait donner en layout sec la taille et la ligne de base du layout réel', (tester) async {
    await tester.pumpWidget(_app(const FlListRow(title: 'Wi-Fi', subtitle: 'Maison', leading: _leading)));
    final layout = layoutOf(tester);
    final constraints = BoxConstraints(maxWidth: layout.size.width);
    expect(layout.getDryLayout(constraints), layout.size);
    final title = tester.getRect(find.text('Wi-Fi')).top - tester.getRect(find.byType(FlListRow)).top;
    final paragraph = TextPainter(
      text: TextSpan(text: 'Wi-Fi', style: _tokens.typography.android.resolve(FlTextRole.textBase)),
      strutStyle: _tokens.typography.android.strut(FlTextRole.textBase),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(paragraph.dispose);
    expect(
      layout.getDryBaseline(constraints, TextBaseline.alphabetic),
      closeTo(title + paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic), 1e-6),
    );
  });

  testWidgets('devrait donner ses intrinsèques : une ligne sur une ligne sous IntrinsicWidth, sa hauteur réelle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: IntrinsicWidth(
            child: FlListRow(title: 'Wi-Fi', leading: _leading, trailing: _trailing),
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text('Wi-Fi'));
    expect(title.height, _tokens.typography.android.textBase.lineHeight);
    final row = tester.getRect(find.byType(FlListRow));
    expect(row.width, 2 * _tokens.space.lg + 40 + 2 * _tokens.space.md + title.width + 20);
    final layout = layoutOf(tester);
    expect(layout.getMinIntrinsicWidth(double.infinity), lessThanOrEqualTo(layout.size.width));
    expect(layout.getMinIntrinsicHeight(layout.size.width), layout.size.height);
    expect(layout.getMaxIntrinsicHeight(layout.size.width), layout.size.height);
  });

  testWidgets('devrait passer la fin de ligne sous le titre sans couper de mot quand le texte est agrandi', (
    tester,
  ) async {
    // La police de test donne 1 em à chaque glyphe : à 2,0, « Sauvegarde »
    // fait 320 points et tient dans la ligne de 358 moins ses marges, pas à
    // côté de l'interrupteur ; « avion » (160) tient dans celle de 220.
    for (final direction in TextDirection.values) {
      for (final (width, title) in [(358.0, 'Sauvegarde'), (220.0, 'Mode avion')]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: direction,
              child: FlScope(
                brightness: Brightness.light,
                platform: TargetPlatform.iOS,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: FlListRow(
                      title: title,
                      trailing: FlSwitch(value: true, onChanged: (_) {}, label: title),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final reason = '$width ${direction.name}';
        expect(tester.takeException(), isNull, reason: reason);
        expect(_cutWords(tester.renderObject<RenderParagraph>(find.text(title)), title), isEmpty, reason: reason);
        final row = tester.getRect(find.byType(FlListRow));
        final text = tester.getRect(find.text(title));
        final control = tester.getRect(find.byType(FlSwitch));
        expect(control.top, greaterThanOrEqualTo(text.bottom), reason: '$reason : l’interrupteur passe dessous');
        final gutter = _tokens.space.lg;
        if (direction == TextDirection.ltr) {
          expect(control.left, row.left + gutter, reason: '$reason : au début');
        } else {
          expect(control.right, row.right - gutter, reason: '$reason : au début');
        }
        expect(row.bottom, greaterThanOrEqualTo(control.bottom + _tokens.size.listPaddingComfortable), reason: reason);
      }
    }
  });

  testWidgets('devrait garder la fin de ligne au bout quand le titre tient à côté sans couper de mot', (tester) async {
    await tester.pumpWidget(
      _app(
        FlListRow(
          title: 'Notifications de la semaine',
          trailing: FlSwitch(value: true, onChanged: (_) {}, label: 'Notifications'),
        ),
      ),
    );
    final row = tester.getRect(find.byType(FlListRow));
    final control = tester.getRect(find.byType(FlSwitch));
    expect(control.right, row.right - _tokens.space.lg);
    expect(control.center.dy, row.center.dy);
  });

  testWidgets('devrait garder la fin au bout à 1,0 quand seul le sous-titre a un mot trop long, une adresse', (
    tester,
  ) async {
    for (final trailing in <Widget>[
      FlSwitch(value: true, onChanged: (_) {}, label: 'Camille'),
      const FlListRowChevron(),
    ]) {
      await tester.pumpWidget(
        _app(FlListRow(title: 'Camille', subtitle: 'camille.martin@example.com', trailing: trailing)),
      );
      final row = tester.getRect(find.byType(FlListRow));
      final end = tester.getRect(find.byWidget(trailing));
      expect(end.right, row.right - _tokens.space.lg, reason: '${trailing.runtimeType}');
      expect(end.center.dy, closeTo(row.center.dy, 0.5), reason: '${trailing.runtimeType}');
    }
  });

  testWidgets('devrait passer la valeur sous un titre long et garder le chevron au bout, centré', (tester) async {
    // À 1,0, « Sauvegarde » (160) remplit la colonne de 220 moins les marges
    // et le chevron : la valeur passe dessous, le chevron reste.
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: FlScope(
            brightness: Brightness.light,
            platform: TargetPlatform.iOS,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 220,
                child: FlListRow(
                  title: 'Sauvegarde',
                  value: 'Activée',
                  trailing: const FlListRowChevron(),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final reason = direction.name;
      final row = tester.getRect(find.byType(FlListRow));
      final title = tester.getRect(find.text('Sauvegarde'));
      final value = tester.getRect(find.text('Activée'));
      final chevron = tester.getRect(find.byType(FlListRowChevron));
      expect(_cutWords(tester.renderObject<RenderParagraph>(find.text('Sauvegarde')), 'Sauvegarde'), isEmpty);
      expect(value.top, greaterThanOrEqualTo(title.bottom), reason: reason);
      final gutter = _tokens.space.lg;
      if (direction == TextDirection.ltr) {
        expect(value.left, title.left, reason: reason);
        expect(chevron.right, row.right - gutter, reason: reason);
      } else {
        expect(value.right, title.right, reason: reason);
        expect(chevron.left, row.left + gutter, reason: reason);
      }
      expect(chevron.center.dy, closeTo(row.center.dy, 0.5), reason: reason);
    }
  });

  testWidgets('devrait nommer FlListRow quand la largeur n’est pas bornée', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pumpWidget(_app(const Row(children: [FlListRow(title: 'Wi-Fi')])));
    FlutterError.onError = original;
    expect(errors.first.exceptionAsString(), contains('FlListRow needs a bounded width'));
  });

  testWidgets('devrait prendre le focus dès le premier frame quand autofocus est vrai', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.pumpWidget(_app(FlListRow(title: 'Wi-Fi', autofocus: true, onPressed: () {})));
    await tester.pump();
    expect(find.byType(FlListRow), paints..rrect(color: _tokens.light.focusRing, style: PaintingStyle.stroke));
  });

  testWidgets('devrait écrire le titre d’une ligne danger en danger, et en onDisabled quand elle est désactivée', (
    tester,
  ) async {
    Color? title() => tester.widget<Text>(find.text('Supprimer le compte')).style!.color;
    await tester.pumpWidget(_app(FlListRow(title: 'Supprimer le compte', danger: true, onPressed: () {})));
    expect(title(), _tokens.light.danger);
    await tester.pumpWidget(
      _app(FlListRow(title: 'Supprimer le compte', danger: true, enabled: false, onPressed: () {})),
    );
    expect(title(), _tokens.light.onDisabled);
  });

  testWidgets('devrait faire partir chaque filet de separatorInset quand il est donné', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlListGroup(
          separatorInset: 44,
          children: [
            FlListRow(title: 'Wi-Fi', leading: _leading),
            FlListRow(title: 'Bluetooth', leading: _leading),
            FlListRow(title: 'Langue'),
          ],
        ),
      ),
    );
    final group = tester.getRect(find.byType(FlListGroup));
    for (var i = 0; i < 2; i++) {
      final rect = tester.getRect(find.byType(FlSeparator).at(i));
      expect(rect.left - group.left, 44);
      expect(rect.right, group.right);
    }
    expect(find.byType(FlSeparator), findsNWidgets(2));
  });
}

/// Les mots que [paragraph] coupe en fin de ligne : deux lettres voisines
/// posées sur deux lignes.
List<String> _cutWords(RenderParagraph paragraph, String text) {
  double top(int i) => paragraph.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1)).first.top;
  return [
    for (var i = 1; i < text.length; i++)
      if (text[i - 1] != ' ' && text[i] != ' ' && top(i - 1) != top(i)) text.substring(0, i + 1),
  ];
}
