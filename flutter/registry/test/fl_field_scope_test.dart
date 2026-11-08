import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('devrait donner l’état du champ le plus proche, et nul hors d’un champ', (tester) async {
    FlFieldScope? inside, outside;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) => Text('${outside = FlFieldScope.maybeOf(context)}', textDirection: TextDirection.ltr),
          ),
          FlFieldScope(
            invalid: true,
            required: true,
            child: Builder(
              builder: (context) => Text('${inside = FlFieldScope.maybeOf(context)}', textDirection: TextDirection.ltr),
            ),
          ),
        ],
      ),
    );
    expect(outside, isNull);
    expect((inside!.invalid, inside!.disabled, inside!.required, inside!.inset), (true, false, true, false));
  });

  testWidgets('devrait reconstruire une partie quand l’état du champ change', (tester) async {
    var builds = 0;
    Widget field({required bool invalid}) => FlFieldScope(invalid: invalid, child: const _Probe());
    _Probe.onBuild = () => builds++;
    await tester.pumpWidget(field(invalid: false));
    await tester.pumpWidget(field(invalid: false));
    expect(builds, 1);
    await tester.pumpWidget(field(invalid: true));
    expect(builds, 2);
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  static VoidCallback onBuild = () {};

  @override
  Widget build(BuildContext context) {
    FlFieldScope.maybeOf(context);
    onBuild();
    return const SizedBox();
  }
}
