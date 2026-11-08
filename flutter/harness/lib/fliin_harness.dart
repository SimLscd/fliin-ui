/// Rendering harness: variant matrix, capture, guidelines, report.
///
/// This file is copied verbatim into `test/.fliin/` of the user's app: it only
/// imports `dart:*`, `package:flutter/*` and `package:flutter_test/*`.
library;

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rendering variant: platform, brightness, text scale factor and reading
/// direction.
typedef FlVariant = ({TargetPlatform platform, Brightness brightness, double scale, TextDirection dir});

/// A contrast pair the theme declares below its threshold (ADR 0014): in
/// [brightness], a [foreground] text on the [background] (layers from top to
/// bottom, the last one opaque) measures at least [ratio]. A
/// `textContrastGuideline` failure that only involves such pairs becomes a
/// report warning, never a silent pass.
typedef FlContrastAllowance = ({
  Brightness brightness,
  Color foreground,
  List<Color> background,
  double ratio,
  String reason,
});

/// The stable name of a [FlVariant].
extension FlVariantId on FlVariant {
  /// `<platform>.<brightness>.<scale>.<direction>`, for example
  /// `ios.light.1.0.ltr`: the name of the test, the rendered PNG, the golden
  /// and the entry in `report.json`.
  String get id => '${platform.name.toLowerCase()}.${brightness.name}.${scale.toStringAsFixed(1)}.${dir.name}';
}

/// The 16 variants `fliinVerify` renders by default: iOS and Android, light
/// and dark, text at 1× and 2×, LTR and RTL.
final List<FlVariant> fliinMatrix = [
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android])
    for (final brightness in Brightness.values)
      for (final scale in [1.0, 2.0])
        for (final dir in [TextDirection.ltr, TextDirection.rtl])
          (platform: platform, brightness: brightness, scale: scale, dir: dir),
];

/// Declares one test per variant, then a "contact sheet and report" test.
///
/// Variant tests do not fail on a verdict: the verdict is in `report.json`,
/// which the CLI (exit codes) and CI read.
///
/// With [goldens], each render is compared pixel by pixel to
/// `<goldens>/<variant>.png` and the difference goes into `golden.diffPct`
/// (in %, null if the reference is missing); `flutter test --update-goldens`
/// rewrites the references. The difference stays informational: it does not
/// change `status`.
///
/// With [settle], each variant advances the clock by this duration, in 16 ms
/// frames, before the capture: an entry that opens an overlay through its
/// controller renders it open and at rest. The duration is bounded, so that an
/// endlessly spinning indicator does not block the render, and the result
/// depends only on it.
///
/// With [contrastExceptions], a text contrast failure where every node has the
/// colors of an exception for the rendered appearance, at no less than its
/// declared ratio, goes into the variant's `warnings` instead of `a11y`.
///
/// [logicalSize] is the render size; [platformSizes] overrides it for a
/// platform: a full screen renders at the size of an iPhone and of an Android
/// phone (ADR 0015 §1).
///
/// [onReport] receives the report in the "contact sheet and report" test,
/// right after it is written: a verdict that depends on it only covers the
/// renders of this run, never a `report.json` left on disk.
void fliinVerify({
  required String item,
  required String version,
  required Widget Function(BuildContext context, FlVariant variant) entry,
  String? outDir,
  Size logicalSize = const Size(390, 300),
  Map<TargetPlatform, Size> platformSizes = const {},
  List<FlVariant>? variants,
  String? goldens,
  void Function(Map<String, Object?> report)? onReport,
  Duration? settle,
  List<FlContrastAllowance> contrastExceptions = const [],
}) {
  final out = outDir ?? 'build/fliin/verify/$item';
  final results = <_VariantResult>[];
  final stopwatch = Stopwatch();
  late _Fonts fonts;

  group(item, () {
    setUpAll(() async {
      stopwatch.start();
      Directory(out).createSync(recursive: true);
      fonts = await _loadFonts();
    });

    for (final variant in variants ?? fliinMatrix) {
      testWidgets(variant.id, (tester) async {
        results.add(
          await _renderVariant(
            tester,
            variant,
            entry,
            platformSizes[variant.platform] ?? logicalSize,
            '$out/${variant.id}.png',
            fonts,
            goldens == null ? null : '$goldens/${variant.id}.png',
            settle,
            [
              for (final e in contrastExceptions)
                if (e.brightness == variant.brightness) e,
            ],
          ),
        );
      });
    }

    testWidgets('contact sheet and report', (tester) async {
      final cell = [
        logicalSize,
        ...platformSizes.values,
      ].reduce((a, b) => Size(math.max(a.width, b.width), math.max(a.height, b.height)));
      await tester.runAsync(() => _writeOverview(results, cell, '$out/overview.png'));
      stopwatch.stop();
      final report = {
        'item': item,
        'version': version,
        'flutter': _flutterVersion(),
        'host': Abi.current().toString().replaceAll('_', '-'),
        'fonts': fonts.fingerprints,
        'analyze': {'diagnostics': <Object>[]},
        'variants': [for (final result in results) result.toJson()],
        'summary': _summary(results),
        'warnings': [
          for (final result in results)
            for (final warning in result.warnings) '${result.id}: ${warning.message}',
        ],
        'elapsedMs': stopwatch.elapsedMilliseconds,
      };
      File('$out/report.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
      onReport?.call(report);
    });
  });
}

const double _pixelRatio = 2;

const Duration _frame = Duration(milliseconds: 16);

enum _Status { pass, fail }

typedef _LayoutError = ({String message, String? widget, String? source});

typedef _A11yFailure = ({String guideline, String message});

/// [diffPct]: the share of pixels that differ from [reference], in %, null if
/// the reference is missing.
typedef _Golden = ({String reference, double? diffPct});

final class _VariantResult {
  const _VariantResult({
    required this.id,
    required this.png,
    required this.layoutErrors,
    required this.a11y,
    required this.fontFallback,
    required this.golden,
    this.warnings = const [],
  });

  final String id;
  final String png;
  final List<_LayoutError> layoutErrors;
  final List<_A11yFailure> a11y;
  final bool fontFallback;
  final _Golden? golden;

  /// The contrast failures covered by declared exceptions.
  final List<_A11yFailure> warnings;

  _Status get status => layoutErrors.isEmpty && a11y.isEmpty ? _Status.pass : _Status.fail;

  /// A target pushed out of frame by an overflow escapes the guidelines: the
  /// report says so instead of claiming it passes.
  bool get a11yIncomplete => layoutErrors.isNotEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'png': png,
    'status': status.name,
    'layoutErrors': [
      for (final e in layoutErrors) {'message': e.message, 'widget': e.widget, 'source': e.source},
    ],
    'a11y': [
      for (final f in a11y) {'guideline': f.guideline, 'message': f.message},
    ],
    'golden': switch (golden) {
      null => null,
      (:final reference, :final diffPct) => {'reference': reference, 'diffPct': diffPct, 'informational': true},
    },
    'fontFallback': fontFallback,
    'a11yIncomplete': a11yIncomplete,
    'warnings': [
      for (final w in warnings) {'guideline': w.guideline, 'message': w.message},
    ],
  };
}

