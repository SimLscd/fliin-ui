import 'package:fliin_ui/components/tag_group/fl_tag_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

final _light = FlTokens.defaults.light;

const _tags = [FlTag('news', 'Actualités'), FlTag('travel', 'Voyage'), FlTag('games', 'Jeux')];

/// Un groupe que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.selection = FlTagSelection.single, this.disabled = false, this.removable = false});

  final FlTagSelection selection;
  final bool disabled;
  final bool removable;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Set<String> selected = {};
  List<FlTag<String>> tags = [..._tags];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: FlTagGroup<String>(
      tags: tags,
      selection: widget.selection,
      selected: selected,
      disabled: widget.disabled,
      onSelectionChanged: (next) => setState(() => selected = next),
      onRemove: widget.removable
          ? (value) => setState(
              () => tags = [
                for (final tag in tags)
                  if (tag.value != value) tag,
              ],
            )
          : null,
      removeLabel: (label) => 'Retirer $label',
      empty: const Text('Aucune catégorie', textDirection: TextDirection.ltr),
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

/// Le fond de l'étiquette [label].
Color? _fill(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(
    find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as ShapeDecoration).color;
}

void main() {
  testWidgets('devrait s’annoncer comme une liste d’éléments sélectionnables qui se touchent', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    final list = tester.getSemantics(find.byType(Wrap));
    expect(list.role, SemanticsRole.list);
    expect(
      tester.getSemantics(find.text('Voyage')),
      matchesSemantics(
        label: 'Voyage',
        role: SemanticsRole.listItem,
        isButton: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait choisir une seule étiquette, et la relâcher au second toucher, en sélection simple', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Voyage'));
    await tester.pumpAndSettle();
    expect(_host(tester).selected, {'travel'});
    expect(_fill(tester, 'Voyage'), _light.selected);
    expect(tester.widget<Text>(find.text('Voyage')).style!.color, _light.onSelected);
    await tester.tap(find.text('Jeux'));
    await tester.pump();
    expect(_host(tester).selected, {'games'});
    await tester.tap(find.text('Jeux'));
    await tester.pump();
    expect(_host(tester).selected, isEmpty);
    expect(_fill(tester, 'Jeux'), _light.control);
  });

  testWidgets('devrait basculer chaque étiquette touchée en sélection multiple', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(selection: FlTagSelection.multiple)));
    await tester.tap(find.text('Voyage'));
    await tester.pump();
    await tester.tap(find.text('Jeux'));
    await tester.pump();
    expect(_host(tester).selected, {'travel', 'games'});
    await tester.tap(find.text('Voyage'));
    await tester.pump();
    expect(_host(tester).selected, {'games'});
  });

  testWidgets('devrait seulement afficher les étiquettes, sans action, quand la sélection est none', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(selection: FlTagSelection.none)));
    expect(tester.getSemantics(find.text('Voyage')), matchesSemantics(label: 'Voyage', role: SemanticsRole.listItem));
    await tester.tap(find.text('Voyage'));
    await tester.pump();
    expect(_host(tester).selected, isEmpty);
    semantics.dispose();
  });

  testWidgets('devrait passer à demi opaque et ignorer le toucher quand le groupe est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(disabled: true, removable: true)));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Voyage'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, FlTokens.defaults.size.disabledOpacity);
    await tester.tap(find.text('Voyage'));
    await tester.tap(find.bySemanticsLabel('Retirer Voyage'), warnIfMissed: false);
    await tester.pump();
    expect(_host(tester).selected, isEmpty);
    expect(_host(tester).tags, hasLength(3));
  });

  testWidgets('devrait retirer l’étiquette par sa croix nommée, puis montrer l’état vide', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(removable: true), platform: TargetPlatform.iOS));
    final cross = find.bySemanticsLabel('Retirer Voyage');
    expect(tester.getSemantics(cross).rect.size, Size.square(FlTokens.defaults.size.hitTargetIos));
    await tester.tap(cross);
    await tester.pump();
    expect(find.text('Voyage'), findsNothing);
    expect(_host(tester).selected, isEmpty);
    await tester.tap(find.bySemanticsLabel('Retirer Actualités'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Retirer Jeux'));
    await tester.pump();
    expect(find.text('Aucune catégorie'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait prendre les marges, le rayon et le texte de sa taille, sur le fond de sa variante', (
    tester,
  ) async {
    for (final (size, height) in [(FlTagSize.sm, 24.0), (FlTagSize.md, 28.0), (FlTagSize.lg, 36.0)]) {
      await tester.pumpWidget(
        toggleApp(
          FlTagGroup<String>(tags: _tags, size: size, variant: FlTagGroupVariant.surface),
          platform: TargetPlatform.iOS,
        ),
      );
      final tag = find.ancestor(of: find.text('Voyage'), matching: find.byType(DecoratedBox)).first;
      expect(tester.getSize(tag).height, height, reason: '$size');
      expect(_fill(tester, 'Voyage'), _light.control);
      expect(tester.widget<Text>(find.text('Voyage')).style!.color, _light.onField);
    }
  });

  testWidgets('devrait passer à la ligne avec 8 entre les étiquettes', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 140,
          child: FlTagGroup<String>(tags: _tags, size: FlTagSize.md),
        ),
      ),
    );
    final news = tester.getRect(find.ancestor(of: find.text('Actualités'), matching: find.byType(DecoratedBox)).first);
    final travel = tester.getRect(find.ancestor(of: find.text('Voyage'), matching: find.byType(DecoratedBox)).first);
    expect(travel.top - news.bottom, 8);
  });
}
