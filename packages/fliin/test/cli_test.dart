import 'package:fliin/fliin.dart';
import 'package:test/test.dart';

void main() {
  test('devrait retourner 64 quand la commande est inconnue', () async {
    expect(await run(['nope']), 64);
  });

  test('devrait retourner 0 quand on demande la version', () async {
    expect(await run(['version']), 0);
  });

  test('devrait refuser --token en usage (64) : le jeton se lit dans .fliin/local.json (synthèse #16)', () async {
    final err = StringBuffer();
    expect(
      await run(['mcp', '--http', '--token', 'x'], io: (out: StringBuffer(), err: err)),
      64,
    );
    expect('$err', contains('token'));
  });
}
