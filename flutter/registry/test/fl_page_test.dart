import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/page/fl_page.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/components/tab_bar/fl_tab_bar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(390, 844);
const _safe = EdgeInsets.only(top: 47, bottom: 34);

/// Un téléphone de 390 × 844, sa zone sûre, et un clavier de [keyboard].
Widget _phoneApp(Widget page, {TargetPlatform platform = TargetPlatform.iOS, double keyboard = 0}) => MediaQuery(
  data: MediaQueryData(
    size: _phone,
    viewPadding: _safe,
    padding: EdgeInsets.only(top: _safe.top, bottom: keyboard > 0 ? 0 : _safe.bottom),
    viewInsets: EdgeInsets.only(bottom: keyboard),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(brightness: Brightness.light, platform: platform, child: page),
  ),
);

Future<void> _pumpPhone(WidgetTester tester, Widget page, {TargetPlatform platform = TargetPlatform.iOS}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_phoneApp(page, platform: platform));
}

List<Widget> _rows([int count = 30]) => [
  SliverList.list(
    children: [for (var i = 0; i < count; i++) SizedBox(key: ValueKey(i), height: 56, child: Text('Ligne $i'))],
  ),
];

final _tabBar = FlBottomTabBar(
  index: 0,
  onSelected: (_) {},
  tabs: const [
    FlBottomTab(icon: SizedBox.square(dimension: 24), label: 'Accueil'),
    FlBottomTab(icon: SizedBox.square(dimension: 24), label: 'Messages'),
    FlBottomTab(icon: SizedBox.square(dimension: 24), label: 'Profil'),
  ],
);

const _appBar = FlAppBar(title: 'Réglages');

double _firstRowTop(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey(0))).top;

