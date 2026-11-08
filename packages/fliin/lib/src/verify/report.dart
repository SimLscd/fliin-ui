import '../commands/exit_code.dart';
import '../project/environment_failure.dart';

enum VariantStatus { pass, fail }

typedef VariantResult = ({
  String id,
  VariantStatus status,
  double? goldenDiffPct,
});

/// Au-delà, `--strict` fait échouer (DESIGN.md §4.5).
const goldenTolerancePct = 2.0;

/// `report.json` tel que le harnais l'écrit (DESIGN.md §4.5) : le document
/// entier pour `--json`, et ce que le verdict en lit.
final class VerifyReport {
  const VerifyReport._(this.json, this.variants, this.summary, this.warnings);

  static VerifyReport parse(Object? json) {
    if (json case {
      'variants': final List<Object?> variants,
      'summary': final List<Object?> summary,
    }) {
      return VerifyReport._(
        json as Map<String, Object?>,
        [for (final variant in variants) _variant(variant)],
        [for (final line in summary) line as String],
        switch (json['warnings']) {
          final List<Object?> warnings => [for (final w in warnings) w as String],
          _ => const [],
        },
      );
    }
    throw const EnvironmentFailure(
      'report.json: expected variants and summary.',
    );
  }

  final Map<String, Object?> json;
  final List<VariantResult> variants;
  final List<String> summary;

  /// Les échecs de contraste que des exceptions déclarées du thème couvrent :
  /// ils ne font pas échouer, mais `fliin verify` les dit.
  final List<String> warnings;

  /// Les erreurs de layout et l'accessibilité font échouer ; l'écart au golden
  /// seulement avec [strict] (règle 9). Un `flutter test` en échec
  /// ([testExitCode] non nul) ou une variante demandée et non rendue
  /// ([missing]) font échouer aussi : le rapport seul ne les voit pas.
  ExitCode verdict({
    required bool strict,
    int testExitCode = 0,
    List<String> missing = const [],
  }) =>
      testExitCode != 0 ||
          missing.isNotEmpty ||
          variants.any(
            (v) =>
                v.status == VariantStatus.fail ||
                strict && (v.goldenDiffPct ?? 0) > goldenTolerancePct,
          )
      ? ExitCode.failure
      : ExitCode.ok;

  static VariantResult _variant(Object? json) => switch (json) {
    {
      'id': final String id,
      'status': final String status,
      'golden': final Object? golden,
    } =>
      (
        id: id,
        status: VariantStatus.values.byName(status),
        goldenDiffPct: switch (golden) {
          {'diffPct': final num pct} => pct.toDouble(),
          _ => null,
        },
      ),
    _ => throw const EnvironmentFailure('report.json: unreadable variant.'),
  };
}
