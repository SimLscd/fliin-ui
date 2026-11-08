import 'dart:io';

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';

import 'torture.g.dart';

/// Les thèmes sous lesquels le registre rend ses matrices : le défaut et les
/// deux thèmes de torture de DESIGN.md §2.1. Torture B demande aussi la
/// densité compacte, qui n'est pas un jeton mais un choix de `FlScope`.
typedef FlTestTheme = ({String id, FlTokens tokens, FlDensity? density});

final List<FlTestTheme> flTestThemes = [
  (id: 'default', tokens: FlTokens.defaults, density: null),
  (id: 'torture-a', tokens: tortureA, density: null),
  (id: 'torture-b', tokens: tortureB, density: FlDensity.compact),
];

/// Charge la police nommée par torture A, que le SDK Flutter épinglé porte
/// sous licence Apache 2.0. Sans elle, le texte retomberait sur la police du
/// harnais et le thème ne torturerait plus rien : son absence fait échouer.
Future<void> loadTortureFonts() async {
  final family = tortureA.typography.ios.fontFamily!;
  final file = File('${_flutterRoot().path}/engine/src/flutter/txt/third_party/fonts/HomemadeApple.ttf');
  if (!file.existsSync()) throw StateError('$family introuvable : ${file.path}');
  await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())))).load();
}

Directory _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('SDK Flutter introuvable depuis ${Platform.resolvedExecutable}');
}