Future<_VariantResult> _renderVariant(
  WidgetTester tester,
  FlVariant variant,
  Widget Function(BuildContext, FlVariant) entry,
  Size logicalSize,
  String png,
  _Fonts fonts,
  String? golden,
  Duration? settle,
  List<FlContrastAllowance> allowances,
) async {
  tester.view.physicalSize = logicalSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = variant.platform;
  final semantics = tester.ensureSemantics();
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  final boundary = GlobalKey();
  try {
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            devicePixelRatio: _pixelRatio,
            platformBrightness: variant.brightness,
            textScaler: TextScaler.linear(variant.scale),
          ),
          child: Directionality(
            textDirection: variant.dir,
            child: DefaultTextStyle(
              style: TextStyle(fontFamily: fonts.familyFor(variant), fontFamilyFallback: const [_Fonts.arabicFamily]),
              child: RepaintBoundary(
                key: boundary,
                child: Builder(builder: (context) => entry(context, variant)),
              ),
            ),
          ),
        ),
      );
      // Autofocus takes effect after the first frame: without one more frame, a
      // focused element would be rendered without its ring.
      await tester.pump();
      if (settle != null) {
        for (var elapsed = Duration.zero; elapsed < settle; elapsed += _frame) {
          await tester.pump(_frame);
        }
      }
    } finally {
      FlutterError.onError = originalOnError;
    }

    final a11y = <_A11yFailure>[];
    final warnings = <_A11yFailure>[];
    for (final (name, guideline) in _guidelinesFor(variant)) {
      final evaluation = await guideline.evaluate(tester);
      if (evaluation.passed) continue;
      final failure = (guideline: name, message: evaluation.reason ?? '');
      if (guideline == flTextContrastGuideline && _excused(failure.message, allowances)) {
        warnings.add((guideline: name, message: 'declared contrast exception: ${failure.message}'));
      } else {
        a11y.add(failure);
      }
    }

    final renderBoundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
    final bytes = await tester.runAsync(() async {
      final image = await renderBoundary.toImage(pixelRatio: _pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    _writeIfChanged(png, bytes!);

    return _VariantResult(
      id: variant.id,
      png: png,
      layoutErrors: [for (final details in errors) _parseError(details)],
      a11y: a11y,
      fontFallback: fonts.fallbackFor(variant),
      golden: golden == null ? null : await _compareGolden(tester, bytes, golden),
      warnings: warnings,
    );
  } finally {
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<_Golden> _compareGolden(WidgetTester tester, Uint8List bytes, String reference) async {
  final file = File(reference);
  if (autoUpdateGoldenFiles) {
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
  if (!file.existsSync()) return (reference: reference, diffPct: null);
  final result = await tester.runAsync(() => GoldenFileComparator.compareLists(bytes, file.readAsBytesSync()));
  return (reference: reference, diffPct: result!.diffPercent * 100);
}

final RegExp _contrastFailure = RegExp(
  r'found ([0-9.]+) for a font size[\s\S]*?light - Color\(alpha: ([0-9.]+), red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+)'
  r'[\s\S]*?dark - Color\(alpha: ([0-9.]+), red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+)',
);

/// True when every node `textContrastGuideline` reports has both colors of an
/// exception, within 2/255 per channel, and at least its ratio.
bool _excused(String message, List<FlContrastAllowance> allowances) {
  final failures = _contrastFailure.allMatches(message).toList();
  if (failures.isEmpty || allowances.isEmpty) return false;
  Color read(Match m, int from) => Color.from(
    alpha: double.parse(m[from]!),
    red: double.parse(m[from + 1]!),
    green: double.parse(m[from + 2]!),
    blue: double.parse(m[from + 3]!),
  );
  bool near(Color a, Color b) =>
      [(a.r, b.r), (a.g, b.g), (a.b, b.b)].every((pair) => (pair.$1 - pair.$2).abs() * 255 <= 2);
  return failures.every((m) {
    final found = double.parse(m[1]!);
    final light = read(m, 2), dark = read(m, 6);
    return allowances.any((e) {
      final ground = _flatten(e.background);
      final colors = near(light, e.foreground) && near(dark, ground) || near(dark, e.foreground) && near(light, ground);
      return colors && found >= e.ratio - 0.02;
    });
  });
}

/// [layers] from top to bottom, the last one opaque, rounded to 8 bits.
Color _flatten(List<Color> layers) {
  var (r, g, b) = (0.0, 0.0, 0.0);
  for (final layer in layers.reversed) {
    r = layer.r * 255 * layer.a + r * (1 - layer.a);
    g = layer.g * 255 * layer.a + g * (1 - layer.a);
    b = layer.b * 255 * layer.a + b * (1 - layer.a);
  }
  return Color.fromARGB(255, r.round(), g.round(), b.round());
}

/// The minimum touch target depends on the platform (44 on iOS, 48
/// elsewhere, DESIGN §2.1): applying the Android rule to an iOS variant would
/// wrongly fail it.
List<(String, AccessibilityGuideline)> _guidelinesFor(FlVariant variant) => [
  if (variant.platform == TargetPlatform.iOS)
    ('iOSTapTargetGuideline', iOSTapTargetGuideline)
  else
    ('androidTapTargetGuideline', androidTapTargetGuideline),
  ('labeledTapTargetGuideline', labeledTapTargetGuideline),
  ('textContrastGuideline', flTextContrastGuideline),
];

final RegExp _creator = RegExp(r'The relevant error-causing widget was:\s*\n\s*(.+?)\s*\n(?:[^\n]*?(file:///\S+))?');

_LayoutError _parseError(FlutterErrorDetails details) {
  final match = _creator.firstMatch(details.toString());
  final uri = match?.group(2);
  return (
    message: details.exceptionAsString().split('\n').first,
    widget: match?.group(1),
    source: uri == null ? null : _relativeSource(uri),
  );
}

String _relativeSource(String uri) {
  final location = RegExp(r'^(.*?)(:\d+:\d+)$').firstMatch(uri);
  if (location == null) return uri;
  final path = Uri.parse(location.group(1)!).toFilePath();
  final root = '${Directory.current.path}${Platform.pathSeparator}';
  return '${path.startsWith(root) ? path.substring(root.length) : path}${location.group(2)}';
}

List<String> _summary(List<_VariantResult> results) {
  final failed = results.where((r) => r.status == _Status.fail).toList();
  return [
    '${results.length - failed.length}/${results.length} variants pass',
    for (final r in failed)
      '${r.id}: ${r.layoutErrors.length} layout error(s), ${r.a11y.length} a11y failure(s)'
          '${r.a11yIncomplete ? ', a11y checks incomplete' : ''}',
  ];
}

Future<void> _writeOverview(List<_VariantResult> results, Size thumb, String path) async {
  const columns = 4;
  final rows = math.max(1, (results.length / columns).ceil());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var i = 0; i < results.length; i++) {
    final codec = await ui.instantiateImageCodec(File(results[i].png).readAsBytesSync());
    final frame = await codec.getNextFrame();
    final cell = Offset((i % columns) * thumb.width, (i ~/ columns) * thumb.height) & thumb;
    canvas.drawImageRect(
      frame.image,
      Offset.zero & Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
      (cell.topLeft & Size(frame.image.width / _pixelRatio, frame.image.height / _pixelRatio)).deflate(4),
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (results[i].status == _Status.fail) {
      canvas.drawRect(
        cell.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFE5484D),
      );
    }
    frame.image.dispose();
    codec.dispose();
  }
  final sheet = await recorder.endRecording().toImage((columns * thumb.width).round(), (rows * thumb.height).round());
  final data = await sheet.toByteData(format: ui.ImageByteFormat.png);
  sheet.dispose();
  _writeIfChanged(path, data!.buffer.asUint8List());
}

/// An image identical to the one already on disk is not rewritten: a rerun
/// verification only touches the files that change, and wakes neither
/// fseventsd nor Spotlight for the rest.
void _writeIfChanged(String path, Uint8List bytes) {
  final file = File(path);
  if (file.existsSync() && file.lengthSync() == bytes.length && listEquals(file.readAsBytesSync(), bytes)) return;
  file.writeAsBytesSync(bytes);
}

final class _Fonts {
  const _Fonts({required this.sf, required this.roboto, required this.arabic, required this.fingerprints});

  static const String iosFamily = 'FliinIos';
  static const String androidFamily = 'FliinAndroid';
  static const String arabicFamily = 'FliinArabic';

  final bool sf;
  final bool roboto;
  final bool arabic;

  /// By file name, the 64-bit FNV-1a fingerprint of each loaded font: a
  /// reference rendered with other fonts is not comparable.
  final Map<String, String> fingerprints;

  String familyFor(FlVariant variant) => variant.platform == TargetPlatform.iOS ? iosFamily : androidFamily;

  bool fallbackFor(FlVariant variant) =>
      !(variant.platform == TargetPlatform.iOS ? sf : roboto) || (variant.dir == TextDirection.rtl && !arabic);
}

Future<_Fonts>? _fonts;

Future<_Fonts> _loadFonts() => _fonts ??= () async {
  final sf = [File('/System/Library/Fonts/SFNS.ttf')];
  final materialFonts = _flutterRoot()?.uri.resolve('bin/cache/artifacts/material_fonts/');
  final roboto = [
    for (final weight in ['Regular', 'Medium', 'Bold'])
      if (materialFonts != null) File.fromUri(materialFonts.resolve('Roboto-$weight.ttf')),
  ];
  final fingerprints = <String, String>{};
  final hasSf = await _loadFamily(_Fonts.iosFamily, sf, fingerprints);
  if (!hasSf) await _loadFamily(_Fonts.iosFamily, roboto, fingerprints);
  // The code font (`typography.monospace`): Menlo on iOS, and under Android's
  // generic name `monospace`, which the test does not resolve by itself.
  final menlo = [File('/System/Library/Fonts/Menlo.ttc')];
  for (final family in ['Menlo', 'monospace']) {
    await _loadFamily(family, menlo, fingerprints);
  }
  return _Fonts(
    sf: hasSf,
    roboto: await _loadFamily(_Fonts.androidFamily, roboto, fingerprints),
    arabic: await _loadFamily(_Fonts.arabicFamily, [File('/System/Library/Fonts/SFArabic.ttf')], fingerprints),
    fingerprints: Map.fromEntries(fingerprints.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
  );
}();

Future<bool> _loadFamily(String family, List<File> candidates, Map<String, String> fingerprints) async {
  final present = candidates.where((file) => file.existsSync()).toList();
  if (present.isEmpty) return false;
  final loader = FontLoader(family);
  for (final file in present) {
    final bytes = file.readAsBytesSync();
    fingerprints[file.uri.pathSegments.last] = _fnv1a64(bytes);
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  return true;
}

/// 64-bit FNV-1a, in hexadecimal: dependency-free, enough to notice that a
/// font has changed.
String _fnv1a64(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash = (hash ^ byte) * 0x100000001b3;
  }
  return '${(hash >>> 32).toRadixString(16).padLeft(8, '0')}${(hash & 0xffffffff).toRadixString(16).padLeft(8, '0')}';
}

/// The root of the SDK running the test, walked up from its executable
/// (`…/bin/cache/…`): it provides Roboto and its version.
Directory? _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) return dir;
    dir = dir.parent;
  }
  return null;
}

String? _flutterVersion() {
  final root = _flutterRoot();
  if (root == null) return null;
  final file = File('${root.path}/bin/cache/flutter.version.json');
  if (!file.existsSync()) return null;
  return switch (jsonDecode(file.readAsStringSync())) {
    {'frameworkVersion': final String version} => version,
    _ => null,
  };
}

/// flutter_test's `textContrastGuideline`, measured on the visible part of
/// the text: its paint bounds, inflated by 4 as in flutter_test, then clipped
/// by each ancestor's clip (scrollable, `ClipRect`). A text cut by the edge of
/// a scrollable (under a pinned bottom bar) used to be measured on the bar's
/// pixels; it is now measured on what can be seen of it. A fully hidden text
/// is not measured. On a text whose clip bites into the ink, the text color
/// is the one it declares, and its background is still measured: the top of
/// cut letters does not have enough ink for a pixel to give the text color
/// (WCAG 1.4.3: text color against background, without antialiasing). The
/// rest is flutter_test 3.47's rule as is (`MinimumTextContrastGuideline`,
/// BSD license of The Flutter Authors): thresholds, tolerance, histogram,
/// colors.
const AccessibilityGuideline flTextContrastGuideline = FlVisibleTextContrastGuideline();

/// The rule of [flTextContrastGuideline].
class FlVisibleTextContrastGuideline extends AccessibilityGuideline {
  /// The rule.
  const FlVisibleTextContrastGuideline();

  @override
  String get description => 'Text contrast should follow WCAG guidelines';

  /// Routes and nodes without text are not measured.
  bool shouldSkipNode(SemanticsData data) =>
      data.flagsCollection.scopesRoute || (data.label.trim().isEmpty && data.value.trim().isEmpty);

  /// True when [bounds] extends more than 50 outside the view.
  bool isNodeOffScreen(Rect bounds, ui.FlutterView view) {
    final size = view.physicalSize * view.devicePixelRatio;
    return bounds.top < -50.0 ||
        bounds.left < -50.0 ||
        bounds.bottom > size.height + 50.0 ||
        bounds.right > size.width + 50.0;
  }

  /// 3:1 for large text (18 and above, or 14 and above in bold), 4.5:1
  /// otherwise; 12 when the size is unknown.
  double targetContrastRatio(double? fontSize, {required bool bold}) {
    final size = fontSize ?? 12.0;
    return bold && size >= 14 || size >= 18 ? 3.0 : 4.5;
  }

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final renderView in tester.binding.renderViews) {
      final layer = renderView.debugLayer! as OffsetLayer;
      final root = renderView.owner!.semanticsOwner!.rootSemanticsNode!;
      late ui.Image image;
      final byteData = await tester.binding.runAsync<ByteData?>(() async {
        image = await layer.toImage(renderView.paintBounds, pixelRatio: 1 / renderView.flutterView.devicePixelRatio);
        final data = await image.toByteData();
        image.dispose();
        return data;
      });
      result += await _node(root, tester, image, byteData!, renderView);
    }
    return result;
  }

  Future<Evaluation> _node(
    SemanticsNode node,
    WidgetTester tester,
    ui.Image image,
    ByteData bytes,
    RenderView view,
  ) async {
    var result = const Evaluation.pass();
    if (node.isInvisible ||
        node.isMergedIntoParent ||
        node.flagsCollection.isHidden ||
        node.flagsCollection.isEnabled == ui.Tristate.isFalse) {
      return result;
    }
    final data = node.getSemanticsData();
    final children = <SemanticsNode>[];
    node.visitChildren((child) {
      children.add(child);
      return true;
    });
    for (final child in children) {
      result += await _node(child, tester, image, bytes, view);
    }
    if (shouldSkipNode(data)) return result;
    final text = data.label.isEmpty ? data.value : data.label;
    for (final element in find.text(text).hitTestable().evaluate()) {
      result += await _element(tester, node, element, image, bytes, view);
    }
    return result;
  }

  Future<Evaluation> _element(
    WidgetTester tester,
    SemanticsNode node,
    Element element,
    ui.Image image,
    ByteData bytes,
    RenderView view,
  ) async {
    final box = element.renderObject;
    if (box is! RenderBox) throw StateError('Unexpected renderObject type: $box');
    final global = box.getTransformTo(null);
    var measured = MatrixUtils.transformRect(global, box.paintBounds.inflate(4));
    final root = Matrix4.identity();
    view.applyPaintTransform(view.child!, root);
    root.multiply(global);
    final screen = MatrixUtils.transformRect(root, box.paintBounds);
    var nodeBounds = node.rect;
    for (SemanticsNode? current = node; current != null; current = current.parent) {
      if (current.transform case final transform?) nodeBounds = MatrixUtils.transformRect(transform, nodeBounds);
    }
    final intersection = nodeBounds.intersect(screen);
    if (intersection.width <= 0 || intersection.height <= 0) return const Evaluation.pass();

    // First difference from flutter_test: the measured box is clipped by its
    // ancestors' clips.
    var clip = Rect.largest;
    RenderObject child = box;
    for (var parent = box.parent; parent != null; child = parent, parent = parent.parent) {
      final region = parent.describeApproximatePaintClip(child);
      if (region == null) continue;
      clip = clip.intersect(MatrixUtils.transformRect(parent.getTransformTo(null), region));
      measured = measured.intersect(clip);
      if (measured.width <= 0 || measured.height <= 0) return const Evaluation.pass();
    }
    // The text is cut when the clip bites into its ink, which a script font
    // places outside its box: neither the margin of 4 nor the leading count.
    // Without known ink (a field, a `WidgetSpan`), on its box.
    final reach = MatrixUtils.transformRect(global, box.paintBounds.inflate(_inkMargin(box)));
    final ink = reach.intersect(clip) == reach ? null : await _inkBounds(tester, box);
    final whole = MatrixUtils.transformRect(global, ink ?? box.paintBounds);
    final visible = whole.intersect(clip);
    final cut = visible != whole && visible.width > 0 && visible.height > 0;

    final widget = element.widget;
    final inherited = DefaultTextStyle.of(element).style;
    final (bool bold, double? size) = switch (widget) {
      Text(:final style) => switch (style == null || style.inherit ? inherited.merge(style) : style) {
        final effective => (effective.fontWeight == FontWeight.bold, effective.fontSize),
      },
      EditableText(:final style) => (style.fontWeight == FontWeight.bold, style.fontSize),
      _ => throw StateError('Unexpected widget type: ${widget.runtimeType}'),
    };
    if (isNodeOffScreen(measured, view.flutterView)) return const Evaluation.pass();
    final histogram = _colorsWithin(bytes, measured, image.width, image.height);
    if (histogram.isEmpty) return const Evaluation.pass();
    var (light, dark) = _lightAndDark(histogram);
    // Second difference: of a cut text, sometimes only antialiased pixels
    // remain on screen, not a single fully covered one, and the antialiasing
    // passed for the text color. Its color is then the one it declares,
    // against the worse of two backgrounds: the most frequent color of the
    // margin of 4 around its ink, and that of its visible part, its ink
    // removed, when it covers at least a quarter of it (a highlight, a tight
    // badge, a band the margin does not show). When something is painted over
    // its visible part, the measurement stays that of the pixels.
    final inks = cut && !await _paintedOver(tester, box, visible) ? _declaredInk(box) : null;
    final ring = inks == null ? null : _colorsWithin(bytes, measured, image.width, image.height, except: visible);
    if (inks != null && ring != null && ring.isNotEmpty) {
      final around = _mostFrequent(ring);
      final shownAround = {for (final ink in inks) Color.alphaBlend(ink, around).toARGB32()};
      final under = _colorsWithin(bytes, visible, image.width, image.height);
      final total = under.values.fold(0, (a, b) => a + b);
      under.removeWhere((color, _) => shownAround.contains(color.toARGB32()));
      final behind = under.isEmpty ? null : under.entries.reduce((a, b) => b.value > a.value ? b : a);
      final grounds = {around, if (behind != null && behind.value * 4 >= total) behind.key};
      var worstRatio = double.infinity;
      for (final ground in grounds) {
        for (final ink in inks) {
          final shown = Color.alphaBlend(ink, ground);
          final r = _contrast(shown, ground);
          if (r >= worstRatio) continue;
          worstRatio = r;
          (light, dark) = shown.computeLuminance() > ground.computeLuminance() ? (shown, ground) : (ground, shown);
        }
      }
    }
    final ratio = (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
    final target = targetContrastRatio(size, bold: bold);
    if (ratio - target >= -0.01) return const Evaluation.pass();
    return Evaluation.fail(
      '$node:\n'
      'Expected contrast ratio of at least $target '
      'but found ${ratio.toStringAsFixed(2)} '
      'for a font size of $size.\n'
      'The computed colors was:\n'
      'light - $light, dark - $dark\n'
      'See also: '
      'https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html',
    );
  }
}

