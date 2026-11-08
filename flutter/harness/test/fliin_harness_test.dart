import 'dart:io';
import 'dart:ui' as ui;

import 'package:fliin_harness/fliin_harness.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _trapOut = 'build/fliin/verify/trap';
const _soundOut = 'build/fliin/verify/sound';
const _target44Out = 'build/fliin/verify/target44';
const _referenceOut = 'build/fliin/verify/reference';
const _sameOut = 'build/fliin/verify/same';
const _changedOut = 'build/fliin/verify/changed';
const _orphanOut = 'build/fliin/verify/orphan';
const _settledOut = 'build/fliin/verify/settled';
const _unsettledOut = 'build/fliin/verify/unsettled';
const _phoneOut = 'build/fliin/verify/phone';
const _keptOut = 'build/fliin/verify/kept';
const _ink = Color(0xFF000000);
const _paper = Color(0xFFFFFFFF);

/// Les rapports de cette exécution, par dossier de sortie. Un test qui lit un
/// rapport absent échoue : il ne relit jamais celui d'une exécution passée.
final _reports = <String, Map<String, Object?>>{};

void _keep(String outDir, Map<String, Object?> report) => _reports[outDir] = report;

Map<String, Object?> _report(String outDir) {
  final report = _reports[outDir];
  if (report == null) fail('$outDir : aucun rendu dans cette exécution');
  return report;
}

List<Map<String, Object?>> _variants(Map<String, Object?> report) =>
    (report['variants']! as List<Object?>).cast<Map<String, Object?>>();

