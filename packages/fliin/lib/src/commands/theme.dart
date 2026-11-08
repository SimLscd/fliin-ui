import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_style/dart_style.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/icon_swap.dart';
import '../install/kept_raws.dart';
import '../install/lockfile_io.dart';
import '../install/registry_port.dart';
import '../project/fliin_yaml.dart';
import '../tokens/preset_notes.dart';
import '../tokens/project_tokens.dart';
import 'exit_code.dart';
import 'project_command.dart';

class ThemeCommand extends ProjectCommand {
  ThemeCommand(super.openRegistry, super.io) {
    argParser
      ..addOption(
        'preset',
        valueHelp: 'code',
        help:
            'A preset from the theme page (c0000000000000: Izydesk). It starts '
            'from the tokens shipped with the installed core version and sets '
            'colors, radii, spacing, shadows, fonts and button. It cannot be '
            'combined with the other options.',
      )
      ..addOption(
        'primary',
        valueHelp: '#RRGGBB',
        help:
            'The brand color, the base of the light and dark accent. Without '
            'it, the file’s accent steps stay.',
      )
      ..addOption(
        'neutral',
        allowed: [for (final tone in NeutralTone.values) tone.name],
        help: 'The neutral tone. Without it, the file’s neutrals stay.',
      )
      ..addOption(
        'button',
        allowed: [for (final shape in ButtonShape.values) shape.name],
        help: 'The button shape.',
      )
      ..addOption(
        'radius',
        valueHelp: 'px',
        help: 'shape.radius.control, from 0 to 9999.',
      )
      ..addOption(
        'font',
        valueHelp: 'family',
        help:
            'A named font, to declare in the app’s pubspec.yaml. system goes '
            'back to the platform font.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help:
            'Writes nothing. Prints the JSON patch (RFC 6902) and the report.',
      );
  }

  @override
  String get name => 'theme';

  @override
  String get description =>
      'Adapts core/tokens/fliin.tokens.json to a brand color without '
      'breaking contrast, then regenerates tokens.g.dart.';

  bool get dryRun => argResults!.flag('dry-run');

  @override
  bool get writesProject => !dryRun;