Color _mostFrequent(Map<Color, int> histogram) => histogram.entries.reduce((a, b) => b.value > a.value ? b : a).key;

double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance() + 0.05, b.computeLuminance() + 0.05);
  return x > y ? x / y : y / x;
}

/// How far a text's ink can extend outside its box.
double _inkMargin(RenderBox box) => math.max(32.0, box.size.height).ceilToDouble();

/// The ink of the text of [box] in its frame: the paragraph repainted alone,
/// outside any clip, and bounded to its non-transparent pixels. Null for a
/// field, a text with a `WidgetSpan` or without ink.
Future<Rect?> _inkBounds(WidgetTester tester, RenderBox box) async {
  if (box is! RenderParagraph || !box.text.visitChildren((span) => span is! PlaceholderSpan)) return null;
  final painter = TextPainter(
    text: box.text,
    textAlign: box.textAlign,
    textDirection: box.textDirection,
    textScaler: box.textScaler,
    maxLines: box.maxLines,
    ellipsis: box.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: box.locale,
    strutStyle: box.strutStyle,
    textWidthBasis: box.textWidthBasis,
    textHeightBehavior: box.textHeightBehavior,
  );
  final widthMatters = box.softWrap || box.overflow == TextOverflow.ellipsis;
  painter.layout(
    minWidth: box.constraints.minWidth,
    maxWidth: widthMatters ? box.constraints.maxWidth : double.infinity,
  );
  final margin = _inkMargin(box);
  final width = (box.size.width + 2 * margin).ceil();
  final height = (box.size.height + 2 * margin).ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset(margin, margin));
  painter.dispose();
  final picture = recorder.endRecording();
  final data = await tester.binding.runAsync(() async {
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData();
    image.dispose();
    return bytes;
  });
  picture.dispose();
  if (data == null) return null;
  var (left, top, right, bottom) = (width, height, -1, -1);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (data.getUint8((y * width + x) * 4 + 3) == 0) continue;
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }
  }
  if (right < 0) return null;
  return Rect.fromLTRB(left - margin, top - margin, right + 1 - margin, bottom + 1 - margin);
}

