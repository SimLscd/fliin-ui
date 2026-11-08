import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

const abc =
    'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

void main() {
  test(
    "devrait donner l'empreinte du brut quand on hache ses octets (règle 1)",
    () {
      expect(Sha256.ofBytes('abc'.codeUnits), Sha256.parse(abc));
      expect(Sha256.ofString('abc').value, abc);
    },
  );

  test(
    "devrait distinguer deux contenus quand ils diffèrent d'un octet (règle 1)",
    () {
      expect(Sha256.ofString('abd'), isNot(Sha256.ofString('abc')));
    },
  );

  test(
    'devrait refuser une empreinte quand elle est en majuscules (règle 1)',
    () {
      expect(() => Sha256.parse(abc.toUpperCase()), throwsFormatException);
      expect(
        () => Sha256.parse('sha256:${abc.substring(7).toUpperCase()}'),
        throwsFormatException,
      );
    },
  );

  test(
    'devrait refuser une empreinte quand le préfixe ou la longueur manque',
    () {
      expect(() => Sha256.parse(abc.substring(7)), throwsFormatException);
      expect(() => Sha256.parse(abc.substring(0, 70)), throwsFormatException);
      expect(() => Sha256.parse('${abc}0'), throwsFormatException);
    },
  );

  test(
    "devrait exposer l'hexadécimal sans préfixe quand on construit un chemin",
    () {
      expect(Sha256.parse(abc).hex, abc.substring(7));
    },
  );
}
