import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/runs.dart';
import 'torture/themes.dart';

String _out(FlTestTheme theme, [String item = 'text_field']) => 'build/fliin/verify/$item/${theme.id}';

String _goldens(FlTestTheme theme, [String item = 'text_field']) => 'test/goldens/$item/${theme.id}';

/// Les libellés de la barre en arabe, que `GlobalWidgetsLocalizations` donne
/// dans une app : le registre ne dépend pas de `flutter_localizations`.
class _ArabicLocalizations extends DefaultWidgetsLocalizations {
  const _ArabicLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;

  @override
  String get cutButtonLabel => 'قص';

  @override
  String get copyButtonLabel => 'نسخ';

  @override
  String get pasteButtonLabel => 'لصق';

  @override
  String get selectAllButtonLabel => 'تحديد الكل';

  @override
  String get lookUpButtonLabel => 'بحث عن';

  @override
  String get searchWebButtonLabel => 'البحث على الويب';

  @override
  String get shareButtonLabel => 'مشاركة';
}

class _ArabicDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _ArabicDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<WidgetsLocalizations> load(Locale locale) => SynchronousFuture(const _ArabicLocalizations());

  @override
  bool shouldReload(_ArabicDelegate old) => false;
}

/// Un champ en haut de l'écran dont un mot est sélectionné et la barre ouverte, par l'API de
/// `EditableTextState` après le premier frame, comme le ferait un appui long ;
/// le presse-papiers est vide, donc pas de « Coller ».
class _Selection extends StatefulWidget {
  const _Selection({required this.rtl});

  final bool rtl;

  @override
  State<_Selection> createState() => _SelectionState();
}

class _SelectionState extends State<_Selection> {
  @override
  void initState() {
    super.initState();
    // L'autofocus prend effet après le premier frame : la sélection attend le second.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        final field = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>();
        if (field == null) return;
        final (text, word) = widget.rtl ? ('موعدنا غدا عند الظهر', 'غدا') : ('Appointment tomorrow at noon', 'tomorrow');
        final start = text.indexOf(word);
        field
          ..userUpdateTextEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection(baseOffset: start, extentOffset: start + word.length),
            ),
            SelectionChangedCause.longPress,
          )
          ..showToolbar();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return Localizations(
      locale: Locale(widget.rtl ? 'ar' : 'en'),
      delegates: [if (widget.rtl) const _ArabicDelegate() else DefaultWidgetsLocalizations.delegate],
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => ColoredBox(
              color: theme.colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  // En haut : la barre se retourne sous le champ et laisse son libellé lisible.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [FlTextField(label: widget.rtl ? 'الموعد' : 'Appointment', autofocus: true)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Showcase extends StatefulWidget {
  const _Showcase({required this.rtl});

  final bool rtl;

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase> {
  late final _amount = TextEditingController(text: '42');
  late final _password = TextEditingController(text: 'secret');
  late final _city = TextEditingController(text: _t('Paris', 'باريس'));

  String _t(String fr, String ar) => widget.rtl ? ar : fr;

  @override
  void dispose() {
    _amount.dispose();
    _password.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => ColoredBox(
            color: theme.colors.surface,
            child: Padding(
              padding: EdgeInsetsDirectional.all(theme.space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.lg,
                children: [
                  FlTextField(
                    label: _t('Email', 'البريد الإلكتروني'),
                    placeholder: _t('name@example.com', 'name@example.com'),
                    helper: _t('We won’t share it.', 'لن نشاركه مع أحد.'),
                    prefix: const Text('@'),
                  ),
                  FlTextField(
                    label: _t('Amount', 'المبلغ'),
                    controller: _amount,
                    autofocus: true,
                    suffix: const Text('€'),
                  ),
                  FlTextField(
                    label: _t('Password', 'كلمة المرور'),
                    controller: _password,
                    obscureText: true,
                    error: _t('Too short: at least 8 characters.', 'قصيرة جدًا: 8 أحرف على الأقل.'),
                  ),
                  FlTextField(label: _t('City', 'المدينة'), controller: _city, enabled: false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void main() {
  setUpAll(loadTortureFonts);
  final runs = FlRuns();

  for (final theme in flTestThemes) {
    fliinVerify(
      item: 'text_field',
      version: '0.1.0',
      contrastExceptions: allowancesOf(theme.tokens),
      outDir: _out(theme),
      goldens: macOSGoldens(_goldens(theme), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(_out(theme), report),
      logicalSize: const Size(390, 1040),
      entry: (context, variant) => FlScope(
        tokens: theme.tokens,
        density: theme.density,
        brightness: variant.brightness,
        platform: variant.platform,
        child: _Showcase(rtl: variant.dir == TextDirection.rtl),
      ),
    );
  }

  for (final theme in flTestThemes) {
    fliinVerify(
      item: 'text_selection',
      version: '0.1.0',
      contrastExceptions: allowancesOf(theme.tokens),
      outDir: _out(theme, 'text_selection'),
      goldens: macOSGoldens(_goldens(theme, 'text_selection'), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(_out(theme, 'text_selection'), report),
      logicalSize: const Size(390, 600),
      settle: const Duration(milliseconds: 300),
      entry: (context, variant) => FlScope(
        tokens: theme.tokens,
        density: theme.density,
        brightness: variant.brightness,
        platform: variant.platform,
        child: _Selection(rtl: variant.dir == TextDirection.rtl),
      ),
    );
  }

  for (final (item, name) in [('text_field', 'du champ'), ('text_selection', 'de la barre de sélection ouverte')]) {
    for (final theme in flTestThemes) {
      test('devrait passer les guidelines a11y et le layout sur les 16 variantes $name sous le thème ${theme.id}', () {
        expect(runs.report(_out(theme, item))['summary'], ['16/16 variants pass']);
        for (final variant in runs.variants(_out(theme, item))) {
          expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
          expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
        }
      });

      test('devrait rendre chaque variante $name au pixel près de son golden macOS sous le thème ${theme.id}', () {
        final drifted = {
          for (final variant in runs.variants(_out(theme, item)))
            if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
              variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
        };
        expect(
          drifted,
          isEmpty,
          reason:
              'références ${_goldens(theme, item)}, produites sous macOS 27.2 arm64 (ADR 0005), '
              'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
              'flutter test --update-goldens test/text_field_verify_test.dart',
        );
      }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
    }
  }
}
