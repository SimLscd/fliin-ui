// Reads an item manifest, merges three versions of a file the way
// `fliin update` does, and measures a contrast the way `fliin theme` does.
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';

void main() {
  const source = 'class FlButton {}\n';
  final manifest = ItemManifest.fromJson({
    'name': 'button',
    'type': 'registry:component',
    'version': '0.2.5',
    'title': 'Button',
    'description': 'Triggers the main action of a screen or form.',
    'flutter': '>=3.47.0 <4.0.0',
    'registryDependencies': ['core@^0.2.0', 'spinner@^0.2.0'],
    'files': [
      {
        'path': 'components/button/fl_button.dart',
        'type': 'registry:component',
        'target': '@components/button/fl_button.dart',
        'sha256': Sha256.ofString(source).value,
      },
    ],
    'meta': {
      'tier': 'free',
      'platforms': ['ios', 'android'],
      'intents': {
        'fr': ['valider un formulaire'],
        'en': ['submit a form'],
      },
    },
  });
  stdout.writeln(
    '${manifest.name} ${manifest.version} needs '
    '${manifest.registryDependencies.join(', ')}',
  );

  // A parse error names the JSON path at fault.
  try {
    ItemManifest.fromJson({'name': 'Button'});
  } on Object catch (error) {
    stdout.writeln('rejected: $error');
  }

  // The base you installed, your copy, and the new upstream version.
  final merged = diff3(
    base: 'padding: 12\nradius: 8\nlabel: Save\n',
    local: 'padding: 16\nradius: 8\nlabel: Save\n',
    upstream: 'padding: 12\nradius: 8\nlabel: Save changes\n',
    upstreamLabel: 'button 0.3.0',
  );
  stdout
    ..writeln('merged cleanly: ${merged.clean}')
    ..write(merged.text);

  final ratio = contrastRatio(Rgb8.parse('#0A6CFF'), Rgb8.parse('#FFFFFF'));
  stdout.writeln('contrast: ${ratio.toStringAsFixed(2)}:1');
}
