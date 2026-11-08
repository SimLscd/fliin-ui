import 'dart:async';

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/components/toast/fl_toast.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';

final _key = GlobalKey<FlToasterState>();

Widget _app({
  FlToastPlacement placement = FlToastPlacement.top,
  TargetPlatform platform = TargetPlatform.iOS,
  EdgeInsets padding = EdgeInsets.zero,
  bool announce = false,
  bool screenReader = false,
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(800, 600),
    padding: padding,
    supportsAnnounce: announce,
    accessibleNavigation: screenReader,
    disableAnimations: reduceMotion,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(
      brightness: Brightness.light,
      platform: platform,
      child: FlToaster(key: _key, placement: placement, child: const SizedBox.expand()),
    ),
  ),
);

FlToasterState get _toaster => _key.currentState!;

FlToast _toast(String title, {String? description, FlToastAction? action, String? closeLabel}) =>
    FlToast(title: title, description: description, action: action, closeLabel: closeLabel);

Rect _rect(WidgetTester tester, String title) =>
    tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(FlToast)));

double _opacity(WidgetTester tester, String title) =>
    tester.widget<Opacity>(find.ancestor(of: find.text(title), matching: find.byType(Opacity)).first).opacity;

void main() {
  testWidgets('devrait poser l’action en bouton principal, en onAccent, quel que soit le statut', (tester) async {
    for (final tokens in [FlTokens.defaults, tortureA]) {
      for (final brightness in Brightness.values) {
        for (final variant in FlToastVariant.values) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: FlScope(
                tokens: tokens,
                brightness: brightness,
                platform: TargetPlatform.iOS,
                child: Center(
                  child: FlToast(
                    title: 'Envoyé',
                    variant: variant,
                    action: FlToastAction(label: 'Annuler', onPressed: () {}),
                  ),
                ),
              ),
            ),
          );
          final colors = brightness == Brightness.light ? tokens.light : tokens.dark;
          final label = tester.widget<Text>(find.text('Annuler'));
          expect(label.style!.color, colors.onAccent, reason: '${variant.name} ${brightness.name}');
          expect(find.byType(FlButton), findsOneWidget);
        }
      }
    }
  });

  testWidgets('devrait afficher le titre et la description quand show est appelé', (tester) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Fichier envoyé', description: 'rapport.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Fichier envoyé'), findsOneWidget);
    expect(find.text('rapport.pdf'), findsOneWidget);
  });

  testWidgets('devrait trouver le toaster par of et lever une erreur quand il manque', (tester) async {
    late BuildContext inside;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlToaster(child: Builder(builder: (context) => const SizedBox.expand())),
      ),
    );
    inside = tester.element(find.byType(SizedBox));
    expect(FlToaster.of(inside), isA<FlToasterState>());
    await tester.pumpWidget(const SizedBox());
    expect(() => FlToaster.of(tester.element(find.byType(SizedBox))), throwsFlutterError);
  });

  testWidgets('devrait fermer le toast quand sa durée de 4 s est écoulée', (tester) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Copié'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('Copié'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Copié'), findsNothing);
  });

  testWidgets('devrait suivre la durée demandée et garder un toast persistant', (tester) async {
    await tester.pumpWidget(_app());
    _toaster
      ..show(_toast('Bref'), duration: const Duration(seconds: 1))
      ..show(_toast('Persistant'), persistent: true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Bref'), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Persistant'), findsOneWidget);
  });

  testWidgets('devrait garder un toast à action tant qu’un lecteur d’écran est actif', (tester) async {
    await tester.pumpWidget(_app(screenReader: true));
    _toaster.show(
      _toast(
        'Supprimé',
        action: FlToastAction(label: 'Annuler', onPressed: () {}),
      ),
    );
    _toaster.show(_toast('Copié'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Supprimé'), findsOneWidget);
    expect(find.text('Copié'), findsNothing);
  });

  testWidgets('devrait fermer le toast quand son bouton de fermeture est touché', (tester) async {
    var closed = 0;
    await tester.pumpWidget(_app());
    _toaster.show(FlToast(title: 'Mis à jour', closeLabel: 'Fermer', onClose: () => closed++), persistent: true);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Fermer'));
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(find.text('Mis à jour'), findsNothing);
  });

  testWidgets('devrait appeler l’action puis fermer le toast quand l’action est touchée', (tester) async {
    var undone = 0;
    await tester.pumpWidget(_app());
    _toaster.show(
      _toast(
        'Supprimé',
        action: FlToastAction(label: 'Annuler', onPressed: () => undone++),
      ),
      persistent: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Supprimé'), findsNothing);
  });

  testWidgets('devrait fermer un toast par hide et tous par hideAll', (tester) async {
    await tester.pumpWidget(_app());
    final first = _toaster.show(_toast('Un'), persistent: true);
    _toaster
      ..show(_toast('Deux'), persistent: true)
      ..show(_toast('Trois'), persistent: true);
    await tester.pumpAndSettle();
    _toaster.hide(first);
    await tester.pumpAndSettle();
    expect(find.text('Un'), findsNothing);
    expect(find.text('Deux'), findsOneWidget);
    _toaster.hideAll();
    await tester.pumpAndSettle();
    expect(find.byType(FlToast), findsNothing);
  });

  testWidgets('devrait empiler derrière le dernier toast les précédents réduits et décalés vers l’intérieur', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Ancien', description: 'Sur deux lignes de texte'), persistent: true);
    await tester.pumpAndSettle();
    _toaster.show(_toast('Récent'), persistent: true);
    await tester.pumpAndSettle();
    final front = _rect(tester, 'Récent');
    final behind = _rect(tester, 'Ancien');
    // Même hauteur que le toast de devant, réduit de 10 % et descendu de 14,
    // comme la pile du canvas.
    expect(behind.height, moreOrLessEquals(front.height * 0.9, epsilon: 0.01));
    expect(behind.width, moreOrLessEquals(front.width * 0.9, epsilon: 0.01));
    expect(behind.center.dy - front.center.dy, moreOrLessEquals(14, epsilon: 0.01));
  });

  testWidgets('devrait effacer et rendre inerte un toast au-delà de maxVisible', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    for (final title in ['Un', 'Deux', 'Trois', 'Quatre']) {
      _toaster.show(_toast(title), persistent: true);
      await tester.pumpAndSettle();
    }
    expect(_opacity(tester, 'Un'), 0);
    expect(_opacity(tester, 'Deux'), 1);
    expect(find.semantics.byLabel('Un'), findsNothing);
    expect(find.semantics.byLabel('Quatre'), findsOne);
    semantics.dispose();
  });

  testWidgets('devrait fermer le toast du haut quand on le glisse vers le haut', (tester) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Glissé'), persistent: true);
    await tester.pumpAndSettle();
    await tester.drag(find.text('Glissé'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('Glissé'), findsNothing);
  });

  testWidgets('devrait revenir en place quand le glisser est court ou vers l’intérieur', (tester) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Retenu'), persistent: true);
    await tester.pumpAndSettle();
    final rest = _rect(tester, 'Retenu');
    await tester.timedDrag(find.text('Retenu'), const Offset(0, -20), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_rect(tester, 'Retenu'), rest);
    final gesture = await tester.startGesture(rest.center);
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 280));
    await tester.pump();
    // L'élastique : 300 points tirés sur 600 de haut en donnent 20.
    expect(_rect(tester, 'Retenu').center.dy - rest.center.dy, moreOrLessEquals(20, epsilon: 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_rect(tester, 'Retenu'), rest);
  });

  testWidgets('devrait fermer le toast du bas quand on le glisse vers le bas', (tester) async {
    await tester.pumpWidget(_app(placement: FlToastPlacement.bottom));
    _toaster.show(_toast('En bas'), persistent: true);
    await tester.pumpAndSettle();
    await tester.drag(find.text('En bas'), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(find.text('En bas'), findsNothing);
  });

  testWidgets('devrait poser les toasts sous la zone sûre et à 12 des côtés sous iOS', (tester) async {
    await tester.pumpWidget(_app(padding: const EdgeInsets.only(top: 47, bottom: 34)));
    _toaster
      ..show(_toast('Haut'), persistent: true)
      ..show(_toast('Bas'), placement: FlToastPlacement.bottom, persistent: true);
    await tester.pumpAndSettle();
    expect(_rect(tester, 'Haut').top, 47);
    expect(_rect(tester, 'Haut').left, 12);
    expect(_rect(tester, 'Haut').right, 800 - 12);
    expect(_rect(tester, 'Bas').bottom, 600 - 34 - 6);
  });

  testWidgets('devrait écarter les toasts de 12 de chaque bord hors d’iOS', (tester) async {
    await tester.pumpWidget(_app(platform: TargetPlatform.android, padding: const EdgeInsets.only(top: 24)));
    _toaster.show(_toast('Haut'), persistent: true);
    await tester.pumpAndSettle();
    expect(_rect(tester, 'Haut').top, 24 + 12);
  });

  testWidgets('devrait entrer en glissant depuis le bord, et en fondu seul sous mouvement réduit', (tester) async {
    await tester.pumpWidget(_app());
    _toaster.show(_toast('Entrée'), persistent: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_rect(tester, 'Entrée').top, lessThan(0));
    await tester.pumpAndSettle();
    expect(_rect(tester, 'Entrée').top, 0);

    await tester.pumpWidget(_app(reduceMotion: true));
    _toaster.show(_toast('Fondu'), persistent: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_rect(tester, 'Fondu').top, 0);
    expect(_opacity(tester, 'Fondu'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'Fondu'), 1);
  });

  testWidgets('devrait annoncer le titre et la description au lecteur d’écran quand le toast s’affiche', (
    tester,
  ) async {
    final messages = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async => messages.add(message),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    await tester.pumpWidget(_app(announce: true));
    _toaster.show(_toast('Fichier envoyé', description: 'rapport.pdf'));
    await tester.pumpAndSettle();
    expect(messages, [
      {
        'type': 'announce',
        'data': {'viewId': 0, 'message': 'Fichier envoyé\nrapport.pdf', 'textDirection': 1},
      },
    ]);
  });

  testWidgets('devrait marquer le toast comme région vivante pour TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(platform: TargetPlatform.android));
    _toaster.show(_toast('Copié'), persistent: true);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byType(FlToast)), matchesSemantics(label: 'Copié', isLiveRegion: true));
    semantics.dispose();
  });

  testWidgets('devrait garder la durée du fondu quand le système désactive les animations', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final fade = FlTokens.defaults.motion.short3;
    await tester.pumpWidget(_app(reduceMotion: true));
    _toaster.show(_toast('Fondu'), persistent: true);
    await tester.pump();
    await tester.pump(fade ~/ 2);
    expect(_opacity(tester, 'Fondu'), closeTo(0.5, 0.1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'Fondu'), 1);
  });

  group('icône', () {
    const icon = SizedBox.square(key: Key('icon'), dimension: 20);
    final pop = find.ancestor(of: find.byKey(const Key('icon')), matching: find.byType(FlPop));
    double scale(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(of: pop, matching: find.byType(Transform)).first)
        .transform
        .entry(0, 0);
    double opacity(WidgetTester tester) =>
        // FlPop's fade, which adds no layer when opaque, exposes its alpha.
        ((tester.widget(
              find.descendant(of: pop, matching: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Fade')).first,
            ) as dynamic).alpha
            as int) /
        255;

    testWidgets('devrait attendre que le toast se pose, puis faire rebondir son icône depuis la moitié', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      _toaster.show(const FlToast(title: 'Enregistré', icon: icon, variant: FlToastVariant.success));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(tester), 0, reason: 'the icon waits for medium1');
      await tester.pump(const Duration(milliseconds: 90));
      expect(opacity(tester), greaterThan(0));
      expect(scale(tester), inInclusiveRange(0.5, 1));
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (scale(tester) > peak) peak = scale(tester);
      }
      expect(peak, greaterThan(1));
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      expect(opacity(tester), 1);
    });

    testWidgets('devrait montrer l’icône sans délai ni échelle sous mouvement réduit', (tester) async {
      await tester.pumpWidget(_app(reduceMotion: true));
      _toaster.show(const FlToast(title: 'Enregistré', icon: icon));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity(tester), greaterThan(0));
      expect(scale(tester), 1);
    });

    testWidgets('devrait montrer l’icône d’emblée quand le toast est posé seul, hors d’un toaster', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            platform: TargetPlatform.iOS,
            child: Center(
              child: FlToast(title: 'Enregistré', icon: icon),
            ),
          ),
        ),
      );
      expect(opacity(tester), 1);
      expect(scale(tester), 1);
    });
  });

  testWidgets('devrait remplacer le toast à sa place et relancer sa durée quand update le reçoit', (tester) async {
    await tester.pumpWidget(_app());
    final id = _toaster.show(_toast('Envoi…'), persistent: true);
    await tester.pumpAndSettle();
    final before = _rect(tester, 'Envoi…');
    expect(_toaster.update(id, _toast('Envoyé')), isTrue);
    await tester.pump();
    expect(find.text('Envoi…'), findsNothing);
    expect(_rect(tester, 'Envoyé').topLeft, before.topLeft);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Envoyé'), findsNothing);
    expect(_toaster.update(id, _toast('Trop tard')), isFalse);
  });

  testWidgets('devrait montrer le chargement puis le succès ou l’erreur quand promise suit un Future', (tester) async {
    await tester.pumpWidget(_app());
    final ok = Completer<int>();
    final ko = Completer<int>();
    _toaster
      ..promise(
        ok.future,
        loading: const FlToast(title: 'Un…', loading: true),
        success: (n) => FlToast(title: 'Un : $n'),
        error: (e) => const FlToast(title: 'Un raté'),
      )
      ..promise(
        ko.future,
        loading: const FlToast(title: 'Deux…', loading: true),
        success: (n) => FlToast(title: 'Deux : $n'),
        error: (e) => FlToast(title: 'Deux raté : $e'),
      );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FlSpinner), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Un…'), findsOneWidget, reason: 'sans durée tant que le Future court');
    ok.complete(3);
    ko.completeError('réseau');
    await tester.pump();
    expect(find.text('Un : 3'), findsOneWidget);
    expect(find.text('Deux raté : réseau'), findsOneWidget);
    expect(find.byType(FlSpinner), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(FlToast), findsNothing);
  });

  testWidgets('devrait poser l’icône du statut quand showIcon est vrai, et aucune par défaut', (tester) async {
    Widget toast(FlToast toast) => Directionality(
      textDirection: TextDirection.ltr,
      child: FlScope(
        platform: TargetPlatform.iOS,
        child: Center(child: toast),
      ),
    );
    await tester.pumpWidget(toast(const FlToast(title: 'Rien')));
    expect(find.byType(FlIcon), findsNothing);
    for (final variant in FlToastVariant.values) {
      await tester.pumpWidget(toast(FlToast(title: 'Statut', variant: variant, showIcon: true)));
      expect(find.byType(FlIcon), findsOneWidget, reason: variant.name);
      expect(IconTheme.of(tester.element(find.byType(FlIcon))).size, 20);
    }
    await tester.pumpWidget(
      toast(
        FlToast(
          title: 'Retirer',
          action: FlToastAction(label: 'Retirer', variant: FlButtonVariant.danger, onPressed: () {}),
        ),
      ),
    );
    expect(tester.widget<FlButton>(find.byType(FlButton)).variant, FlButtonVariant.danger);
  });
}