/// Tire le haut du contenu de [distance] par petits pas, comme un doigt.
Future<TestGesture> _pullDown(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(const Offset(195, 400));
  for (var moved = 0.0; moved < distance; moved += 10) {
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// Laisse le défilement et les ressorts se poser pendant que le spinner
/// tourne : `pumpAndSettle` attendrait sa fin.
Future<void> _settleWhileSpinning(WidgetTester tester) async {
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final colors = FlTokens.defaults.light;

  testWidgets('devrait poser la barre d’onglets en bas et finir le contenu au-dessus d’elle', (tester) async {
    await _pumpPhone(tester, FlPage(appBar: _appBar, tabBar: _tabBar, slivers: _rows()));
    final bar = tester.getRect(find.byType(FlBottomTabBar));
    expect(bar.bottom, _phone.height);
    expect(tester.getRect(find.byType(CustomScrollView)).bottom, bar.top);
    expect(tester.getRect(find.byType(FlAppBar)).top, 0);
    expect(_firstRowTop(tester), tester.getRect(find.byType(FlAppBar)).bottom);
  });

  testWidgets('devrait garder la zone sûre en marge du contenu quand la page n’a ni barre du haut ni d’onglets', (
    tester,
  ) async {
    final controller = ScrollController();
    await _pumpPhone(tester, FlPage(controller: controller, slivers: _rows()));
    expect(_firstRowTop(tester), _safe.top);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey(29))).bottom, _phone.height - _safe.bottom);
  });

  testWidgets('devrait réduire le contenu au clavier sans soulever la barre d’onglets', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_phoneApp(FlPage(tabBar: _tabBar, slivers: _rows()), keyboard: 300));
    expect(tester.getRect(find.byType(CustomScrollView)).bottom, _phone.height - 300);
    expect(tester.getRect(find.byType(FlBottomTabBar)).bottom, _phone.height);
  });

  testWidgets('devrait faire défiler un champ focalisé au-dessus du clavier et sous la barre du haut', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    Widget page(double keyboard) => _phoneApp(
      FlPage(
        appBar: _appBar,
        tabBar: _tabBar,
        slivers: [
          SliverList.list(
            children: [
              for (var i = 0; i < 9; i++) SizedBox(height: 56, child: Text('Ligne $i')),
              KeyedSubtree(
                key: const ValueKey('champ'),
                child: EditableText(
                  controller: controller,
                  focusNode: focus,
                  style: const TextStyle(fontSize: 16),
                  cursorColor: colors.accent,
                  backgroundCursorColor: colors.onSurfaceMuted,
                ),
              ),
              for (var i = 0; i < 9; i++) SizedBox(height: 56, child: Text('Suite $i')),
            ],
          ),
        ],
      ),
      keyboard: keyboard,
    );
    await tester.pumpWidget(page(0));
    focus.requestFocus();
    await tester.pump();
    // EditableText lit le clavier sur la vue, pas dans la MediaQuery.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(page(336));
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const ValueKey('champ')));
    expect(field.bottom, lessThanOrEqualTo(_phone.height - 336));
    expect(field.top, greaterThanOrEqualTo(tester.getRect(find.byType(FlAppBar)).bottom));
  });

  testWidgets('devrait rebondir sur iOS et buter sur Android', (tester) async {
    for (final (platform, physics) in [
      (TargetPlatform.iOS, BouncingScrollPhysics),
      (TargetPlatform.android, ClampingScrollPhysics),
    ]) {
      await _pumpPhone(tester, FlPage(slivers: _rows()), platform: platform);
      expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics.runtimeType, physics);
    }
  });

  testWidgets('devrait dévoiler le spinner et garder le contenu baissé pendant le rafraîchissement sur iOS', (
    tester,
  ) async {
    final done = Completer<void>();
    var calls = 0;
    await _pumpPhone(
      tester,
      FlPage(
        appBar: _appBar,
        refresh: FlPageRefresh(
          label: 'Actualiser',
          onRefresh: () {
            calls++;
            return done.future;
          },
        ),
        slivers: _rows(),
      ),
    );
    final rest = _firstRowTop(tester);
    final gesture = await _pullDown(tester, 400);
    await gesture.up();
    await _settleWhileSpinning(tester);
    expect(calls, 1);
    expect(_firstRowTop(tester), closeTo(rest + 60, 0.5));
    final spinner = tester.getRect(find.byType(FlSpinner));
    expect(spinner.center.dy, closeTo(rest + 30, 0.5));
    done.complete();
    await tester.pumpAndSettle();
    expect(_firstRowTop(tester), closeTo(rest, 0.5));
    expect(calls, 1);
  });

  testWidgets('devrait faire descendre le disque sur le contenu immobile pendant le rafraîchissement sur Android', (
    tester,
  ) async {
    final done = Completer<void>();
    var calls = 0;
    await _pumpPhone(
      tester,
      FlPage(
        appBar: _appBar,
        refresh: FlPageRefresh(
          label: 'Actualiser',
          onRefresh: () {
            calls++;
            return done.future;
          },
        ),
        slivers: _rows(),
      ),
      platform: TargetPlatform.android,
    );
    final rest = _firstRowTop(tester);
    final gesture = await _pullDown(tester, 160);
    expect(calls, 0, reason: 'Android rafraîchit au relâché');
    await gesture.up();
    await _settleWhileSpinning(tester);
    expect(calls, 1);
    expect(_firstRowTop(tester), rest);
    final disc = tester.getRect(find.byType(FlSpinner));
    expect(disc.center.dy, greaterThan(rest));
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FlSpinner), findsNothing);
  });

  testWidgets('devrait laisser retomber un tirage trop court sans rafraîchir', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      var calls = 0;
      await _pumpPhone(
        tester,
        FlPage(
          appBar: _appBar,
          refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () async => calls++),
          slivers: _rows(),
        ),
        platform: platform,
      );
      final rest = _firstRowTop(tester);
      final gesture = await _pullDown(tester, platform == TargetPlatform.iOS ? 60 : 40);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 0, reason: '$platform');
      expect(_firstRowTop(tester), rest, reason: '$platform');
    }
  });

  testWidgets('devrait offrir le rafraîchissement au lecteur d’écran comme une action nommée', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await _pumpPhone(
      tester,
      FlPage(
        refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () async => calls++),
        slivers: _rows(),
      ),
    );
    final node = tester.getSemantics(find.byType(CustomScrollView));
    final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
    final action = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Actualiser'));
    SemanticsNode? holder;
    for (SemanticsNode? n = node; n != null; n = n.parent) {
      if (n.getSemanticsData().customSemanticsActionIds?.contains(action) ?? false) holder = n;
    }
    expect(holder, isNotNull);
    owner.performAction(holder!.id, SemanticsAction.customAction, action);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(FlSpinner), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait rafraîchir une seule fois quand le doigt reste tiré après la fin du futur', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      var calls = 0;
      await _pumpPhone(
        tester,
        FlPage(
          appBar: _appBar,
          refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () async => calls++),
          slivers: _rows(),
        ),
        platform: platform,
      );
      final gesture = await _pullDown(tester, 800);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1, reason: '$platform');
      final again = await _pullDown(tester, 800);
      await again.up();
      await tester.pumpAndSettle();
      expect(calls, 2, reason: '$platform : un nouveau geste rafraîchit de nouveau');
    }
  });

  testWidgets('devrait poser l’indicateur sous la zone sûre du haut quand la page n’a pas de barre du haut', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final done = Completer<void>();
      await _pumpPhone(
        tester,
        FlPage(
          refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () => done.future),
          slivers: _rows(),
        ),
        platform: platform,
      );
      final gesture = await _pullDown(tester, 400);
      await gesture.up();
      await _settleWhileSpinning(tester);
      expect(tester.getRect(find.byType(FlSpinner)).top, greaterThanOrEqualTo(_safe.top), reason: '$platform');
      done.complete();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('devrait découper le disque d’Android au bord bas de la barre du haut', (tester) async {
    final done = Completer<void>();
    await _pumpPhone(
      tester,
      FlPage(
        appBar: const FlAppBar(title: 'Réglages', titleSize: FlAppBarTitleSize.large),
        refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () => done.future),
        slivers: _rows(),
      ),
      platform: TargetPlatform.android,
    );
    final gesture = await _pullDown(tester, 60);
    final bar = tester.getRect(find.byType(FlAppBar));
    expect(tester.getRect(find.byType(FlSpinner)).top, lessThan(bar.bottom), reason: 'le disque sort de sous la barre');
    final clips = tester.layers.whereType<ClipRectLayer>().where((layer) => layer.clipRect?.top == bar.bottom);
    expect(clips, isNotEmpty);
    await gesture.up();
    done.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('devrait dévoiler le spinner sous la barre quand le lecteur d’écran rafraîchit en bas de page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final done = Completer<void>();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpPhone(
      tester,
      FlPage(
        appBar: const FlAppBar(title: 'Réglages', titleSize: FlAppBarTitleSize.large),
        controller: controller,
        refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () => done.future),
        slivers: _rows(),
      ),
    );
    controller.jumpTo(400);
    await tester.pump();
    final holder = tester.getSemantics(find.bySemanticsLabel('Actualiser'));
    final action = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Actualiser'));
    expect(holder.getSemanticsData().customSemanticsActionIds, contains(action));
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      holder.id,
      SemanticsAction.customAction,
      action,
    );
    await _settleWhileSpinning(tester);
    final spinner = tester.getRect(find.byType(FlSpinner));
    expect(spinner.top, greaterThanOrEqualTo(tester.getRect(find.byType(FlAppBar)).bottom));
    expect(spinner.bottom, lessThanOrEqualTo(_firstRowTop(tester)));
    done.complete();
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('devrait ne déclarer d’en-tête dans son manifeste que si la page en annonce un sans barre du haut', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final manifest = jsonDecode(File('items/page.json').readAsStringSync()) as Map<String, Object?>;
    final roles = (manifest['meta']! as Map<String, Object?>)['semanticsRoles']! as List<Object?>;
    await _pumpPhone(
      tester,
      FlPage(
        refresh: FlPageRefresh(label: 'Actualiser', onRefresh: () async {}),
        tabBar: _tabBar,
        slivers: _rows(),
      ),
    );
    final headers = find.semantics.byPredicate((node) => node.getSemanticsData().flagsCollection.isHeader);
    expect(roles.contains('header'), headers.evaluate().isNotEmpty);
    semantics.dispose();
  });

  testWidgets('devrait garder le focus et l\'état du contenu quand le rafraîchissement disparaît puis revient', (
    tester,
  ) async {
    const target = ValueKey('cible');
    Widget page({required bool refresh}) => FlPage(
      refresh: refresh ? FlPageRefresh(label: 'Actualiser', onRefresh: () async {}) : null,
      slivers: [
        const SliverToBoxAdapter(
          child: Focus(
            debugLabel: 'cible',
            child: SizedBox(key: target, height: 56),
          ),
        ),
      ],
    );
    bool focused() => FocusManager.instance.primaryFocus?.debugLabel == 'cible';
    await _pumpPhone(tester, page(refresh: true));
    Focus.of(tester.element(find.byKey(target))).requestFocus();
    await tester.pump();
    expect(focused(), isTrue);
    final scrollable = tester.state(find.byType(Scrollable));
    for (final refresh in [false, true]) {
      await tester.pumpWidget(_phoneApp(page(refresh: refresh)));
      expect(focused(), isTrue, reason: 'refresh: $refresh');
      expect(tester.state(find.byType(Scrollable)), same(scrollable), reason: 'refresh: $refresh');
    }
  });
}