/// True when something is painted over [visible], the visible part of the
/// text of [box]: a sibling painted after it (in a `Stack`, an `Overlay`,
/// `FlScrollShadow`'s shadow) that covers that part and paints something, an
/// ancestor's foreground decoration, or an ancestor's `foregroundPainter` when
/// it draws on that part (`GlowingOverscrollIndicator`'s draws nothing at
/// rest). The paint order is assumed to be the children's order.
Future<bool> _paintedOver(WidgetTester tester, RenderBox box, Rect visible) async {
  // A switched-off sibling (zero opacity, offstage) paints nothing; wrappers
  // that paint nothing themselves are traversed. Everything else counts.
  bool paints(RenderObject node) => switch (node) {
    RenderOpacity(:final opacity) when opacity == 0 => false,
    RenderAnimatedOpacityMixin(:final opacity) when opacity.value == 0 => false,
    RenderOffstage(:final offstage) when offstage => false,
    RenderBox(:final hasSize) when !hasSize => false,
    RenderIgnorePointer(:final child?) ||
    RenderAbsorbPointer(:final child?) ||
    RenderSemanticsAnnotations(:final child?) ||
    RenderExcludeSemantics(:final child?) ||
    RenderRepaintBoundary(:final child?) => paints(child),
    _ => true,
  };
  RenderObject child = box;
  for (var parent = box.parent; parent != null; child = parent, parent = parent.parent) {
    if (parent is RenderDecoratedBox && parent.position == DecorationPosition.foreground) return true;
    if (parent is RenderCustomPaint && parent.foregroundPainter != null) {
      if (await _drawsOn(tester, parent, parent.foregroundPainter!, visible)) return true;
    }
    var after = false;
    var over = false;
    final path = child;
    parent.visitChildren((sibling) {
      if (identical(sibling, path)) {
        after = true;
      } else if (after && !over && paints(sibling)) {
        over = MatrixUtils.transformRect(sibling.getTransformTo(null), sibling.paintBounds).overlaps(visible);
      }
    });
    if (over) return true;
  }
  return false;
}

