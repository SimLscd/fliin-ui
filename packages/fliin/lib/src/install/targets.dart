import 'package:fliin_schema/fliin_schema.dart';

/// Le dossier de chaque alias de cible, sous `root` de `fliin.yaml`.
const targetDirectories = {
  TargetAlias.core: 'core',
  TargetAlias.components: 'components',
  TargetAlias.screens: 'screens',
  TargetAlias.icons: 'icons',
  TargetAlias.lib: 'lib',
  TargetAlias.root: '',
};

/// Relatif à `root` : `components/button/fl_button.dart`, ou `LICENSE`.
String underRoot(ItemTarget target) =>
    switch (targetDirectories[target.alias]) {
      '' || null => target.path,
      final dir => '$dir/${target.path}',
    };

/// Relatif au projet : `lib/ui/fliin/components/button/fl_button.dart`.
String projectPath(RenderConfig config, ItemTarget target) =>
    '${config.root}/${underRoot(target)}';

/// L'URI d'import d'un chemin sous `lib/` : `package:app/ui/fliin/….dart`.
String importUri(RenderConfig config, String projectPath) =>
    'package:${config.package}/${projectPath.substring('lib/'.length)}';
