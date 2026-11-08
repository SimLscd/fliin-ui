import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/keyboard_highlight.dart';
import 'support/runs.dart';
import 'torture/themes.dart';

typedef _Line = ({String fr, String ar, Widget Function(String label) control});

/// Une colonne de lignes « libellé, contrôle », comme dans des réglages. Le
/// harnais n'a pas de `WidgetsApp` : les localisations que `RawRadio` lit
/// sur iOS viennent d'ici. `Localizations` impose le sens de ses
/// localisations, toujours LTR par défaut : celui de la variante est remis
/// dessous.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.rtl, required this.lines});

  final bool rtl;
  final List<_Line> lines;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return Localizations(
      locale: Locale(rtl ? 'ar' : 'en'),
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Directionality(
        textDirection: Directionality.of(context),
        child: ColoredBox(
          color: theme.colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(theme.space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.sm,
              children: [
                for (final line in lines)
                  Row(
                    spacing: theme.space.md,
                    children: [
                      Expanded(
                        child: Text(
                          rtl ? line.ar : line.fr,
                          style: theme.typography.resolve(FlTextRole.body).copyWith(color: theme.colors.onSurface),
                          strutStyle: theme.typography.strut(
                            FlTextRole.body,
                            inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                          ),
                        ),
                      ),
                      line.control(rtl ? line.ar : line.fr),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _noop(Object? _) {}

/// Allumé, éteint, désactivé dans les deux états, et focalisé au clavier.
final List<_Line> _switches = [
  (fr: 'Wi-Fi', ar: 'واي فاي', control: (label) => FlSwitch(value: true, label: label, onChanged: _noop)),
  (fr: 'Bluetooth', ar: 'بلوتوث', control: (label) => FlSwitch(value: false, label: label, onChanged: _noop)),
  (fr: 'Airplane mode', ar: 'وضع الطيران', control: (label) => FlSwitch(value: true, label: label, onChanged: null)),
  (
    fr: 'Personal hotspot',
    ar: 'مشاركة الاتصال',
    control: (label) => FlSwitch(value: false, label: label, onChanged: null),
  ),
  (
    fr: 'Notifications',
    ar: 'الإشعارات',
    control: (label) => FlSwitch(value: false, label: label, onChanged: _noop, autofocus: true),
  ),
];

/// Coché, décoché, mixte, désactivé coché, invalide, et focalisé au clavier.
final List<_Line> _checkboxes = [
  (
    fr: 'Terms accepted',
    ar: 'قبول الشروط',
    control: (label) => FlCheckbox(value: true, label: label, onChanged: _noop),
  ),
  (
    fr: 'Newsletter',
    ar: 'النشرة الإخبارية',
    control: (label) => FlCheckbox(value: false, label: label, onChanged: _noop),
  ),
  (
    fr: 'Select all',
    ar: 'تحديد الكل',
    control: (label) => FlCheckbox(value: null, tristate: true, label: label, onChanged: _noop),
  ),
  (fr: 'Required', ar: 'إلزامي', control: (label) => FlCheckbox(value: true, label: label, onChanged: null)),
  (
    fr: 'Terms declined',
    ar: 'الشروط مرفوضة',
    control: (label) => FlCheckbox(value: false, invalid: true, label: label, onChanged: _noop),
  ),
  (
    fr: 'Remember me',
    ar: 'تذكرني',
    control: (label) => FlCheckbox(value: false, label: label, onChanged: _noop, autofocus: true),
  ),
];

enum _Delivery { standard, express, pickup, locker }

/// Un groupe de HeroUI (choisie et focalisée, non choisie, désactivée), puis
/// un radio seul désactivé, posé à côté de son texte.
Widget _radios({required bool rtl}) => _Showcase(
  rtl: rtl,
  lines: [
    (
      fr: 'Shipping',
      ar: 'التوصيل',
      control: (_) => SizedBox(
        width: 220,
        child: FlRadioGroup<_Delivery>(
          groupValue: _Delivery.express,
          onChanged: _noop,
          children: [
            FlRadioGroupItem(value: _Delivery.standard, label: rtl ? 'عادي' : 'Standard'),
            FlRadioGroupItem(value: _Delivery.express, label: rtl ? 'سريع' : 'Express', autofocus: true),
            FlRadioGroupItem(value: _Delivery.pickup, label: rtl ? 'الاستلام من المتجر' : 'Pickup', disabled: true),
          ],
        ),
      ),
    ),
    (
      fr: 'Parcel locker (unavailable)',
      ar: 'خزانة (غير متاحة)',
      control: (label) => FlRadio(value: _Delivery.locker, label: label, enabled: false),
    ),
  ],
);

final Map<String, Widget Function({required bool rtl})> _items = {
  'switch': ({required rtl}) => _Showcase(rtl: rtl, lines: _switches),
  'checkbox': ({required rtl}) => _Showcase(rtl: rtl, lines: _checkboxes),
  'radio': _radios,
};

String _out(String item, FlTestTheme theme) => 'build/fliin/verify/$item/${theme.id}';

String _goldens(String item, FlTestTheme theme) => 'test/goldens/$item/${theme.id}';

void main() {
  setUpAll(loadTortureFonts);
  final runs = FlRuns();

  for (final MapEntry(key: item, value: showcase) in _items.entries) {
    for (final theme in flTestThemes) {
      fliinVerify(
        item: item,
        version: '0.1.0',
        contrastExceptions: allowancesOf(theme.tokens),
        outDir: _out(item, theme),
        goldens: macOSGoldens(_goldens(item, theme), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
        onReport: (report) => runs.keep(_out(item, theme), report),
        logicalSize: const Size(390, 1000),
        entry: (context, variant) => FlScope(
          tokens: theme.tokens,
          density: theme.density,
          brightness: variant.brightness,
          platform: variant.platform,
          child: KeyboardHighlight(child: showcase(rtl: variant.dir == TextDirection.rtl)),
        ),
      );
    }

    for (final theme in flTestThemes) {
      test(
        'devrait passer les guidelines a11y et le layout sur les 16 variantes de $item sous le thème ${theme.id}',
        () {
          expect(runs.report(_out(item, theme))['summary'], ['16/16 variants pass']);
          for (final variant in runs.variants(_out(item, theme))) {
            expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
            expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
          }
        },
      );

      test('devrait rendre chaque variante de $item au pixel près de son golden macOS sous le thème ${theme.id}', () {
        final drifted = {
          for (final variant in runs.variants(_out(item, theme)))
            if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
              variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
        };
        expect(
          drifted,
          isEmpty,
          reason:
              'références ${_goldens(item, theme)}, produites sous macOS 27.2 arm64 (ADR 0005), '
              'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
              'flutter test --update-goldens test/toggles_verify_test.dart',
        );
      }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
    }
  }
}
