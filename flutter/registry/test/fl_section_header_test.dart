import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/components/section_header/fl_section_header.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 320, child: child),
    ),
  ),
);

void main() {
  final space = FlTokens.defaults.space;

  testWidgets('devrait annoncer le titre comme un en-tête quand le lecteur d’écran parcourt la page', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlSectionHeader(title: 'Compte')));
    expect(tester.getSemantics(find.text('Compte')), matchesSemantics(label: 'Compte', isHeader: true));
    semantics.dispose();
  });

  testWidgets('devrait retirer le titre de space.lg du bord du groupe, au début du sens de lecture', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(_app(const FlSectionHeader(title: 'Compte'), direction: direction));
      final box = tester.getRect(find.byType(FlSectionHeader));
      final text = tester.getRect(find.text('Compte'));
      final inset = direction == TextDirection.ltr ? text.left - box.left : box.right - text.right;
      expect(inset, space.lg, reason: '$direction');
      expect(box.bottom - text.bottom, space.sm, reason: '$direction');
    }
  });

  testWidgets('devrait écrire le titre en textSm atténué', (tester) async {
    await tester.pumpWidget(_app(const FlSectionHeader(title: 'Compte')));
    final style = tester.widget<Text>(find.text('Compte')).style!;
    final ios = FlTokens.defaults.typography.ios.style(FlTextRole.textSm);
    expect(style.fontSize, ios.size);
    expect(style.color, FlTokens.defaults.light.onSurfaceMuted);
  });

  testWidgets('devrait poser le lien au bout et appeler son action quand on le touche', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _app(
        FlSectionHeader(
          title: 'Récents',
          action: FlSectionHeaderAction(label: 'Tout voir', onPressed: () => pressed++),
        ),
      ),
    );
    final box = tester.getRect(find.byType(FlSectionHeader));
    final link = tester.getRect(find.byType(FlLinkButton));
    expect(box.right - link.right, space.lg);
    await tester.tap(find.text('Tout voir'));
    expect(pressed, 1);
  });

  testWidgets('devrait passer le lien sous l’intitulé sans couper de mot quand le texte est agrandi', (tester) async {
    // La police de test donne 1 em à chaque glyphe : à 2,0, un mot de 7
    // lettres fait 196 points et tient dans la colonne de 236 moins ses
    // marges, « Preferences » (308) dans celle de 358.
    for (final (width, title) in [(358.0, 'Preferences'), (236.0, 'Mes listes de favoris')]) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FlScope(
              brightness: Brightness.light,
              platform: TargetPlatform.iOS,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: FlSectionHeader(
                    title: title,
                    action: FlSectionHeaderAction(label: 'Tout voir', onPressed: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$width $title');
      expect(_cutWords(tester.renderObject<RenderParagraph>(find.text(title)), title), isEmpty, reason: '$width');
      final box = tester.getRect(find.byType(FlSectionHeader));
      final text = tester.getRect(find.text(title));
      final link = tester.getRect(find.byType(FlLinkButton));
      if (link.top >= text.bottom) {
        expect(link.left - box.left, space.lg, reason: '$width : le lien passe dessous, au début');
      } else {
        expect(box.right - link.right, space.lg, reason: '$width : le lien reste au bout');
      }
    }
  });

  testWidgets(
    'devrait écrire un grand titre en title3 sur onSurface, space.md au-dessus du contenu, quand size est large',
    (tester) async {
      await tester.pumpWidget(_app(const FlSectionHeader(title: 'Populaires', size: FlSectionHeaderSize.large)));
      final style = tester.widget<Text>(find.text('Populaires')).style!;
      expect(style.fontSize, FlTokens.defaults.typography.ios.style(FlTextRole.title3).size);
      expect(style.color, FlTokens.defaults.light.onSurface);
      final box = tester.getRect(find.byType(FlSectionHeader));
      expect(box.bottom - tester.getRect(find.text('Populaires')).bottom, space.md);
    },
  );

  testWidgets('devrait poser la description atténuée sous le titre, le lien restant sur la ligne du titre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FlSectionHeader(
          title: 'Top',
          size: FlSectionHeaderSize.large,
          description: 'Selon vos commandes',
          action: FlSectionHeaderAction(label: 'Voir', onPressed: () {}),
        ),
      ),
    );
    final title = tester.getRect(find.text('Top'));
    final description = tester.getRect(find.text('Selon vos commandes'));
    final link = tester.getRect(find.byType(FlLinkButton));
    // Under the title's line, which the link's touch target may make taller.
    expect(description.top - tester.getRect(find.byType(OverflowBar)).bottom, space.xs);
    expect(description.top, greaterThan(title.bottom));
    expect(link.center.dy, closeTo(title.center.dy, 0.5));
    expect(tester.widget<Text>(find.text('Selon vos commandes')).style!.color, FlTokens.defaults.light.onSurfaceMuted);
  });

  testWidgets('devrait poser trailing au bout du titre quand il remplace le lien', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlSectionHeader(
          title: 'Non lus',
          trailing: SizedBox(key: Key('count'), width: 20, height: 16),
        ),
      ),
    );
    final box = tester.getRect(find.byType(FlSectionHeader));
    expect(box.right - tester.getRect(find.byKey(const Key('count'))).right, space.lg);
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
