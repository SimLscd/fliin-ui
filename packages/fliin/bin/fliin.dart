import 'dart:io';

import 'package:fliin/fliin.dart' as fliin;

Future<void> main(List<String> args) async {
  exitCode = await fliin.run(args);
}
