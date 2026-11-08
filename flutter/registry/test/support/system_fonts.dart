import 'dart:io';

import 'package:flutter/services.dart';

/// Les polices des goldens, chargées sous un nom de famille pour un test :
/// SF du Mac pour iOS, Roboto du SDK pour Android. Une mesure de texte qui
/// dépend de la largeur des glyphes se fait sous elles, pas sous la police
/// de test, dont chaque glyphe est un carré.
enum SystemFont {
  sf('FliinTestSF'),
  roboto('FliinTestRoboto');

  const SystemFont(this.family);

  /// Le nom de famille à donner au `TextStyle`.
  final String family;

  List<File> get _files => switch (this) {
    sf => [File('/System/Library/Fonts/SFNS.ttf')],
    roboto => [
      for (final weight in ['Regular', 'Medium', 'Bold'])
        if (_flutterRoot() case final root?) File('${root.path}/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf'),
    ],
  };

  /// Charge la police ; faux si elle manque sur cette machine.
  Future<bool> load() async {
    final present = _files.where((file) => file.existsSync()).toList();
    if (present.isEmpty) return false;
    final loader = FontLoader(family);
    for (final file in present) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
    return true;
  }
}

Directory? _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) return dir;
    dir = dir.parent;
  }
  return null;
}
