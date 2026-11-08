import 'dart:ui' as ui;

import 'package:fliin_ui/components/skeleton/fl_skeleton.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Key('frame');

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: FlScope(
    brightness: Brightness.light,
    child: Builder(
      builder: (context) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: RepaintBoundary(
            key: _frame,
            child: SizedBox(width: 100, height: 60, child: child),
          ),
        ),
      ),
    ),
  ),
);

/// La couleur au centre du cadre, en pixels logiques.
Future<Color> _center(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final at = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
    image.dispose();
    return data!.buffer.asUint8List(at, 4);
  }))!;
  return Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]);
}

double _boneOpacity(WidgetTester tester) => tester
    .widgetList<FadeTransition>(find.ancestor(of: find.byType(CustomPaint), matching: find.byType(FadeTransition)))
    .map((fade) => fade.opacity.value)
    .reduce((a, b) => a * b);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets('devrait prendre la taille de l’appelant et cacher le contenu quand il charge', (tester) async {
    await tester.pumpWidget(
      _app(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: FlSkeleton(label: 'Profil', width: 48, height: 12, child: Text('Ada')),
        ),
      ),
    );
    expect(tester.getSize(find.byType(CustomPaint).last), const Size(48, 12));
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('devrait prendre la largeur du parent quand l’appelant n’en donne pas', (tester) async {
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil', height: 12)));
    expect(tester.getSize(find.byType(CustomPaint).last).width, 100);
  });

  testWidgets('devrait montrer le contenu en fondu quand le chargement finit', (tester) async {
    await tester.pumpWidget(
      _app(const FlSkeleton(label: 'Profil', variant: FlSkeletonVariant.pulse, child: Text('Ada'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(
      _app(const FlSkeleton(label: 'Profil', loading: false, variant: FlSkeletonVariant.pulse, child: Text('Ada'))),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('Ada'), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Ada'), findsOneWidget);
    expect(find.descendant(of: find.byType(FlSkeleton), matching: find.byType(CustomPaint)), findsNothing);
  });

  testWidgets('devrait remplacer l’os sans fondu quand la variante est none', (tester) async {
    await tester.pumpWidget(
      _app(const FlSkeleton(label: 'Profil', variant: FlSkeletonVariant.none, child: Text('Ada'))),
    );
    await tester.pumpWidget(
      _app(const FlSkeleton(label: 'Profil', loading: false, variant: FlSkeletonVariant.none, child: Text('Ada'))),
    );
    await tester.pump();
    expect(find.descendant(of: find.byType(FlSkeleton), matching: find.byType(CustomPaint)), findsNothing);
  });

  testWidgets('devrait faire passer un reflet sur l’os quand la variante est shimmer', (tester) async {
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil')));
    // Un tour entier : le fondu d'entrée est fini et le reflet repart de
    // la gauche de l'os, hors de lui.
    await tester.pump(const Duration(milliseconds: 1500));
    final before = await _center(tester);
    // Le reflet, large comme l'os, va de -100 à 800 (la largeur de l'écran)
    // en 1 500 ms : centré sur l'os après 100 / 900 du tour.
    await tester.pump(const Duration(milliseconds: 167));
    final during = await _center(tester);
    expect(during.r, greaterThan(before.r + 5 / 255));
  });

  testWidgets('devrait faire passer le reflet de droite à gauche quand la lecture va de droite à gauche', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil'), direction: TextDirection.rtl));
    await tester.pump(const Duration(milliseconds: 1500));
    final before = await _center(tester);
    await tester.pump(const Duration(milliseconds: 167));
    expect(await _center(tester), before);
    // De 800 à -100 : centré sur l'os après 800 / 900 du tour.
    await tester.pump(const Duration(milliseconds: 1333 - 167));
    expect((await _center(tester)).r, greaterThan(before.r + 5 / 255));
  });

  testWidgets('devrait pulser entre 0,5 et 1 quand la variante est pulse', (tester) async {
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil', variant: FlSkeletonVariant.pulse)));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_boneOpacity(tester), closeTo(1, 1e-6));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_boneOpacity(tester), closeTo(0.5, 1e-6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_boneOpacity(tester), closeTo(0.75, 1e-6));
  });

  testWidgets('devrait rester immobile, sans reflet et à 0,5 en pulse, sous mouvement réduit', (tester) async {
    _reduceMotion(tester);
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil')));
    final still = await _center(tester);
    await tester.pump(const Duration(milliseconds: 167));
    expect(await _center(tester), still);
    expect(_boneOpacity(tester), 1);

    await tester.pumpWidget(
      _app(const FlSkeleton(key: Key('pulse'), label: 'Profil', variant: FlSkeletonVariant.pulse)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(_boneOpacity(tester), 0.5);
  });

  testWidgets('devrait s’annoncer comme un chargement nommé quand il charge, puis céder au contenu', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil', child: Text('Ada'))));
    expect(tester.getSemantics(find.bySemanticsLabel('Profil')).getSemanticsData().role, SemanticsRole.loadingSpinner);
    await tester.pumpWidget(_app(const FlSkeleton(label: 'Profil', loading: false, child: Text('Ada'))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Profil'), findsNothing);
    expect(find.bySemanticsLabel('Ada'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait prendre le chargement et la variante du groupe, sauf ceux que l’os donne', (tester) async {
    Widget group({required bool loading}) => _app(
      FlSkeletonGroup(
        label: 'Profil',
        loading: loading,
        variant: FlSkeletonVariant.none,
        child: const Column(
          children: [
            FlSkeleton.item(height: 8, child: Text('Ada')),
            FlSkeleton.item(height: 8, loading: true, child: Text('Lovelace')),
          ],
        ),
      ),
    );
    await tester.pumpWidget(group(loading: true));
    expect(find.text('Ada'), findsNothing);
    await tester.pumpWidget(group(loading: false));
    await tester.pump();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Lovelace'), findsNothing);
  });

  testWidgets('devrait s’annoncer une seule fois par le groupe quand il charge', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const FlSkeletonGroup(
          label: 'Profil',
          child: Column(children: [FlSkeleton.item(height: 8), FlSkeleton.item(height: 8)]),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Profil')).getSemanticsData().role, SemanticsRole.loadingSpinner);
    semantics.dispose();
  });

  testWidgets('devrait ne rien rendre quand le groupe n’est fait que pour le chargement et qu’il a fini', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FlSkeletonGroup(
          label: 'Profil',
          loading: false,
          skeletonOnly: true,
          child: FlSkeleton.item(height: 8, child: Text('Ada')),
        ),
      ),
    );
    expect(find.text('Ada'), findsNothing);
    expect(find.byType(FlSkeleton), findsNothing);
  });

  testWidgets(
    'devrait poser des lignes de 12 espacées de 8, la dernière à 60 %, et s’annoncer une fois avec son label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const FlSkeletonText(label: 'Article', child: Text('Ada'))));
      final bones = [
        for (final element in find.byType(FlSkeleton).evaluate()) tester.getRect(find.byWidget(element.widget)),
      ];
      expect(bones, hasLength(3));
      expect([for (final bone in bones) bone.height], [12, 12, 12]);
      expect([for (final bone in bones) bone.width], [100, 100, 60]);
      expect(bones[1].top - bones[0].bottom, 8);
      expect(find.text('Ada'), findsNothing);
      expect(find.bySemanticsLabel('Article'), findsOneWidget);
      await tester.pumpWidget(_app(const FlSkeletonText(label: 'Article', loading: false, child: Text('Ada'))));
      expect(find.text('Ada'), findsOneWidget);
      expect(find.byType(FlSkeleton), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('devrait suivre le chargement et l’animation du groupe quand il n’a pas de label', (tester) async {
    Widget group({required bool loading}) => _app(
      FlSkeletonGroup(
        label: 'Profil',
        loading: loading,
        variant: FlSkeletonVariant.pulse,
        child: const FlSkeletonText(lines: 1, child: Text('Ada')),
      ),
    );
    await tester.pumpWidget(group(loading: true));
    expect(tester.getSize(find.byType(FlSkeleton)).width, 100, reason: 'une seule ligne prend toute la largeur');
    await tester.pump(const Duration(milliseconds: 500));
    expect(_boneOpacity(tester), lessThan(1));
    await tester.pumpWidget(group(loading: false));
    expect(find.text('Ada'), findsOneWidget);
  });
}
