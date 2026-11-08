import 'dart:io';

import 'package:fliin/src/verify/harness_source.g.dart';
import 'package:test/test.dart';

void main() {
  test('devrait embarquer exactement flutter/harness/lib/fliin_harness.dart (ADR §4.1)', () {
    expect(
      harnessSource,
      File('../../flutter/harness/lib/fliin_harness.dart').readAsStringSync(),
      reason: 'lancez dart run tool/embed_harness.dart depuis la racine',
    );
  });
}
