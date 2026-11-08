import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/alert/fl_alert.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/card/fl_card.dart';
import 'package:fliin_ui/components/section_header/fl_section_header.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presets/presets.g.dart';
import 'support/allowances.dart';
import 'support/keyboard_highlight.dart';
import 'support/runs.dart';
import 'support/showcase.dart';

/// Les préréglages de `presets/presets.json` (ADR 0016 §8), du plus anguleux
/// au plus rond, puis à empattements, puis titres à empattements sur le
/// texte système, puis deux de la version b : cartes à plat, traits moyens et
/// petit texte ; marque libre, menus teintés, grand texte et traits épais.
/// Chacun rendu en clair et en sombre par les 16 variantes du harnais.
final _presets = {
  'square': presetSquare,
  'round': presetRound,
  'serif': presetSerif,
  'editorial': presetEditorial,
  'outlined': presetOutlined,
  'large': presetLarge,
};

/// Quelques éléments qui lisent chacun des réglages : rayons (carte, champ,
/// alerte), forme du bouton, espacement, ombres, titres et texte.
Widget _board(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  return columnPage(context, [
    showcaseText(context, tr(rtl, 'Book a table', 'احجز طاولة'), role: FlTextRole.heading3),
    showcaseText(
      context,
      tr(rtl, 'Choose the time, we confirm right away.', 'اختر الوقت، وسنؤكد فورًا.'),
      role: FlTextRole.paragraphSm,
      color: theme.colors.onSurfaceMuted,
    ),
    FlCard(
      children: [
        FlCardBody(
          children: [
            FlCardTitle(tr(rtl, 'Tonight, 8 PM', 'الليلة، 8 مساءً')),
            FlCardDescription(tr(rtl, 'Two guests, on the terrace.', 'شخصان، في الشرفة.')),
          ],
        ),
      ],
    ),
    FlTextField(label: tr(rtl, 'Name', 'الاسم'), placeholder: tr(rtl, 'Camille Martin', 'كاميل مارتن')),
    FlSectionHeader(title: tr(rtl, 'Reminder', 'تذكير')),
    FlSwitch(value: true, label: tr(rtl, 'Remind me the day before', 'ذكّرني قبل يوم'), onChanged: (_) {}),
    FlAlert(
      status: FlAlertStatus.accent,
      title: tr(rtl, 'Table confirmed', 'تم تأكيد الطاولة'),
      description: tr(rtl, 'An email follows.', 'سيصلك بريد.'),
    ),
    FlButton(label: tr(rtl, 'Book', 'احجز'), onPressed: () {}),
    FlButton(label: tr(rtl, 'Later', 'لاحقًا'), variant: FlButtonVariant.secondary, onPressed: () {}),
    FlButton(label: tr(rtl, 'Edit', 'تعديل'), variant: FlButtonVariant.outline, onPressed: () {}),
  ]);
}

/// Roboto Slab, la police à empattements du préréglage `serif`, que le SDK
/// Flutter épinglé porte sous licence Apache 2.0 : rien n'est copié dans le
/// dépôt. Son absence fait échouer, sinon le texte retomberait sur la police
/// du harnais.
Future<void> _loadSerif() async {
  final family = presetSerif.typography.ios.headingFamily!;
  var dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
    if (dir.parent.path == dir.path) throw StateError('SDK Flutter introuvable');
    dir = dir.parent;
  }
  final file = File('${dir.path}/engine/src/flutter/testing/resources/RobotoSlab-VariableFont_wght.ttf');
  if (!file.existsSync()) throw StateError('$family introuvable : ${file.path}');
  await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())))).load();
}

void main() {
  String out(String name) => 'build/fliin/verify/presets/$name';
  String goldens(String name) => 'test/goldens/presets/$name';

  setUpAll(_loadSerif);
  final runs = FlRuns();

  for (final MapEntry(key: name, value: tokens) in _presets.entries) {
    fliinVerify(
      item: 'presets',
      version: '0.1.0',
      // Le préréglage editorial garde les couleurs de HeroUI exact, donc
      // ses exceptions déclarées ; les autres n'en ont aucune.
      contrastExceptions: allowancesOf(tokens),
      outDir: out(name),
      goldens: macOSGoldens(goldens(name), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(out(name), report),
      logicalSize: const Size(390, 1100),
      entry: (context, variant) => FlScope(
        tokens: tokens,
        brightness: variant.brightness,
        platform: variant.platform,
        child: KeyboardHighlight(
          child: Builder(builder: (context) => _board(context, rtl: variant.dir == TextDirection.rtl)),
        ),
      ),
    );
  }

  for (final name in _presets.keys) {
    test('devrait passer les guidelines a11y, contraste compris, sur les 16 variantes du préréglage $name', () {
      expect(runs.report(out(name))['summary'], ['16/16 variants pass']);
      for (final variant in runs.variants(out(name))) {
        expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
        expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
      }
    });

    test('devrait rendre chaque variante du préréglage $name au pixel près de son golden macOS', () {
      final drifted = {
        for (final variant in runs.variants(out(name)))
          if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
            variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
      };
      expect(
        drifted,
        isEmpty,
        reason:
            'références ${goldens(name)}, produites sous macOS 27.2 arm64 (ADR 0005), '
            'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
            'flutter test --update-goldens test/preset_verify_test.dart',
      );
    }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
  }

  test('devrait donner à chaque préréglage des goldens les réglages qu’il nomme', () {
    expect(presetSquare.shape.radiusCard, 0);
    expect(presetSquare.shape.button, FlButtonShape.square);
    expect(presetRound.shape.radiusCard, FlTokens.defaults.shape.radiusCard * 1.5);
    expect(presetRound.space.lg, FlTokens.defaults.space.lg * 1.25);
    expect(presetSerif.typography.ios.fontFamily, 'Roboto Slab');
    expect(presetSerif.typography.android.headingFamily, 'Roboto Slab');
    expect(presetEditorial.typography.ios.fontFamily, isNull);
    expect(presetEditorial.typography.ios.headingFamily, 'Roboto Slab');
    expect(presetOutlined.size.surfaceBorder, 1.5);
    expect(presetOutlined.size.border, 1.5);
    expect(presetOutlined.typography.ios.body.size, (FlTokens.defaults.typography.ios.body.size * 0.9).roundToDouble());
    expect(presetLarge.size.border, 2);
    expect(presetLarge.size.surfaceBorder, 0);
    expect(presetLarge.typography.ios.body.size, (FlTokens.defaults.typography.ios.body.size * 1.1).roundToDouble());
    expect(presetLarge.light.surfaceOverlay, isNot(presetLarge.light.surfaceRaised));
    for (final tokens in [presetSquare, presetRound, presetSerif, presetOutlined, presetLarge]) {
      expect(tokens.contrastExceptions, isEmpty);
    }
  });
}