/// True when [painter], painted alone in place of [owner], puts at least one
/// non-transparent pixel in [visible].
Future<bool> _drawsOn(WidgetTester tester, RenderCustomPaint owner, CustomPainter painter, Rect visible) async {
  final local = MatrixUtils.transformRect(Matrix4.tryInvert(owner.getTransformTo(null))!, visible);
  final area = (Offset.zero & owner.size).intersect(local);
  if (area.width <= 0 || area.height <= 0) return false;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(-area.left.floorToDouble(), -area.top.floorToDouble());
  painter.paint(canvas, owner.size);
  final picture = recorder.endRecording();
  final width = (area.right.ceil() - area.left.floor()).clamp(1, 1 << 14);
  final height = (area.bottom.ceil() - area.top.floor()).clamp(1, 1 << 14);
  final data = await tester.binding.runAsync(() async {
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData();
    image.dispose();
    return bytes;
  });
  picture.dispose();
  if (data == null) return true;
  for (var i = 3; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) != 0) return true;
  }
  return false;
}

/// The colors the text of [box] declares, one per text span; null when one
/// cannot be read from the style (a `foreground`, no color) or an ancestor
/// layer transforms it (opacity, color filter, mask, image filter).
List<Color>? _declaredInk(RenderBox box) {
  RenderObject? found;
  void search(RenderObject node) {
    if (found != null) return;
    if (node is RenderParagraph || node is RenderEditable) {
      found = node;
    } else {
      node.visitChildren(search);
    }
  }

  search(box);
  final InlineSpan? text = switch (found) {
    RenderParagraph(:final text) => text,
    RenderEditable(:final text) => text,
    _ => null,
  };
  if (text == null) return null;
  // An opacity above may also blend the measured background: the text color
  // cannot be derived exactly from it, the measurement stays that of the
  // pixels. `Flow` and `ListWheelScrollView` push their children's opacity
  // without keeping it in their `debugLayer`.
  for (RenderObject? node = found; node != null; node = node.parent) {
    if (node is RenderFlow || node is RenderListWheelViewport && node.overAndUnderCenterOpacity < 1) return null;
    switch (node.debugLayer) {
      case OpacityLayer() || ColorFilterLayer() || ShaderMaskLayer() || ImageFilterLayer():
        return null;
      default:
    }
  }
  final inks = <Color>{};
  var known = true;
  void collect(InlineSpan span, Color? inherited) {
    final style = span.style;
    if (style?.foreground != null) known = false;
    final color = style?.color ?? inherited;
    if (span is TextSpan) {
      if ((span.text ?? '').trim().isNotEmpty) {
        if (color == null) {
          known = false;
        } else {
          inks.add(color);
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        collect(child, color);
      }
    }
  }

  collect(text, null);
  return known && inks.isNotEmpty ? inks.toList() : null;
}

/// The most frequent light and dark colors, on either side of the average
/// lightness (flutter_test's `_ContrastReport`).
(Color, Color) _lightAndDark(Map<Color, int> histogram) {
  var total = 0.0;
  var count = 0;
  for (final MapEntry(key: color, value: n) in histogram.entries) {
    total += HSLColor.fromColor(color).lightness * n;
    count += n;
  }
  final average = total / count;
  MapEntry<Color, int>? light;
  MapEntry<Color, int>? dark;
  for (final entry in histogram.entries) {
    if (HSLColor.fromColor(entry.key).lightness <= average) {
      if (entry.value > (dark?.value ?? 0)) dark = entry;
    } else if (entry.value > (light?.value ?? 0)) {
      light = entry;
    }
  }
  return (light?.key ?? dark!.key, dark?.key ?? light!.key);
}

/// The histogram of the pixels of [bounds] in the RGBA image [data]
/// (flutter_test's `_colorsWithinRect`, each pixel judged at its center),
/// without those of [except].
Map<Color, int> _colorsWithin(ByteData data, Rect bounds, int width, int height, {Rect? except}) {
  final rect = bounds.intersect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  final counts = <int, int>{};
  // A pixel counts when its center is in [bounds]: an edge at 737.5 (a clip
  // on a half pixel) leaves out row 737, the rest of which is outside the
  // clip, where a bar paints its hairline.
  for (var x = (rect.left - 0.5).ceil(); x < (rect.right - 0.5).ceil(); x++) {
    for (var y = (rect.top - 0.5).ceil(); y < (rect.bottom - 0.5).ceil(); y++) {
      if (except != null && x + 1 > except.left && x < except.right && y + 1 > except.top && y < except.bottom) {
        continue;
      }
      counts.update(data.getUint32((y * width + x) * 4), (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return counts.map((rgba, n) => MapEntry(Color((rgba << 24) | (rgba >> 8) & 0xFFFFFFFF), n));
}