void main() {
  fliinVerify(
    item: 'trap',
    version: '0.0.0',
    outDir: _trapOut,
    onReport: (report) => _keep(_trapOut, report),
    entry: (context, variant) => const ColoredBox(
      color: _paper,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Row(
          children: [
            SizedBox(width: 240),
            Text('Paramètres', style: TextStyle(color: _ink, fontSize: 16)),
          ],
        ),
      ),
    ),
  );

  fliinVerify(
    item: 'sound',
    version: '0.0.0',
    outDir: _soundOut,
    onReport: (report) => _keep(_soundOut, report),
    entry: (context, variant) => const ColoredBox(
      color: _paper,
      child: Center(
        child: Text('Bonjour', style: TextStyle(color: _ink, fontSize: 16)),
      ),
    ),
  );

  fliinVerify(
    item: 'target44',
    version: '0.0.0',
    outDir: _target44Out,
    onReport: (report) => _keep(_target44Out, report),
    entry: (context, variant) => ColoredBox(
      color: _paper,
      child: Center(
        child: Semantics(
          container: true,
          button: true,
          label: 'Info',
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox.square(dimension: 44, child: ColoredBox(color: _ink)),
          ),
        ),
      ),
    ),
  );

  Widget greeting(Color ink) => ColoredBox(
    color: _paper,
    child: Center(
      child: Text('Bonjour', style: TextStyle(color: ink, fontSize: 16)),
    ),
  );

  fliinVerify(
    item: 'reference',
    version: '0.0.0',
    outDir: _referenceOut,
    onReport: (report) => _keep(_referenceOut, report),
    entry: (context, variant) => greeting(_ink),
  );
  fliinVerify(
    item: 'same',
    version: '0.0.0',
    outDir: _sameOut,
    onReport: (report) => _keep(_sameOut, report),
    goldens: _referenceOut,
    entry: (context, variant) => greeting(_ink),
  );
  fliinVerify(
    item: 'changed',
    version: '0.0.0',
    outDir: _changedOut,
    onReport: (report) => _keep(_changedOut, report),
    goldens: _referenceOut,
    entry: (context, variant) => greeting(const Color(0xFF8B0000)),
  );

  /// Le texte apparaît en fondu de 200 ms dès le montage.
  Widget fadingGreeting() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 200),
    builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
    child: greeting(_ink),
  );
  fliinVerify(
    item: 'settled',
    version: '0.0.0',
    outDir: _settledOut,
    onReport: (report) => _keep(_settledOut, report),
    goldens: _referenceOut,
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => fadingGreeting(),
  );
  fliinVerify(
    item: 'unsettled',
    version: '0.0.0',
    outDir: _unsettledOut,
    onReport: (report) => _keep(_unsettledOut, report),
    goldens: _referenceOut,
    entry: (context, variant) => fadingGreeting(),
  );
  fliinVerify(
    item: 'phone',
    version: '0.0.0',
    outDir: _phoneOut,
    onReport: (report) => _keep(_phoneOut, report),
    logicalSize: const Size(390, 844),
    platformSizes: const {TargetPlatform.android: Size(412, 915)},
    variants: [
      for (final v in fliinMatrix)
        if (v.scale == 1 && v.dir == TextDirection.ltr && v.brightness == Brightness.light) v,
    ],
    entry: (context, variant) =>
        Text('${MediaQuery.sizeOf(context)}', style: const TextStyle(color: _ink, fontSize: 16)),
  );
  fliinVerify(
    item: 'orphan',
    version: '0.0.0',
    outDir: _orphanOut,
    onReport: (report) => _keep(_orphanOut, report),
    goldens: 'build/fliin/verify/nowhere',
    entry: (context, variant) => greeting(_ink),
  );

  // Rendu deux fois dans le même dossier : entre les deux, chaque image est
  // datée de 2001 et la première est abîmée.
  final keptVariants = [
    for (final v in fliinMatrix)
      if (v.scale == 1 && v.dir == TextDirection.ltr) v,
  ];
  final past = DateTime.utc(2001);
  late List<File> keptPngs;
  late List<int> damagedBytes;
  fliinVerify(
    item: 'kept',
    version: '0.0.0',
    outDir: _keptOut,
    variants: keptVariants,
    entry: (context, variant) => greeting(_ink),
  );
  group('rendu relancé', () {
    setUpAll(() {
      keptPngs = [for (final v in keptVariants) File('$_keptOut/${v.id}.png'), File('$_keptOut/overview.png')];
      for (final png in keptPngs) {
        png.setLastModifiedSync(past);
      }
      damagedBytes = keptPngs.first.readAsBytesSync();
      keptPngs.first
        ..writeAsBytesSync([...damagedBytes.reversed])
        ..setLastModifiedSync(past);
    });
    fliinVerify(
      item: 'kept',
      version: '0.0.0',
      outDir: _keptOut,
      onReport: (report) => _keep(_keptOut, report),
      variants: keptVariants,
      entry: (context, variant) => greeting(_ink),
    );
  });

  test('devrait mesurer un écart nul au golden quand le rendu est identique à la référence', () {
    _report(_referenceOut);
    for (final variant in _variants(_report(_sameOut))) {
      expect(variant['golden'], {
        'reference': '$_referenceOut/${variant['id']}.png',
        'diffPct': 0.0,
        'informational': true,
      });
    }
  });

  test("devrait mesurer l'écart au golden sans faire échouer la variante quand le rendu change", () {
    for (final variant in _variants(_report(_changedOut))) {
      final golden = variant['golden']! as Map<String, Object?>;
      expect(golden['diffPct'], allOf(greaterThan(0), lessThan(100)), reason: '${variant['id']}');
      expect(variant['status'], 'pass', reason: '${variant['id']}');
    }
  });

  test('devrait rendre une entrée animée à son terme quand settle couvre son animation', () {
    for (final variant in _variants(_report(_settledOut))) {
      expect((variant['golden']! as Map<String, Object?>)['diffPct'], 0.0, reason: '${variant['id']}');
    }
    for (final variant in _variants(_report(_unsettledOut))) {
      expect((variant['golden']! as Map<String, Object?>)['diffPct'], greaterThan(0), reason: '${variant['id']}');
    }
  });

  test("devrait laisser diffPct nul quand la référence n'existe pas", () {
    for (final variant in _variants(_report(_orphanOut))) {
      expect((variant['golden']! as Map<String, Object?>)['diffPct'], isNull);
    }
    expect(_variants(_report(_soundOut)).map((v) => v['golden']), everyElement(isNull));
  });

  test('devrait signaler le débordement avec le widget et sa source quand un Row déborde à 2,0×', () {
    final variants = _variants(_report(_trapOut));
    expect(variants, hasLength(16));
    for (final variant in variants) {
      final errors = (variant['layoutErrors']! as List<Object?>).cast<Map<String, Object?>>();
      if ((variant['id']! as String).contains('.2.0.')) {
        expect(variant['status'], 'fail', reason: '${variant['id']}');
        expect(variant['a11yIncomplete'], isTrue, reason: '${variant['id']}');
        expect(errors.single['message'], contains('overflowed'));
        expect(errors.single['widget'], 'Row');
        expect(errors.single['source'], matches(RegExp(r'^test/fliin_harness_test\.dart:\d+:\d+$')));
      } else {
        expect(errors, isEmpty, reason: '${variant['id']}');
      }
    }
    expect(_report(_trapOut)['summary'], contains('8/16 variants pass'));
  });

  test('devrait faire passer les 16 variantes quand le widget est sain', () {
    final report = _report(_soundOut);
    expect(report['summary'], ['16/16 variants pass']);
    expect(_variants(report).map((v) => v['status']), everyElement('pass'));
  });

  test('devrait accepter une cible de 44×44 sur iOS et la refuser sur Android quand elle est rendue', () {
    for (final variant in _variants(_report(_target44Out))) {
      final guidelines = (variant['a11y']! as List<Object?>).map((f) => (f! as Map<String, Object?>)['guideline']);
      if ((variant['id']! as String).startsWith('ios.')) {
        expect(variant['status'], 'pass', reason: '${variant['id']}');
      } else {
        expect(guidelines, ['androidTapTargetGuideline'], reason: '${variant['id']}');
      }
    }
  });

  test('devrait écrire le rapport au format DESIGN §4.5 quand la matrice est rendue', () async {
    final report = _report(_soundOut);
    expect(
      report.keys,
      containsAll(['item', 'version', 'flutter', 'host', 'analyze', 'variants', 'summary', 'elapsedMs']),
    );
    expect(report['item'], 'sound');
    expect(report['analyze'], {'diagnostics': <Object?>[]});
    expect(report['warnings'], isEmpty);
    final variants = _variants(report);
    expect(variants.map((v) => v['id']), fliinMatrix.map((v) => v.id));
    for (final variant in variants) {
      expect(
        variant.keys,
        unorderedEquals([
          'id',
          'png',
          'status',
          'layoutErrors',
          'a11y',
          'golden',
          'fontFallback',
          'a11yIncomplete',
          'warnings',
        ]),
      );
      expect(variant['warnings'], isEmpty, reason: 'aucune exception de contraste déclarée');
      expect(File(variant['png']! as String).existsSync(), isTrue);
    }
    final codec = await ui.instantiateImageCodec(File('$_soundOut/overview.png').readAsBytesSync());
    final overview = (await codec.getNextFrame()).image;
    expect((overview.width, overview.height), (4 * 390, 4 * 300));
  });

  test('devrait rendre chaque plateforme à sa taille quand platformSizes en donne une', () async {
    Future<(int, int)> size(String png) async {
      final codec = await ui.instantiateImageCodec(File(png).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      return (image.width, image.height);
    }

    final variants = _variants(_report(_phoneOut));
    expect(variants.map((v) => v['id']), ['ios.light.1.0.ltr', 'android.light.1.0.ltr']);
    expect(await size(variants[0]['png']! as String), (2 * 390, 2 * 844));
    expect(await size(variants[1]['png']! as String), (2 * 412, 2 * 915));
    expect(await size('$_phoneOut/overview.png'), (4 * 412, 915));
  });

  test(
    'devrait garder une image identique sans la réécrire et remplacer une image qui diffère quand on rend de nouveau',
    () {
      _report(_keptOut);
      expect(keptPngs.first.readAsBytesSync(), damagedBytes, reason: 'image abîmée remplacée');
      expect([
        for (final png in keptPngs.skip(1))
          if (!png.lastModifiedSync().isAtSameMomentAs(past)) png.path,
      ], isEmpty);
    },
  );

  group('contraste mesuré sur la partie visible du texte', () {
    const page = Color(0xFFF2F2F2);
    const bar = Color(0xFFFFFFFF);
    const faint = Color(0xFFE6E6E6);

    /// Un défilant de 100 au-dessus d'une barre du bas de 100 ; le texte, une
    /// lettre sur toute la largeur, va de 70 à 110 : la barre coupe son quart
    /// bas, son centre reste visible.
    Future<void> scene(WidgetTester tester, {required Color ink, required bool cut}) async {
      tester.view.physicalSize = const Size(390, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: cut ? 100 : 120,
                child: ColoredBox(
                  color: page,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 70),
                        Text(
                          'a',
                          style: TextStyle(color: ink, fontSize: 14, height: 40 / 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(child: ColoredBox(color: bar)),
            ],
          ),
        ),
      );
    }

    testWidgets('devrait passer un texte lisible que la barre du bas coupe, que flutter_test mesurait sur la barre', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await scene(tester, ink: _ink, cut: true);
      expect((await textContrastGuideline.evaluate(tester)).passed, isFalse, reason: 'le défaut de mesure corrigé');
      expect((await flTextContrastGuideline.evaluate(tester)).passed, isTrue);
      semantics.dispose();
    });

    testWidgets(
      'devrait passer un texte entier dont la marge touche une découpe sur un demi-pixel, au-dessus du filet d\'une barre',
      (tester) async {
        // Le défilant s'arrête à 100,5 ; la rangée 100, à moitié dessous, porte
        // le filet de la barre, d'une seule couleur sur toute sa largeur.
        // Comptée dans la marge d'une ligne de texte pleine largeur (un titre
        // de section), elle passait pour la couleur du texte.
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(390, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const muted = Color(0xFF5E5E66);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 100.5,
                  child: ColoredBox(
                    color: page,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 77),
                          Text(
                            'Détail du prix',
                            style: TextStyle(color: muted, fontSize: 14, height: 20 / 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFD1D1D6))),
                const Expanded(child: ColoredBox(color: bar)),
              ],
            ),
          ),
        );
        final evaluation = await flTextContrastGuideline.evaluate(tester);
        expect(evaluation.passed, isTrue, reason: evaluation.reason);
        semantics.dispose();
      },
    );

    testWidgets('devrait refuser encore un texte trop pâle coupé à moitié, sur sa partie visible', (tester) async {
      final semantics = tester.ensureSemantics();
      await scene(tester, ink: faint, cut: true);
      final evaluation = await flTextContrastGuideline.evaluate(tester);
      expect(evaluation.passed, isFalse);
      expect(evaluation.reason, contains('Expected contrast ratio of at least 4.5'));
      semantics.dispose();
    });

    testWidgets('devrait refuser comme flutter_test un texte trop pâle que rien ne coupe', (tester) async {
      final semantics = tester.ensureSemantics();
      await scene(tester, ink: faint, cut: false);
      final ours = await flTextContrastGuideline.evaluate(tester);
      final theirs = await textContrastGuideline.evaluate(tester);
      expect(ours.passed, isFalse);
      expect(ours.reason, theirs.reason);
      semantics.dispose();
    });
  });

  group('texte coupé : couleur déclarée, et ce qui la recouvre (relecture D23)', () {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    const style = TextStyle(fontSize: 16, color: black);
    final veil = ColoredBox(color: white.withValues(alpha: 0.85));

    /// Une boîte de 300 × 200 découpée, sur [background], le texte [marked]
    /// à [top] (16 de haut) et [overlay], un frère peint par-dessus le bas
    /// sur 30.
    Future<Evaluation> scene(
      WidgetTester tester, {
      required Widget marked,
      required double top,
      Widget background = const ColoredBox(color: white),
      Widget? overlay,
      Widget Function(Widget box)? clip,
    }) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final box = SizedBox(
        width: 300,
        height: 200,
        child: Stack(
          children: [
            Positioned.fill(child: background),
            Positioned(top: top, left: 16, child: marked),
            if (overlay != null)
              Positioned(left: 0, right: 0, bottom: 0, height: 30, child: IgnorePointer(child: overlay)),
          ],
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: white,
            child: Align(
              alignment: Alignment.topLeft,
              child: clip == null ? ClipRect(child: box) : clip(box),
            ),
          ),
        ),
      );
      final evaluation = await flTextContrastGuideline.evaluate(tester);
      semantics.dispose();
      return evaluation;
    }

    // Coupé de 6 en bas, centre visible ; entier, à 2 du bord.
    const cut = 190.0;
    const near = 182.0;

    testWidgets('devrait passer du noir sur blanc coupé dont l\'encre remplit la part visible (B1)', (tester) async {
      expect(
        (await scene(
          tester,
          marked: const Text('Marque', style: style),
          top: cut,
        )).passed,
        isTrue,
      );
    });

    testWidgets('devrait refuser un texte entier voilé à 2 du bord, comme flutter_test (H1)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: const Text('Marque', style: style),
        top: near,
        overlay: veil,
      );
      expect(evaluation.reason, contains('found 1.41'));
    });

    testWidgets('devrait refuser un texte entier voilé à 2 du bord d\'un ClipRRect (H1)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: const Text('Marque', style: style),
        top: near,
        overlay: veil,
        clip: (box) => ClipRRect(borderRadius: BorderRadius.circular(12), child: box),
      );
      expect(evaluation.reason, contains('found 1.41'));
    });

    testWidgets('devrait refuser un texte coupé sous un voile frère (H2)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: const Text('Marque', style: style),
        top: cut,
        overlay: veil,
      );
      expect(evaluation.reason, contains('found 1.41'));
    });

    testWidgets('devrait refuser un texte coupé sous un dégradé frère, comme l\'ombre d\'un défilant (H2)', (
      tester,
    ) async {
      final gradient = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [white, white.withValues(alpha: 0)],
          ),
        ),
      );
      final evaluation = await scene(
        tester,
        marked: const Text('Marque', style: style),
        top: cut,
        overlay: gradient,
      );
      expect(evaluation.passed, isFalse);
    });

    testWidgets('devrait refuser un texte coupé sous une foregroundDecoration (H2)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: Container(
          foregroundDecoration: BoxDecoration(color: white.withValues(alpha: 0.85)),
          child: const Text('Marque', style: style),
        ),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.41'));
    });

    testWidgets('devrait refuser un texte coupé sous un foregroundPainter qui dessine (H2)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: CustomPaint(
          foregroundPainter: _Veil(white.withValues(alpha: 0.85)),
          child: const Text('Marque', style: style),
        ),
        top: cut,
      );
      expect(evaluation.passed, isFalse);
    });

    testWidgets('devrait refuser un texte coupé dont un morceau minoritaire est pâle', (tester) async {
      final evaluation = await scene(
        tester,
        marked: const Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: 'Marque longue et noire '),
              TextSpan(
                text: 'pâle',
                style: TextStyle(color: Color(0xFFE0E0E0)),
              ),
            ],
          ),
        ),
        top: cut,
      );
      expect(evaluation.passed, isFalse);
    });

    // Seconde relecture D23. Un gris foncé sur son propre fond gris, sur une
    // page blanche : 7,0:1 contre la page, 1,77:1 contre son fond. L'espace
    // entre les lettres laisse voir le fond entre les glyphes pleins de la
    // police de test, comme entre les traits d'une vraie police.
    const grey = Color(0xFF808080);
    const dim = TextStyle(fontSize: 16, color: Color(0xFF595959), letterSpacing: 24);

    /// Une liste de 300 × 200 défilée à [offset], qui découpe ses lignes.
    Future<Evaluation> list(WidgetTester tester, {required double offset, required Widget Function(int) item}) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: white,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 200,
                child: ListView(
                  controller: controller,
                  itemExtent: 40,
                  children: [for (var i = 0; i < 20; i++) Align(alignment: Alignment.centerLeft, child: item(i))],
                ),
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(offset);
      await tester.pump();
      final evaluation = await flTextContrastGuideline.evaluate(tester);
      semantics.dispose();
      return evaluation;
    }

    testWidgets('devrait refuser un texte coupé sur son surlignage, que la marge ne montre pas (CE1)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: Text('Marque', style: dim.copyWith(backgroundColor: grey)),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.77'));
    });

    testWidgets('devrait refuser un texte coupé sur un fond de style peint, que la marge ne montre pas (CE1)', (
      tester,
    ) async {
      final evaluation = await scene(
        tester,
        marked: Text('Marque', style: dim.copyWith(background: Paint()..color = grey)),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.77'));
    });

    testWidgets('devrait refuser un texte coupé sur une pastille serrée contre lui (CE1)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: const ColoredBox(
          color: grey,
          child: Text('Marque', style: dim),
        ),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.77'));
    });

    testWidgets('devrait refuser un texte coupé sur une bande découpée à sa hauteur, page blanche autour (CE1)', (
      tester,
    ) async {
      final evaluation = await scene(
        tester,
        background: const ColoredBox(
          color: white,
          child: ClipPath(
            clipper: _Band(cut, cut + 16),
            child: ColoredBox(color: grey),
          ),
        ),
        marked: const Text('Marque', style: dim),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.77'));
    });

    testWidgets('devrait refuser un texte coupé sur un dégradé à arrêt net au haut du texte (CE1)', (tester) async {
      final evaluation = await scene(
        tester,
        background: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [white, white, grey, grey],
              stops: [0, cut / 200, cut / 200, 1],
            ),
          ),
        ),
        marked: const Text('Marque', style: dim),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.77'));
    });

    testWidgets('devrait refuser une pastille serrée coupée au bas d\'une liste (CE1)', (tester) async {
      final evaluation = await list(
        tester,
        offset: 24,
        item: (i) => ColoredBox(
          color: grey,
          child: Text('Pastille $i', style: dim),
        ),
      );
      expect(evaluation.reason, contains('"Pastille 5"'));
    });

    testWidgets('devrait refuser un texte coupé peint à 0,2 par un Flow (CE2)', (tester) async {
      final evaluation = await scene(
        tester,
        marked: SizedBox(
          width: 120,
          height: 16,
          child: Flow(
            delegate: const _FadeFlow(0.2),
            children: const [Text('Marque', style: style)],
          ),
        ),
        top: cut,
      );
      expect(evaluation.reason, contains('found 1.62'));
    });

    for (final offset in [20.0, 25.0]) {
      testWidgets('devrait refuser une ligne coupée au bas d\'une roue qui la peint à 0,2, décalée de $offset (CE2)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final controller = FixedExtentScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: white,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: ListWheelScrollView(
                    controller: controller,
                    itemExtent: 40,
                    overAndUnderCenterOpacity: 0.2,
                    children: [for (var i = 0; i < 20; i++) Text('Ligne $i', style: style)],
                  ),
                ),
              ),
            ),
          ),
        );
        controller.jumpTo(offset);
        await tester.pump();
        final evaluation = await flTextContrastGuideline.evaluate(tester);
        semantics.dispose();
        expect(evaluation.reason, contains('"Ligne 3"'));
      });
    }

    testWidgets('devrait mesurer comme flutter_test un texte dont seule l\'interligne est coupée (CE3)', (
      tester,
    ) async {
      final evaluation = await scene(
        tester,
        marked: ColoredBox(
          color: grey,
          child: Text('Marque', style: dim.copyWith(height: 2)),
        ),
        top: 172,
      );
      expect(evaluation.reason, contains('found 3.95'));
    });

    testWidgets('devrait mesurer comme flutter_test une ligne de liste dont seule l\'interligne passe le bord (CE3)', (
      tester,
    ) async {
      final evaluation = await list(
        tester,
        offset: 35.5,
        item: (i) => ColoredBox(
          color: grey,
          child: Text('L$i', style: dim.copyWith(height: 2)),
        ),
      );
      expect(evaluation.reason, contains('"L5"'));
    });
  });

  test("devrait n'importer que dart:, flutter et flutter_test quand on lit le harnais", () {
    final source = File('lib/fliin_harness.dart').readAsStringSync();
    final uris = RegExp(
      r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(source).map((m) => m.group(1)!).toList();
    expect(uris, isNotEmpty);
    expect(uris.where((uri) => !RegExp(r'^(dart:|package:flutter/|package:flutter_test/)').hasMatch(uri)), isEmpty);
  });
}

class _Veil extends CustomPainter {
  _Veil(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, Paint()..color = color);

  @override
  bool shouldRepaint(_Veil old) => old.color != color;
}

class _Band extends CustomClipper<Path> {
  const _Band(this.top, this.bottom);

  final double top;
  final double bottom;

  @override
  Path getClip(Size size) => Path()..addRect(Rect.fromLTRB(0, top, size.width, bottom));

  @override
  bool shouldReclip(_Band old) => old.top != top || old.bottom != bottom;
}

class _FadeFlow extends FlowDelegate {
  const _FadeFlow(this.opacity);

  final double opacity;

  @override
  void paintChildren(FlowPaintingContext context) => context.paintChild(0, opacity: opacity);

  @override
  bool shouldRepaint(_FadeFlow old) => old.opacity != opacity;
}