  @override
  Future<int> execute() async {
    final preset = _preset();
    final request = preset == null ? _request() : const ThemeRequest();
    final dir = projectDir;
    final config = readFliinConfig(dir);
    if (config == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName not found. Run fliin init.',
      );
    }
    final tokensDir = p.join(dir.path, config.render.root, 'core', 'tokens');
    if (!dryRun) removeTemporaries(Directory(tokensDir));
    final source = File(p.join(tokensDir, tokensJsonName));
    final target = File(p.join(tokensDir, tokensDartName));
    final paths = {
      'tokens': p.relative(source.path, from: dir.path),
      'generated': p.relative(target.path, from: dir.path),
    };
    final Object? json;
    final ThemeOutcome outcome;
    var overwritten = const <PresetOverwrite>[];
    IconSwap? icons;
    Future<Registry>? opened;
    Future<Registry> registry() =>
        opened ??= openRegistry(config.registries[Namespace.fliin]);
    try {
      json = jsonDecode(source.readAsStringSync());
      switch (preset) {
        case null:
          outcome = solveTheme(json, request);
        case final preset:
          final defaults = await _installedTokens(
            dir,
            registry,
            paths['tokens']!,
          );
          outcome = applyPreset(json, defaults, preset);
          if (outcome case ThemeSolved(:final patch)) {
            overwritten = presetOverwrites(
              json,
              defaults,
              config.preset,
              patch,
            );
            // À chaque préréglage, même jeu que fliin.yaml : planIconSwap ne
            // change rien quand le fichier installé est déjà celui du jeu, et
            // répare un fliin.yaml retouché ou une écriture interrompue.
            icons = await planIconSwap(
              dir: dir,
              render: config.render,
              lockfile: readLockfile(dir),
              registry: registry,
              set: preset.icons,
            );
          }
      }
    } on _NotInstalled catch (e) {
      return fail(e.code, e.message, paths);
    } on IconSwapBlocked catch (e) {
      return fail(ExitCode.failure, '$e', paths);
    } on PresetError catch (e) {
      return fail(ExitCode.failure, e.message, paths);
    } on FormatException catch (e) {
      return fail(ExitCode.failure, '${paths['tokens']}: ${e.message}', paths);
    } on TokenError catch (e) {
      return fail(ExitCode.failure, '${paths['tokens']}: $e', paths);
    } on FileSystemException catch (e) {
      return fail(ExitCode.failure, '${paths['tokens']}: ${e.message}', paths);
    }
    switch (outcome) {
      case Unsatisfiable():
        return _unsatisfiable(outcome, paths);
      case ThemeSolved(:final patch, :final contrast, :final clashes):
        final String text;
        final String dart;
        try {
          final patched = applyJsonPatch(json, patch);
          text = tokensJsonText(patched);
          dart = renderTokensDart(patched, prefix: config.render.prefix);
        } on JsonPatchError catch (e) {
          return fail(ExitCode.failure, 'Invalid theme: $e', paths);
        } on TokenError catch (e) {
          return fail(ExitCode.failure, 'Invalid theme: $e', paths);
        } on FormatterException catch (e) {
          return fail(
            ExitCode.failure,
            'The generated Dart cannot be formatted: ${e.message()}',
            paths,
          );
        }
        final changes = {
          if (patch.isNotEmpty) source: text,
          if (!target.existsSync() || target.readAsStringSync() != dart)
            target: dart,
        };
        if (!dryRun && preset != null && config.preset != preset) {
          changes[File(p.join(dir.path, fliinYamlName))] = emitYaml(
            config.withPreset(preset).toJson(),
          );
        }
        if (!dryRun && icons != null) {
          changes[File(p.join(dir.path, icons.path))] = icons.text;
          changes[File(p.join(dir.path, lockfileName))] = lockfileText(
            icons.lockfile,
          );
        }
        if (!dryRun && changes.isNotEmpty) {
          try {
            replaceFiles(changes);
          } on FileSystemException catch (e) {
            return fail(
              ExitCode.failure,
              'Nothing was written: ${e.path ?? ''}: ${e.message}',
              paths,
            );
          }
        }
        return _solved(
          patch,
          contrast,
          clashes,
          request,
          preset,
          overwritten,
          icons,
          paths,
          [
            for (final file in changes.keys)
              p.relative(file.path, from: dir.path),
          ],
        );
    }
  }

  /// `--preset`, décodé ; nul sans lui. Un code refusé, ou un autre réglage
  /// à côté, est une erreur d'usage (64).
  Preset? _preset() {
    final args = argResults!;
    final code = args.option('preset');
    if (code == null) return null;
    final others = [
      for (final name in ['primary', 'neutral', 'button', 'radius', 'font'])
        if (args.wasParsed(name)) '--$name',
    ];
    if (others.isNotEmpty) {
      usageException(
        '--preset already sets the whole theme. Remove ${others.join(', ')}.',
      );
    }
    try {
      return Preset.decode(code.trim());
    } on PresetError catch (e) {
      usageException('--preset: ${e.message}');
    }
  }

  /// Le `fliin.tokens.json` que le registre a livré pour la version de
  /// `core` installée : le brut que le lockfile désigne, gardé dans le
  /// projet, sinon dans le cache, sinon relu au registre et vérifié par son
  /// sha256, comme `fliin update` relit la base.
  Future<Object?> _installedTokens(
    Directory dir,
    Future<Registry> Function() registry,
    String relative,
  ) async {
    final path = p.posix.joinAll(p.split(relative));
    final locked = [
      for (final item
          in readLockfile(dir)?.items.values ?? const <LockedItem>[])
        if (item.files[path] case final file?) (item.version, file.raw),
    ];
    if (locked.isEmpty) {
      throw _NotInstalled(
        '$path is not in $lockfileName. A preset starts from the tokens the '
        'registry shipped. Run fliin init.',
      );
    }
    final (version, raw) = locked.single;
    final Uint8List bytes;
    try {
      bytes = keptRaw(dir, raw) ?? await (await registry()).fetchBlob(raw);
    } on RegistryUnreachable catch (e) {
      throw _NotInstalled(
        'A preset starts from the tokens shipped with core $version, which '
        'fliin reads from the registry (or its cache): ${e.detail}. Run it '
        'again once you are online. fliin theme --primary works offline.',
        code: ExitCode.environment,
      );
    }
    if (Sha256.ofBytes(bytes) case final actual when actual != raw) {
      throw IntegrityFailure(raw, actual);
    }
    return jsonDecode(utf8.decode(bytes));
  }

  ThemeRequest _request() {
    final args = argResults!;
    final primary = switch (args.option('primary')) {
      null => null,
      final text => switch (Rgb8.tryParse(text)) {
        final color? => toOklch(color),
        null => usageException('--primary: expected #RRGGBB.'),
      },
    };
    final font = switch (args.option('font')?.trim()) {
      null => null,
      'system' => const SystemFont(),
      final name
          when name.isNotEmpty &&
              !name.contains(',') &&
              !name.contains(RegExp(r'[\x00-\x1F\x7F]')) =>
        NamedFont(name),
      _ => usageException(
        '--font: expected one non-empty family, with no comma or control '
        'character (or system).',
      ),
    };
    final radius = switch (args.option('radius')) {
      null => null,
      final text => switch (double.tryParse(text)) {
        final value? when value >= 0 && value <= 9999 => value,
        _ => usageException('--radius: expected a number from 0 to 9999.'),
      },
    };
    return ThemeRequest(
      primary: primary,
      neutral: switch (args.option('neutral')) {
        null => null,
        final name => NeutralTone.values.byName(name),
      },
      button: switch (args.option('button')) {
        null => null,
        final name => ButtonShape.values.byName(name),
      },
      radius: radius,
      font: font,
    );
  }

  int _solved(
    List<PatchOp> patch,
    List<ContrastCheck> contrast,
    List<RoleClash> clashes,
    ThemeRequest request,
    Preset? preset,
    List<PresetOverwrite> overwritten,
    IconSwap? icons,
    Map<String, String> paths,
    List<String> changed,
  ) {
    final warnings = [
      if (preset == null)
        if (request.font case NamedFont(:final family))
          'font $family: declare it in the app’s pubspec.yaml '
              '(flutter: fonts:). fliin does not download it',
      if (preset != null) ...presetFontWarnings(preset),
      for (final edit in overwritten)
        'manual edit overwritten: ${edit.path} '
            '(${_show(edit.before)} → ${_show(edit.after)}). The preset owns '
            'this path. Apply your edit again afterwards',
      if (icons case (
        :final path,
        :final set,
        overwritten: true,
        text: _,
        lockfile: _,
      ))
        'local change overwritten: $path was no longer the file fliin '
            'wrote. The ${set.label} icon set replaces it. Apply your change '
            'again afterwards (git diff $path)',
      for (final check in contrast)
        if (check.excused)
          'declared contrast exception: ${_pairText(check.pair)} '
              '(${_mode(check.appearance)}) at ${_ratio(check.ratio)}:1 for '
              '${check.threshold}:1, "${check.exception!.reason}". '
              'fliin theme --primary gives a compliant theme with no exception',
      for (final clash in clashes)
        '${clash.role} and ${clash.other} look the same in '
            '${clash.appearance == Appearance.light ? 'light' : 'dark'} mode '
            '(ΔE OKLab ${clash.deltaE.toStringAsFixed(2)}, '
            'less than $distinctDeltaE). A field in error only differs from '
            'a focused field by its message',
    ];
    final written = !dryRun && changed.isNotEmpty;
    return succeed(
      {
        ...paths,
        'dryRun': dryRun,
        'written': written,
        'patch': [for (final op in patch) patchOpJson(op)],
        'contrast': [for (final check in contrast) contrastCheckJson(check)],
        'warnings': warnings,
        if (preset != null)
          'preset': {
            'code': preset.encode(),
            ...preset.describe,
            'pubspec': presetPubspecBlock(preset),
          },
        if (preset != null)
          'overwritten': [
            for (final edit in overwritten)
              {'path': edit.path, 'before': edit.before, 'after': edit.after},
          ],
        if (icons case (
          :final path,
          :final set,
          :final overwritten,
          text: _,
          lockfile: _,
        ))
          'icons': {'path': path, 'set': set.name, 'overwritten': overwritten},
      },
      [
        if (preset != null) ...presetLines(preset),
        if (dryRun) ...[
          '--dry-run: nothing was written. JSON patch (RFC 6902) against '
              '${paths['tokens']}:',
          const JsonEncoder.withIndent('  ')
              .convert([for (final op in patch) patchOpJson(op)]),
        ] else if (written)
          '${changed.join(' and ')} rewritten.'
        else
          '${paths['tokens']} already has this theme. Nothing to write.',
        if (!dryRun)
          for (final (path, before, after) in _replacements(patch))
            '  $path: $before → $after',
        if (icons case (
          :final path,
          :final set,
          overwritten: _,
          text: _,
          lockfile: _,
        ))
          dryRun
              ? '${set.label} icon set: $path would be replaced.'
              : '${set.label} icon set: $path replaced.',
        'Contrast:',
        for (final check in contrast) '  ${_checkLine(check)}',
        for (final warning in warnings) 'Warning: $warning.',
        if (preset != null && presetPubspecBlock(preset).isNotEmpty) ...[
          '',
          presetPubspecBlock(preset),
        ],
      ],
    );
  }

  /// Chaque `replace` du patch, avec la valeur que son `test` a lue.
  static Iterable<(String, String, String)> _replacements(
    List<PatchOp> patch,
  ) sync* {
    final read = {
      for (final op in patch)
        if (op.op == PatchOperation.test) op.path: op.value,
    };
    for (final op in patch) {
      switch (op.op) {
        case PatchOperation.replace:
          yield (op.path, _show(read[op.path]), _show(op.value));
        case PatchOperation.add:
          yield (op.path, '(missing)', _show(op.value));
        case PatchOperation.test:
      }
    }
  }

  static String _show(Object? value) => switch (value) {
    {'hex': final String hex} => hex,
    _ => jsonEncode(value),
  };

  int _unsatisfiable(Unsatisfiable outcome, Map<String, String> paths) {
    final failing = outcome.failing;
    final brand =
        argResults!.option('primary')?.toUpperCase() ?? 'the file’s accent';
    final proposals = [
      if (outcome.sameHue case (:final primary, chroma: _))
        'Same hue, less saturated: fliin theme --primary "${primary.hex}".',
      if (outcome.nearestHue case (:final hue, :final primary))
        'Nearest hue at this saturation: $hue° '
            '(fliin theme --primary "${primary.hex}").',
    ];
    final message =
        'UNSATISFIABLE: ${failing.pair.foreground} on '
        '${failing.pair.background} (${_mode(failing.appearance)}) reaches '
        '${_ratio(failing.ratio)}:1 at best for a threshold of '
        '${failing.threshold}:1 while $brand keeps two thirds of its '
        'chroma. This floor, which keeps the brand recognizable, is what '
        'blocks. '
        '${proposals.isEmpty ? 'No suggestion.' : proposals.join(' ')}';
    return fail(ExitCode.failure, message, {
      ...paths,
      'error': {
        'kind': 'UNSATISFIABLE',
        'failing': contrastCheckJson(failing),
        'sameHue': switch (outcome.sameHue) {
          (:final chroma, :final primary) => {
            'chroma': chroma,
            'primary': primary.hex,
          },
          null => null,
        },
        'nearestHue': switch (outcome.nearestHue) {
          (:final hue, :final primary) => {'hue': hue, 'primary': primary.hex},
          null => null,
        },
      },
    });
  }

  static String _checkLine(ContrastCheck check) =>
      '${_mode(check.appearance).padRight(7)}'
      '${_pairText(check.pair).padRight(34)}'
      '${_ratio(check.ratio).padLeft(6)}:1  ≥ ${check.threshold}  '
      '${check.ok
          ? 'ok'
          : check.excused
          ? 'EXCEPTION'
          : 'FAIL'}';

  static String _pairText(ContrastPair pair) => [
    '${pair.foreground} / ${pair.background}',
    for (final role in pair.over) '/ $role',
  ].join(' ');

  static String _mode(Appearance appearance) => switch (appearance) {
    Appearance.light => 'light',
    Appearance.dark => 'dark',
  };

  /// Tronqué au centième : un 4,50 affiché n'est jamais un 4,497.
  static String _ratio(double ratio) =>
      ((ratio * 100).floor() / 100).toStringAsFixed(2);
}

/// Le fichier de jetons n'est pas dans le lockfile : rien à quoi repartir.
final class _NotInstalled implements Exception {
  const _NotInstalled(this.message, {this.code = ExitCode.failure});

  final String message;
  final ExitCode code;
}
