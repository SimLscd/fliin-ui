import 'package:fliin_ui/components/alert/fl_alert.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    platform: TargetPlatform.iOS,
    child: Center(child: SizedBox(width: 360, child: child)),
  ),
);

final _statusIcon = find.descendant(of: find.byType(FlIcon), matching: find.byType(CustomPaint));

void main() {
  final tokens = FlTokens.defaults;
  final light = tokens.light;

  testWidgets(
    'devrait colorer le titre et l’icône de la couleur douce du statut, l’icône accent en accent, la description atténuée',
    (tester) async {
      for (final (status, color) in [
        (FlAlertStatus.neutral, light.onSurface),
        (FlAlertStatus.accent, light.onAccentSoft),
        (FlAlertStatus.success, light.onSuccessSoft),
        (FlAlertStatus.warning, light.onWarningSoft),
        (FlAlertStatus.danger, light.onDangerSoft),
      ]) {
        await tester.pumpWidget(
          _app(
            FlAlert(
              title: 'Titre',
              description: 'Texte',
              status: status,
              icon: const SizedBox(key: Key('icon')),
            ),
          ),
        );
        final title = tester.widget<Text>(find.text('Titre')).style!;
        expect(title.color, color, reason: status.name);
        expect(title.fontWeight, tokens.typography.weight.medium);
        expect(tester.widget<Text>(find.text('Texte')).style!.color, light.onSurfaceMuted);
        final icon = IconTheme.of(tester.element(find.byKey(const Key('icon'))));
        expect(icon.color, status == FlAlertStatus.accent ? light.accent : color, reason: status.name);
        expect(icon.size, 20);
      }
    },
  );

  testWidgets('devrait prendre la hauteur de son contenu dans une marge de 16, pas celle qu’on lui offre', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlAlert(title: 'Titre', description: 'Texte')));
    final ios = tokens.typography.ios;
    expect(tester.getSize(find.byType(FlAlert)).height, 16 + ios.textBase.lineHeight + 2 + ios.textSm.lineHeight + 16);
    expect(
      tester.getTopLeft(find.text('Titre')) - tester.getTopLeft(find.byType(FlAlert)),
      const Offset(16 + 20 + 12, 16),
    );
  });

  testWidgets('devrait dessiner l’icône d’information, de validation, d’avertissement ou d’erreur selon le statut', (
    tester,
  ) async {
    // Points du viewBox 16 : le point du « i », l'anneau à gauche, la barre
    // du « ! ». L'anneau n'existe pas autour du triangle, le point du « i »
    // tombe dans le vide de la validation.
    const dot = Offset(8, 5.5);
    const ring = Offset(2, 8);
    const bar = Offset(8, 6.5);
    final info = paints..path(includes: [dot, ring]);
    for (final (status, icon) in [
      (FlAlertStatus.neutral, info),
      (FlAlertStatus.accent, info),
      (FlAlertStatus.success, paints..path(includes: [ring], excludes: [dot])),
      (FlAlertStatus.warning, paints..path(includes: [bar], excludes: [ring])),
      (FlAlertStatus.danger, paints..path(includes: [ring], excludes: [dot, bar])),
    ]) {
      await tester.pumpWidget(_app(FlAlert(title: 'Titre', status: status)));
      expect(tester.renderObject(_statusIcon), icon, reason: status.name);
    }
  });

  testWidgets('devrait retirer l’icône et sa place quand showIcon est faux', (tester) async {
    await tester.pumpWidget(_app(const FlAlert(title: 'Titre')));
    expect(_statusIcon, findsOneWidget);
    await tester.pumpWidget(_app(const FlAlert(title: 'Titre', showIcon: false)));
    expect(_statusIcon, findsNothing);
    expect(tester.getTopLeft(find.text('Titre')) - tester.getTopLeft(find.byType(FlAlert)), const Offset(16, 16));
  });

  testWidgets(
    'devrait poser content 8 sous la description, atténué, et action 12 sous le texte, alignée sur le titre',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const FlAlert(
            title: 'Titre',
            description: 'Texte',
            content: Text('Étape'),
            action: SizedBox(key: Key('action'), width: 40, height: 20),
          ),
        ),
      );
      final description = tester.getRect(find.text('Texte'));
      final content = tester.getRect(find.text('Étape'));
      final action = tester.getRect(find.byKey(const Key('action')));
      expect(content.top - description.bottom, 8);
      expect(content.left, tester.getTopLeft(find.text('Titre')).dx);
      expect(
        tester
            .widget<RichText>(find.descendant(of: find.text('Étape'), matching: find.byType(RichText)))
            .text
            .style!
            .color,
        light.onSurfaceMuted,
      );
      expect(action.top - content.bottom, 12);
      expect(action.left, tester.getTopLeft(find.text('Titre')).dx);
      expect(tester.getRect(find.byType(FlAlert)).bottom - action.bottom, 16);
    },
  );

  testWidgets('devrait être une région vivante portant le titre et la description quand elle apparaît hors du web', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FlAlert(
          title: 'Titre',
          description: 'Texte',
          trailing: Semantics(
            container: true,
            button: true,
            label: 'Voir',
            child: const SizedBox.square(dimension: 20),
          ),
        ),
      ),
    );
    final alert = tester.getSemantics(find.byType(FlAlert));
    expect(alert.flagsCollection.isLiveRegion, isTrue);
    expect(alert.label, 'Titre\nTexte');
    expect(alert.role, isNot(SemanticsRole.alert));
    expect(alert.flagsCollection.isHeader, isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Voir')), isNot(same(alert)));
    handle.dispose();
  });

  testWidgets('devrait poser une erreur à plat sur le rouge pastel, les autres statuts sur une carte ombrée', (
    tester,
  ) async {
    final light = FlTokens.defaults.light;
    await tester.pumpWidget(_app(const FlAlert(title: 'Paiement refusé', status: FlAlertStatus.danger)));
    final surface = find.descendant(of: find.byType(FlAlert), matching: find.byType(FlSurface));
    expect(tester.widget<FlSurface>(surface).color, Color.alphaBlend(light.dangerSoft, light.surfaceRaised));
    expect(tester.widget<FlSurface>(surface).variant, FlSurfaceVariant.transparent);
    await tester.pumpWidget(_app(const FlAlert(title: 'Enregistré', status: FlAlertStatus.success)));
    expect(tester.widget<FlSurface>(surface).color, isNull);
    expect(tester.widget<FlSurface>(surface).variant, FlSurfaceVariant.primary);
  });
}
