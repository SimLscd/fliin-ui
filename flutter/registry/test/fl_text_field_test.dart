import 'dart:io';

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';
import 'torture/themes.dart';
import 'torture/torture.g.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  FlDensity? density,
  TextDirection direction = TextDirection.ltr,
  bool announces = true,
  FlTokens? tokens,
  double scale = 1,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(supportsAnnounce: announces, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: FlScope(
        tokens: tokens,
        brightness: Brightness.light,
        platform: platform,
        density: density,
        child: OverlayHost(
          child: FocusScope(
            autofocus: true,
            child: Center(child: SizedBox(width: 320, child: child)),
          ),
        ),
      ),
    ),
  ),
);

FlColorTokens get _colors => FlTokens.defaults.light;

Finder _frame(String label) =>
    find.descendant(of: find.widgetWithText(FlTextField, label), matching: find.byType(FlInputFrame));

/// Le fond de l'entrée, que le contour entoure.
Finder _box(String label) => find.descendant(of: _frame(label), matching: find.byType(DecoratedBox)).first;

Color? _outline(WidgetTester tester, String label) => tester.widget<FlInputFrame>(_frame(label)).outline;

bool _focused(WidgetTester tester, String label) => tester.widget<FlInputFrame>(_frame(label)).focused;

/// Un anneau de [color] peint autour du fond, qui couvre [inside] et pas
/// [outside], en coordonnées du fond.
PaintPattern _paintsRing(Color color, {Offset? inside, Offset? outside}) => paints
  ..something((method, arguments) {
    if (method != #drawPath) return false;
    final [Path path, Paint paint] = arguments;
    return paint.color.toARGB32() == color.toARGB32() &&
        (inside == null || path.contains(inside)) &&
        (outside == null || !path.contains(outside));
  });

/// La couleur et l'épaisseur du contour peint par le fond.
BorderSide _contour(WidgetTester tester, String label) =>
    ((tester.widget<DecoratedBox>(_box(label)).decoration as ShapeDecoration).shape as FlContinuousBorder).side;

/// L'opacité du texte saisi, et du fond qui se peint avec lui.
double _opacity(WidgetTester tester, String label) => _paintOpacity(
  tester,
  find.descendant(of: find.widgetWithText(FlTextField, label), matching: find.byType(EditableText)),
);

/// L'opacité où se peint [finder] : le produit des calques d'opacité
/// au-dessus du premier calque de son sous-arbre (un `RepaintBoundary`, la
/// cible de la barre d'édition d'un `EditableText`).
double _paintOpacity(WidgetTester tester, Finder finder) {
  Layer? layerOf(RenderObject node) {
    Layer? found = node.debugLayer;
    node.visitChildren((child) => found ??= layerOf(child));
    return found;
  }

  var opacity = 1.0;
  for (Layer? layer = layerOf(tester.renderObject(finder)); layer != null; layer = layer.parent) {
    if (layer is OpacityLayer) opacity *= layer.alpha! / 255;
  }
  return opacity;
}

EditableText _editable(WidgetTester tester, String label) => tester.widget<EditableText>(
  find.descendant(of: find.widgetWithText(FlTextField, label), matching: find.byType(EditableText)),
);

void main() {
  setUpAll(loadTortureFonts);

  testWidgets(
    "devrait s'annoncer comme un champ de texte activé avec son libellé et le placeholder en indice quand il est vide",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const FlTextField(label: 'E-mail', placeholder: 'nom@exemple.fr')));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        matchesSemantics(
          label: 'E-mail',
          hint: 'nom@exemple.fr',
          textDirection: TextDirection.ltr,
          isTextField: true,
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
    'devrait former un seul nœud, libellé et champ ensemble, à la boîte de saisie ou à la cible de la plateforme',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (density, height) in [(FlDensity.comfortable, 48.0), (FlDensity.compact, 44.0)]) {
        await tester.pumpWidget(
          _app(
            const FlTextField(label: 'E-mail'),
            platform: TargetPlatform.iOS,
            density: density,
          ),
        );
        final node = tester.getSemantics(find.byType(EditableText));
        expect(node.label, 'E-mail', reason: density.name);
        expect(node.flagsCollection.isTextField, isTrue, reason: density.name);
        expect(node.rect.size, Size(tester.getSize(_box('E-mail')).width, height), reason: density.name);
      }
      semantics.dispose();
    },
  );

  testWidgets('devrait donner la saisie pour valeur et retirer le placeholder quand du texte est tapé', (tester) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    await tester.pumpWidget(_app(FlTextField(label: 'E-mail', placeholder: 'nom@exemple.fr', onChanged: changes.add)));
    await tester.enterText(find.byType(EditableText), 'ana@fliin.dev');
    await tester.pump();
    expect(changes, ['ana@fliin.dev']);
    expect(find.text('nom@exemple.fr'), findsNothing);
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.value, 'ana@fliin.dev');
    expect(node.hint, isEmpty);
    semantics.dispose();
  });

  testWidgets(
    "devrait se déclarer invalide et lire l'erreur une seule fois, dans l'indice du champ, quand la plateforme annonce",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const FlTextField(label: 'Mot de passe', helper: '8 caractères au moins', error: 'Trop court')),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        matchesSemantics(
          label: 'Mot de passe',
          hint: 'Trop court',
          textDirection: TextDirection.ltr,
          validationResult: SemanticsValidationResult.invalid,
          isTextField: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Trop court'), findsNothing);
      expect(find.text('8 caractères au moins'), findsNothing);
      expect(_outline(tester, 'Mot de passe'), _colors.danger);
      semantics.dispose();
    },
  );

  testWidgets("devrait annoncer l'erreur quand elle apparaît, et pas quand le champ naît en erreur", (tester) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', error: 'Inconnue')));
    expect(tester.takeAnnouncements(), isEmpty);
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', error: 'Ville inconnue')));
    expect(tester.takeAnnouncements().map((a) => a.message), ['Ville inconnue']);
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', error: 'Ville inconnue')));
    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets(
    "devrait lire l'erreur une seule fois, par sa région vivante et hors de l'indice, quand la plateforme n'annonce pas",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const FlTextField(label: 'Mot de passe', error: 'Trop court'), announces: false));
      final field = tester.getSemantics(find.byType(EditableText));
      expect(field.hint, isEmpty);
      expect(field.validationResult, SemanticsValidationResult.invalid);
      expect(
        tester.getSemantics(find.text('Trop court')),
        matchesSemantics(label: 'Trop court', textDirection: TextDirection.ltr, isLiveRegion: true),
      );
      await tester.pumpWidget(_app(const FlTextField(label: 'Mot de passe'), announces: false));
      await tester.pumpWidget(_app(const FlTextField(label: 'Mot de passe', error: 'Trop court'), announces: false));
      expect(tester.takeAnnouncements(), isEmpty);
      semantics.dispose();
    },
  );

  testWidgets("devrait lire l'aide dans l'indice du champ, sans nœud séparé, quand error est nul", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlTextField(label: 'Mot de passe', helper: '8 caractères au moins')));
    expect(find.text('8 caractères au moins'), findsOneWidget);
    final field = tester.getSemantics(find.byType(EditableText));
    expect(field.hint, '8 caractères au moins');
    expect(field.validationResult, SemanticsValidationResult.none);
    expect(find.bySemanticsLabel('8 caractères au moins'), findsNothing);
    expect(_outline(tester, 'Mot de passe'), isNull);
    semantics.dispose();
  });

  testWidgets("devrait masquer la saisie à l'accessibilité quand obscureText est vrai", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlTextField(label: 'Mot de passe', obscureText: true)));
    await tester.enterText(find.byType(EditableText), 'secret');
    await tester.pump();
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.flagsCollection.isObscured, isTrue);
    expect(node.value, isNot(contains('secret')));
    semantics.dispose();
  });

  testWidgets(
    'devrait se déclarer désactivé et en lecture seule, ignorer le toucher et le clavier quand enabled est faux',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'Paris');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(FlTextField(label: 'Ville', controller: controller, enabled: false)));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        matchesSemantics(
          label: 'Ville',
          value: 'Paris',
          textDirection: TextDirection.ltr,
          isTextField: true,
          hasEnabledState: true,
          isReadOnly: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.byType(EditableText), warnIfMissed: false);
      await tester.pump();
      expect(_editable(tester, 'Ville').focusNode.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_editable(tester, 'Ville').focusNode.hasFocus, isFalse);
      expect(_opacity(tester, 'Ville'), closeTo(FlTokens.defaults.size.disabledOpacity, 1 / 255));
      semantics.dispose();
    },
  );

  testWidgets("devrait prendre le focus avec Tab, s'entourer de l'anneau de focus, puis le passer au champ suivant", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlTextField(label: 'Prénom'),
            FlTextField(label: 'Nom'),
          ],
        ),
      ),
    );
    expect(_focused(tester, 'Prénom'), isFalse);
    expect(_frame('Prénom'), isNot(_paintsRing(_colors.focusRing)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(tester, 'Prénom'), isTrue);
    await tester.pump(FlTokens.defaults.motion.short3);
    expect(_frame('Prénom'), _paintsRing(_colors.focusRing));
    expect(_outline(tester, 'Prénom'), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(tester, 'Prénom'), isFalse);
    expect(_focused(tester, 'Nom'), isTrue);
  });

  testWidgets('devrait appeler onSubmitted avec la saisie quand on valide au clavier', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _app(FlTextField(label: 'Recherche', textInputAction: TextInputAction.search, onSubmitted: submitted.add)),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'tarte');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, ['tarte']);
  });

  testWidgets('devrait prendre le focus quand on touche le champ', (tester) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    await tester.tap(find.byType(FlTextField).last);
    await tester.pump();
    expect(_editable(tester, 'Ville').focusNode.hasFocus, isTrue);
  });

  testWidgets('devrait tirer curseur, sélection et largeur du curseur des jetons quand le champ a le focus', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', autofocus: true)));
    await tester.pump();
    final editable = _editable(tester, 'Ville');
    expect(editable.cursorColor, _colors.onField);
    expect(editable.selectionColor, _colors.selection);
    expect(editable.cursorWidth, FlTokens.defaults.size.cursorWidth);

    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', error: 'Inconnue', autofocus: true)));
    expect(_editable(tester, 'Ville').cursorColor, _colors.danger);
  });

  testWidgets("devrait arrondir le curseur et en fondre l'opacité sur iOS, sauf quand le mouvement est réduit", (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville'), platform: TargetPlatform.iOS));
    expect(_editable(tester, 'Ville').cursorOpacityAnimates, isTrue);
    expect(_editable(tester, 'Ville').cursorRadius, isNotNull);

    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    expect(_editable(tester, 'Ville').cursorOpacityAnimates, isFalse);
    expect(_editable(tester, 'Ville').cursorRadius, isNull);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville'), platform: TargetPlatform.iOS));
    await tester.pump();
    expect(_editable(tester, 'Ville').cursorOpacityAnimates, isFalse);
  });

  testWidgets(
    'devrait dessiner le champ à la hauteur de la densité et garder la cible de la plateforme quand la densité change',
    (tester) async {
      for (final (platform, guideline, target) in [
        (TargetPlatform.android, androidTapTargetGuideline, 48.0),
        (TargetPlatform.iOS, iOSTapTargetGuideline, 44.0),
      ]) {
        for (final density in FlDensity.values) {
          final reason = '${platform.name} ${density.name}';
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            _app(
              const FlTextField(label: 'Ville'),
              platform: platform,
              density: density,
            ),
          );
          final metrics = FlTokens.defaults.size.metricsFor(density);
          expect(tester.getSize(_box('Ville')).height, metrics.controlHeight, reason: reason);
          expect(
            tester.getSemantics(find.byType(EditableText)).rect.height,
            greaterThanOrEqualTo(target),
            reason: reason,
          );
          await expectLater(tester, meetsGuideline(guideline), reason: reason);
          semantics.dispose();
        }
      }
    },
  );

  testWidgets('devrait placer le préfixe au début et le suffixe à la fin quand le texte va de droite à gauche', (
    tester,
  ) async {
    const prefix = Key('prefix');
    const suffix = Key('suffix');
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          const FlTextField(
            label: 'Montant',
            prefix: SizedBox(key: prefix, width: 10, height: 10),
            suffix: SizedBox(key: suffix, width: 10, height: 10),
          ),
          direction: direction,
        ),
      );
      final editable = tester.getRect(find.byType(EditableText));
      final before = tester.getRect(find.byKey(prefix));
      final after = tester.getRect(find.byKey(suffix));
      if (direction == TextDirection.ltr) {
        expect(before.right, lessThanOrEqualTo(editable.left));
        expect(after.left, greaterThanOrEqualTo(editable.right));
      } else {
        expect(before.left, greaterThanOrEqualTo(editable.right));
        expect(after.right, lessThanOrEqualTo(editable.left));
      }
    }
  });

  testWidgets('devrait rendre au nœud fourni son canRequestFocus quand le champ en change', (tester) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(_app(FlTextField(label: 'Ville', focusNode: a, enabled: false)));
    expect(a.canRequestFocus, isFalse);
    await tester.pumpWidget(_app(FlTextField(label: 'Ville', focusNode: b)));
    expect(a.canRequestFocus, isTrue);
    expect(b.canRequestFocus, isTrue);
  });

  testWidgets("devrait cesser d'écouter l'ancien nœud quand le champ en change", (tester) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final other = Focus(focusNode: a, child: const SizedBox.square(dimension: 10));
    await tester.pumpWidget(_app(FlTextField(label: 'Ville', focusNode: a)));
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            FlTextField(label: 'Ville', focusNode: b),
            other,
          ],
        ),
      ),
    );
    await tester.pumpWidget(_app(other));
    a.requestFocus();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait garder le texte quand le contrôleur fourni disparaît', (tester) async {
    final controller = TextEditingController(text: 'Paris');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(FlTextField(label: 'Ville', controller: controller)));
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    expect(_editable(tester, 'Ville').controller.text, 'Paris');
    expect(find.text('Paris'), findsOneWidget);
  });

  testWidgets('devrait garder le curseur dans la ligne de saisie quand la police dépasse la hauteur de ligne', (
    tester,
  ) async {
    for (final (tokens, platform, scale) in [
      for (final tokens in [tortureA, FlTokens.defaults])
        for (final platform in [TargetPlatform.android, TargetPlatform.iOS])
          for (final scale in [1.0, 2.0]) (tokens, platform, scale),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = TextEditingController(text: '42');
      await tester.pumpWidget(
        _app(
          FlTextField(label: 'Montant', controller: controller, autofocus: true),
          platform: platform,
          tokens: tokens,
        ),
      );
      await tester.pump();
      final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
      final caret = editable.getLocalRectForCaret(const TextPosition(offset: 2));
      final reason =
          '${platform.name} ${identical(tokens, tortureA) ? 'torture A' : 'défaut'} $scale : $caret dans ${editable.size}';
      expect((caret.center.dy - editable.size.height / 2).abs(), lessThanOrEqualTo(1), reason: reason);
      final box = tester.getRect(_box('Montant'));
      final global = MatrixUtils.transformRect(editable.getTransformTo(null), caret);
      expect(box.top, lessThanOrEqualTo(global.top), reason: reason);
      expect(box.bottom, greaterThanOrEqualTo(global.bottom), reason: reason);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });

  testWidgets(
    'devrait garder la hauteur du champ à la première frappe quand le placeholder ne tient pas sur une ligne',
    (tester) async {
      await tester.pumpWidget(
        _app(const FlTextField(label: 'E-mail', placeholder: 'prenom.nom-de-famille@exemple-de-domaine.fr'), scale: 2),
      );
      final before = tester.getSize(_box('E-mail')).height;
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pump();
      expect(tester.getSize(_box('E-mail')).height, before);
    },
  );

  testWidgets('devrait donner à la ligne de saisie au moins la hauteur de ligne de textSm', (tester) async {
    for (final (platform, style) in [
      (TargetPlatform.iOS, FlTokens.defaults.typography.ios.textSm),
      (TargetPlatform.android, FlTokens.defaults.typography.android.textSm),
    ]) {
      await tester.pumpWidget(_app(const FlTextField(label: 'Ville'), platform: platform));
      final line = find.ancestor(of: find.byType(EditableText), matching: find.byType(Stack)).first;
      expect(tester.getSize(line).height, style.lineHeight, reason: platform.name);
    }
  });

  testWidgets("devrait poser le fond et l'ombre field sans contour en primary, le fond control seul en secondary", (
    tester,
  ) async {
    for (final (variant, fill, shadow) in [
      (FlInputVariant.primary, _colors.field, FlTokens.defaults.shadow.light.field),
      (FlInputVariant.secondary, _colors.control, const <FlShadowLayer>[]),
    ]) {
      await tester.pumpWidget(_app(FlTextField(label: 'Ville', variant: variant)));
      expect(
        (tester.widget<DecoratedBox>(_box('Ville')).decoration as ShapeDecoration).color,
        fill,
        reason: '$variant',
      );
      expect(
        tester.widget<FlShadow>(find.descendant(of: _frame('Ville'), matching: find.byType(FlShadow))).layers,
        shadow,
        reason: '$variant',
      );
      expect(_contour(tester, 'Ville'), BorderSide.none, reason: '$variant : aucun contour au repos');
    }
  });

  testWidgets('devrait faire paraître un filet border sous le pointeur, puis le retirer', (tester) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byType(EditableText)));
    await tester.pumpAndSettle();
    expect(_contour(tester, 'Ville'), BorderSide(color: _colors.border, width: FlTokens.defaults.size.border));
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_contour(tester, 'Ville'), BorderSide.none);
  });

  testWidgets(
    'devrait épaissir l’anneau danger à la taille de l’anneau de focus quand le champ invalide prend le focus',
    (tester) async {
      await tester.pumpWidget(_app(const FlTextField(label: 'Ville', error: 'Inconnue', autofocus: true)));
      await tester.pumpAndSettle();
      expect(_editable(tester, 'Ville').focusNode.hasFocus, isTrue);
      expect(_outline(tester, 'Ville'), _colors.danger);
      expect(_focused(tester, 'Ville'), isTrue);
      expect(_frame('Ville'), isNot(_paintsRing(_colors.focusRing)), reason: 'le danger remplace l’accent');
      // L'anneau déborde du fond de size.focusRing.
      final box = tester.getRect(_box('Ville'));
      final ring = FlTokens.defaults.size.focusRing;
      expect(
        _frame('Ville'),
        _paintsRing(_colors.danger, inside: Offset(box.width / 2, -ring / 2), outside: Offset(box.width / 2, ring / 2)),
      );
    },
  );

  testWidgets("devrait s'annoncer requis et suivre le libellé d'un astérisque quand required est vrai", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville', required: true)));
    final label = tester.widget<RichText>(find.descendant(of: find.byType(FlLabel), matching: find.byType(RichText)));
    expect(label.text.toPlainText(includeSemanticsLabels: false), 'Ville *');
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.label, 'Ville');
    expect(node, isSemantics(hasRequiredState: true, isRequired: true));
    await tester.pumpWidget(_app(const FlTextField(label: 'Ville')));
    expect(tester.getSemantics(find.byType(EditableText)), isSemantics(hasRequiredState: false));
    semantics.dispose();
  });

  testWidgets('devrait prendre le focus et se lire sans changer le texte quand readOnly est vrai', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: 'Paris');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(FlTextField(label: 'Ville', controller: controller, readOnly: true)));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(_editable(tester, 'Ville').focusNode.hasFocus, isTrue);
    expect(tester.getSemantics(find.byType(EditableText)).flagsCollection.isReadOnly, isTrue);
    expect(_opacity(tester, 'Ville'), 1);
    tester.testTextInput.enterText('Lyon');
    await tester.pump();
    expect(controller.text, 'Paris');
    semantics.dispose();
  });

  testWidgets('devrait passer à la ligne dans une zone haute de deux contrôles quand multiline est vrai', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: 'Une table pour deux vendredi soir, près de la fenêtre si possible.',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(FlTextField(label: 'Message', controller: controller, multiline: true)));
    expect(tester.getSize(_box('Message')).height, FlTokens.defaults.size.controlComfortable * 2);
    final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
    final first = editable.getLocalRectForCaret(const TextPosition(offset: 0));
    final last = editable.getLocalRectForCaret(TextPosition(offset: controller.text.length));
    expect(last.top, greaterThan(first.bottom), reason: 'le texte tient sur plusieurs lignes');
    expect(_editable(tester, 'Message').keyboardType, TextInputType.multiline);
    final box = tester.getRect(_box('Message'));
    final text = tester.getRect(find.byType(EditableText));
    final line = FlTokens.defaults.typography.ios.textSm.lineHeight;
    expect(
      text.top - box.top,
      (FlTokens.defaults.size.controlComfortable - line) / 2,
      reason: 'la première ligne est là où serait une ligne seule',
    );
  });

  testWidgets('devrait montrer rows lignes entre les marges d’une ligne seule quand rows est donné', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FlTextField(label: 'Court', multiline: true, rows: 3),
            FlTextField(label: 'Long', multiline: true, rows: 6),
          ],
        ),
      ),
    );
    final line = FlTokens.defaults.typography.ios.textSm.lineHeight;
    final control = FlTokens.defaults.size.controlComfortable;
    expect(tester.getSize(_box('Court')).height, control + 2 * line);
    expect(tester.getSize(_box('Long')).height, control + 5 * line);
  });

  testWidgets('devrait couper la saisie à maxLength après les inputFormatters, et passer textCapitalization', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FlTextField(
          label: 'Âge',
          maxLength: 3,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textCapitalization: TextCapitalization.words,
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '1a2b34');
    expect(_editable(tester, 'Âge').controller.text, '123');
    expect(_editable(tester, 'Âge').textCapitalization, TextCapitalization.words);
  });

  testWidgets('devrait garder préfixe et suffixe dans une zone de texte, de part et d\'autre du texte', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlTextField(
          label: 'Message',
          multiline: true,
          prefix: SizedBox(key: Key('prefix'), width: 16, height: 16),
          suffix: SizedBox(key: Key('suffix'), width: 16, height: 16),
        ),
      ),
    );
    final text = tester.getRect(find.byType(EditableText));
    expect(tester.getRect(find.byKey(const Key('prefix'))).right, lessThanOrEqualTo(text.left));
    expect(tester.getRect(find.byKey(const Key('suffix'))).left, greaterThanOrEqualTo(text.right));
    expect(tester.getSize(_box('Message')).height, FlTokens.defaults.size.controlComfortable * 2);
  });

  testWidgets("devrait lire invalide et désactivé du FlFieldScope, sauf quand l'entrée les dit elle-même", (
    tester,
  ) async {
    Widget input({bool? invalid, bool? disabled}) => FlFieldScope(
      invalid: true,
      disabled: true,
      child: FlInput(label: 'Code', invalid: invalid, disabled: disabled),
    );
    FlInputFrame frame() => tester.widget<FlInputFrame>(find.byType(FlInputFrame));
    double opacity() => _paintOpacity(tester, find.byType(EditableText));

    await tester.pumpWidget(_app(input()));
    expect(frame().outline, _colors.danger);
    expect(opacity(), closeTo(FlTokens.defaults.size.disabledOpacity, 1 / 255));
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.canRequestFocus, isFalse);

    await tester.pumpWidget(_app(input(invalid: false, disabled: false)));
    expect(frame().outline, isNull);
    expect(opacity(), 1);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.canRequestFocus, isTrue);
  });

  testWidgets('devrait garder la saisie et le focus quand un suffixe apparaît à la première lettre', (tester) async {
    await tester.pumpWidget(_app(_SuffixOnText()));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pump();
    expect(find.byKey(_SuffixOnText.suffix), findsOneWidget);
    expect(_editable(tester, 'Ville').controller.text, 'a');
    expect(_editable(tester, 'Ville').focusNode.hasFocus, isTrue);
  });

  testWidgets(
    'devrait se mesurer par intrinsèques, avec ou sans affixe, sous IntrinsicHeight et dans une ligne de liste',
    (tester) async {
      for (final suffix in [null, const Text('€')]) {
        final reason = suffix == null ? 'sans affixe' : 'avec affixe';
        await tester.pumpWidget(
          _app(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: FlTextField(label: 'Montant', suffix: suffix),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: reason);
        await tester.pumpWidget(
          _app(
            FlListRow(
              title: 'Montant',
              leading: SizedBox(
                width: 120,
                child: FlInput(label: 'Code', placeholder: '0000', variant: FlInputVariant.secondary),
              ),
              trailing: SizedBox(
                width: 120,
                child: FlTextField(label: 'Montant', suffix: suffix),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$reason, ligne de liste');
      }
    },
  );

  testWidgets(
    "devrait couper le bouton d'un suffixe, au toucher, au clavier et au lecteur d'écran, quand enabled est faux",
    (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          FlTextField(
            label: 'Mot de passe',
            enabled: false,
            suffix: FlButton.icon(
              label: 'Montrer',
              icon: const SizedBox.square(dimension: 16),
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FlButton), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 0);
      expect(find.bySemanticsLabel('Montrer'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('devrait passer la vérification du contraste avec des champs vides et compacts sous une vraie police', (
    tester,
  ) async {
    final roboto = File('${_flutterRoot().path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    await (FontLoader('SystemProbe')..addFont(Future.value(ByteData.sublistView(roboto.readAsBytesSync())))).load();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'SystemProbe'),
            child: FlScope(
              tokens: tortureB,
              density: FlDensity.compact,
              brightness: Brightness.dark,
              platform: TargetPlatform.iOS,
              child: Builder(
                builder: (context) => ColoredBox(
                  color: FlScope.of(context).colors.surface,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        FlTextField(label: 'Email'),
                        FlTextField(label: 'Password', obscureText: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('devrait écrire un identifiant de gauche à droite, préfixe au début, libellé à droite en arabe', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'camille.martin');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        FlTextField(
          label: 'اسم المستخدم',
          controller: controller,
          prefix: const Text('@'),
          textDirection: TextDirection.ltr,
        ),
        direction: TextDirection.rtl,
      ),
    );
    final field = tester.getRect(find.byType(FlTextField));
    final label = tester.getRect(find.text('اسم المستخدم'));
    final at = tester.getRect(find.text('@'));
    final input = tester.getRect(find.byType(EditableText));
    expect(field.right - label.right, lessThan(1), reason: 'le libellé suit la page');
    expect(at.right, lessThanOrEqualTo(input.left + 1), reason: 'le préfixe précède le texte, à gauche');
    expect(Directionality.of(tester.element(find.byType(EditableText))), TextDirection.ltr);

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
    final start = editable.getLocalRectForCaret(const TextPosition(offset: 0));
    final end = editable.getLocalRectForCaret(const TextPosition(offset: 14));
    expect(end.left, greaterThan(start.left), reason: 'le curseur avance vers la droite');
    final boxes = editable.getBoxesForSelection(controller.selection);
    expect(boxes.single.left, closeTo(start.left, 1), reason: 'la sélection part du début du texte, à gauche');
  });

  testWidgets('devrait garder l’entrée dans le sens de la page sans textDirection', (tester) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Nom'), direction: TextDirection.rtl));
    expect(Directionality.of(tester.element(find.byType(EditableText))), TextDirection.rtl);
  });
  group('révélation du mot de passe', () {
    Widget password({bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: _app(
        FlTextField(
          label: 'Mot de passe',
          controller: TextEditingController(text: 'abc'),
          obscureText: true,
          showLabel: 'Afficher',
          hideLabel: 'Masquer',
        ),
      ),
    );
    Color textColor(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).style.color!;
    Finder dots() => find.text('\u2022\u2022\u2022');

    testWidgets('devrait fondre les points dans les lettres quand on affiche le mot de passe', (tester) async {
      await tester.pumpWidget(password());
      await tester.tap(find.text('Afficher'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isFalse);
      expect(textColor(tester).a, inExclusiveRange(0, 1), reason: 'the letters fade in');
      final veil = tester.widget<Text>(dots());
      expect(veil.style!.color!.a, inExclusiveRange(0, 1), reason: 'the dots fade out');
      await tester.pumpAndSettle();
      expect(dots(), findsNothing);
      expect(textColor(tester), _colors.onSurface);
      await tester.tap(find.text('Masquer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final letters = find.byWidgetPredicate((widget) => widget is Text && widget.data == 'abc');
      expect(letters, findsOneWidget, reason: 'the letters fade out over the dots');
      await tester.pumpAndSettle();
      expect(letters, findsNothing);
    });

    testWidgets('devrait afficher le mot de passe d’un coup sous mouvement réduit', (tester) async {
      await tester.pumpWidget(password(reduced: true));
      await tester.tap(find.text('Afficher'));
      await tester.pump();
      expect(dots(), findsNothing);
      expect(textColor(tester), _colors.onSurface);
    });
  });
}

/// Un champ dont le suffixe n'apparaît qu'avec du texte, comme un bouton
/// d'effacement ou une roue de validation.
class _SuffixOnText extends StatefulWidget {
  static const suffix = Key('suffix');

  @override
  State<_SuffixOnText> createState() => _SuffixOnTextState();
}

class _SuffixOnTextState extends State<_SuffixOnText> {
  var _empty = true;

  @override
  Widget build(BuildContext context) => FlTextField(
    label: 'Ville',
    suffix: _empty ? null : const SizedBox(key: _SuffixOnText.suffix, width: 16, height: 16),
    onChanged: (text) => setState(() => _empty = text.isEmpty),
  );
}

/// Le SDK qui fait tourner les tests : il porte Roboto dans ses
/// `material_fonts`, sur toutes les plateformes.
Directory _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('SDK Flutter introuvable depuis ${Platform.resolvedExecutable}');
}
