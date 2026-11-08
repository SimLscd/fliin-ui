import 'dart:async';

import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduced = false, double textScale = 1}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced, textScaler: TextScaler.linear(textScale)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(
      platform: TargetPlatform.iOS,
      child: Center(child: child),
    ),
  ),
);

/// Une image servie par [completer] : décodée, en échec, ou jamais.
class _Pending extends ImageProvider<_Pending> {
  _Pending(this.completer);

  final Completer<ImageInfo> completer;

  @override
  Future<_Pending> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(completer.future);
}

final _fill = find.descendant(of: find.byType(FlAvatar), matching: find.byType(DecoratedBox));

double _opacityOf(WidgetTester tester, Finder finder) =>
    tester.widget<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)).first).opacity.value;

void main() {
  final tokens = FlTokens.defaults;
  final light = tokens.light;

  testWidgets('devrait poser le fond de la variante et colorer les initiales de la couleur douce', (tester) async {
    for (final (variant, color, fill, ink) in [
      (FlAvatarVariant.primary, FlAvatarColor.accent, light.control, light.onAccentSoft),
      (FlAvatarVariant.primary, FlAvatarColor.danger, light.control, light.danger),
      (FlAvatarVariant.soft, FlAvatarColor.accent, light.accentSoft, light.onAccentSoft),
      (FlAvatarVariant.soft, FlAvatarColor.success, light.successSoft, light.onSuccessSoft),
      (FlAvatarVariant.soft, FlAvatarColor.neutral, light.control, light.onControl),
    ]) {
      await tester.pumpWidget(_app(FlAvatar(initials: 'JD', variant: variant, color: color)));
      final reason = '${variant.name} ${color.name}';
      expect((tester.widget<DecoratedBox>(_fill).decoration as ShapeDecoration).color, fill, reason: reason);
      final style = tester.widget<Text>(find.text('JD')).style!;
      expect(style.color, ink, reason: reason);
      expect(style.fontWeight, tokens.typography.weight.medium, reason: reason);
    }
  });

  testWidgets('devrait mesurer 40, 48 et 64, la silhouette 14, 16 et 20', (tester) async {
    for (final (size, side, icon) in [
      (FlAvatarSize.sm, 40.0, 14.0),
      (FlAvatarSize.md, 48.0, 16.0),
      (FlAvatarSize.lg, 64.0, 20.0),
      (FlAvatarSize.xl, 88.0, 32.0),
    ]) {
      await tester.pumpWidget(_app(FlAvatar(size: size)));
      await tester.pumpAndSettle();
      expect(tester.getSize(_fill), Size.square(side), reason: size.name);
      final silhouette = find.descendant(of: find.byType(FlAvatar), matching: find.byType(CustomPaint)).last;
      expect(tester.getSize(silhouette), Size.square(icon), reason: size.name);
    }
  });

  testWidgets('devrait ne montrer que le fond pendant le chargement, puis le repli si l’image échoue', (tester) async {
    final completer = Completer<ImageInfo>();
    await tester.pumpWidget(_app(FlAvatar(image: _Pending(completer), initials: 'JD')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('JD'), findsNothing);
    completer.completeError(StateError('404'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('devrait faire entrer l’image chargée en fondu de short4, et d’un coup sous mouvement réduit', (
    tester,
  ) async {
    final image = (await tester.runAsync(() => createTestImage(width: 8, height: 8)))!;
    for (final reduced in [false, true]) {
      final completer = Completer<ImageInfo>();
      await tester.pumpWidget(
        _app(
          FlAvatar(key: UniqueKey(), image: _Pending(completer)),
          reduced: reduced,
        ),
      );
      completer.complete(ImageInfo(image: image.clone()));
      await tester.pump();
      await tester.pump();
      final raw = find.byType(RawImage);
      expect(_opacityOf(tester, raw), reduced ? 1 : 0, reason: 'reduced $reduced');
      await tester.pump(tokens.motion.short4 ~/ 2);
      if (!reduced) expect(_opacityOf(tester, raw), inExclusiveRange(0, 1));
      await tester.pump(tokens.motion.short4);
      expect(_opacityOf(tester, raw), 1, reason: 'reduced $reduced');
    }
    image.dispose();
  });

  testWidgets('devrait attendre fallbackDelay avant de faire entrer les initiales', (tester) async {
    await tester.pumpWidget(_app(const FlAvatar(initials: 'JD', fallbackDelay: Duration(milliseconds: 600))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacityOf(tester, find.text('JD')), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacityOf(tester, find.text('JD')), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacityOf(tester, find.text('JD')), 1);
  });

  testWidgets('devrait borner les initiales à 1,4 fois leur taille', (tester) async {
    await tester.pumpWidget(_app(const FlAvatar(initials: 'JD'), textScale: 2));
    final scaler = MediaQuery.textScalerOf(tester.element(find.text('JD')));
    expect(scaler.scale(10), 14);
  });

  testWidgets('devrait peindre le fond à sa forme sans le découper, pour ne pas l’anticréneler deux fois', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlAvatar(initials: 'JD')));
    expect(find.descendant(of: find.byType(FlAvatar), matching: find.byType(ClipPath)), findsNothing);
  });

  testWidgets('devrait se lire comme une image nommée', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlAvatar(initials: 'JD', semanticLabel: 'Jane Doe')));
    final node = tester.getSemantics(find.byType(FlAvatar));
    expect(node.label, 'Jane Doe');
    expect(node.flagsCollection.isImage, isTrue);
    handle.dispose();
  });

  testWidgets('devrait se lire par ses initiales quand semanticLabel est nul', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlAvatar(initials: 'JD')));
    final node = tester.getSemantics(find.byType(FlAvatar));
    expect(node.label, 'JD');
    expect(node.flagsCollection.isImage, isTrue);
    handle.dispose();
  });

  testWidgets(
    'devrait prendre dimension, radius et les couleurs données au lieu de ceux de la taille et de la couleur',
    (tester) async {
      await tester.pumpWidget(
        _app(
          FlAvatar(
            initials: 'MB',
            size: FlAvatarSize.sm,
            dimension: 24,
            radius: 6,
            backgroundColor: tokens.light.successSoft,
            foregroundColor: tokens.light.onSuccessSoft,
          ),
        ),
      );
      expect(tester.getSize(find.byType(FlAvatar)), const Size(24, 24));
      final decoration = tester.widget<DecoratedBox>(_fill.first).decoration as ShapeDecoration;
      expect(decoration.color, tokens.light.successSoft);
      expect((decoration.shape as FlContinuousBorder).radius, 6);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(find.text('MB')).style!.color, tokens.light.onSuccessSoft);
      expect(tester.widget<Text>(find.text('MB')).style!.fontSize, tokens.typography.ios.textXs.size);
    },
  );
}
