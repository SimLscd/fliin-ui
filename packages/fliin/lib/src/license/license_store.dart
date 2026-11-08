import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/environment_failure.dart';

/// D'où vient la clé de licence active.
enum LicenseOrigin { environment, file }

/// Une clé de licence Fliin Pro. Elle ne s'affiche jamais : seulement
/// [hint].
final class License {
  const License(this.key, this.origin);

  final String key;
  final LicenseOrigin origin;

  /// Les quatre derniers caractères, précédés de `…`.
  String get hint =>
      '…${key.length <= 4 ? key : key.substring(key.length - 4)}';
}

/// La clé de licence de l'utilisateur, hors de tout projet (ADR 0020 §5) :
/// [variable] d'abord, le chemin de la CI, puis `credentials.json` dans le
/// dossier de configuration de l'utilisateur, en 0600.
final class LicenseStore {
  LicenseStore({Map<String, String>? environment, bool? windows})
    : _environment = environment ?? Platform.environment,
      _windows = windows ?? Platform.isWindows;

  static const variable = 'FLIIN_LICENSE_KEY';

  final Map<String, String> _environment;
  final bool _windows;

  /// `%APPDATA%\fliin\credentials.json` sous Windows,
  /// `$XDG_CONFIG_HOME/fliin/credentials.json` ou
  /// `~/.config/fliin/credentials.json` ailleurs. Lève une
  /// [EnvironmentFailure] quand aucune de ces variables n'est posée.
  String get path {
    String? set(String name) => switch (_environment[name]) {
      final value? when value.isNotEmpty => value,
      _ => null,
    };
    final String folder;
    if (_windows) {
      folder =
          set('APPDATA') ??
          (throw const EnvironmentFailure(
            'APPDATA is not set, so fliin has nowhere to store the license '
            'key. Set FLIIN_LICENSE_KEY instead.',
          ));
    } else if (set('XDG_CONFIG_HOME') case final xdg? when p.isAbsolute(xdg)) {
      folder = xdg;
    } else {
      folder = p.join(
        set('HOME') ??
            (throw const EnvironmentFailure(
              'HOME is not set, so fliin has nowhere to store the license '
              'key. Set FLIIN_LICENSE_KEY instead.',
            )),
        '.config',
      );
    }
    return p.join(folder, 'fliin', 'credentials.json');
  }

  /// Vrai quand [variable] est posée : elle passe avant le fichier.
  bool get fromEnvironment =>
      _environment[variable]?.trim().isNotEmpty ?? false;

  /// La clé active, nulle sans clé. Lève une [EnvironmentFailure] quand le
  /// fichier existe et ne se lit pas.
  License? read() {
    if (_environment[variable]?.trim() case final key? when key.isNotEmpty) {
      return License(key, LicenseOrigin.environment);
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      if (jsonDecode(file.readAsStringSync())
          case {'licenseKey': final String key} when key.isNotEmpty) {
        return License(key, LicenseOrigin.file);
      }
    } on FormatException {
      // Le message ci-dessous dit quoi faire.
    } on FileSystemException catch (e) {
      throw EnvironmentFailure(
        '$path cannot be read (${e.osError?.message ?? e.message}). Run fliin '
        'logout, then fliin login.',
      );
    }
    throw EnvironmentFailure(
      '$path is not a fliin credentials file. Run fliin logout, then fliin '
      'login.',
    );
  }

  /// Écrit [key] en 0600 : le fichier est restreint avant d'en recevoir le
  /// contenu, puis remplace l'ancien d'un bloc.
  void write(String key) {
    final target = File(path);
    try {
      target.parent.createSync(recursive: true);
      _restrict(target.parent.path, '700');
      final partial = File('${target.path}.$pid')..createSync();
      _restrict(partial.path, '600');
      partial
        ..writeAsStringSync('${jsonEncode({'licenseKey': key})}\n')
        ..renameSync(target.path);
    } on FileSystemException catch (e) {
      throw EnvironmentFailure(
        '$path cannot be written (${e.osError?.message ?? e.message}). Set '
        'FLIIN_LICENSE_KEY instead.',
      );
    }
  }

  /// Vrai si un fichier a été effacé.
  bool delete() {
    final file = File(path);
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// Sous Windows, `%APPDATA%` est déjà propre à l'utilisateur.
  void _restrict(String path, String mode) {
    if (_windows) return;
    final run = Process.runSync('chmod', [mode, path]);
    if (run.exitCode != 0) {
      throw FileSystemException('chmod $mode failed: ${run.stderr}', path);
    }
  }
}
