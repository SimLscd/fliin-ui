/// Les codes de sortie du CLI (DESIGN.md §4.5, ADR §2 et constat 10).
enum ExitCode {
  ok(0),
  failure(1),
  analysis(2),

  /// Le SDK, le registre ou un fichier du projet empêche de travailler, dont
  /// un Flutter qui ne convient pas (`verify`, `update`, `diff`), ou dont
  /// seul il écarte une version plus récente (`update --check`, `diff`).
  environment(3),
  confirmation(4),
  integrity(5),

  /// `fliin update --check` et `fliin diff` : une version plus récente
  /// existe.
  updateAvailable(6),

  /// `fliin remove` : un autre élément installé dépend de celui à retirer.
  hasDependents(7),

  /// Un élément Pro sans clé de licence, ou une clé que l'hôte Pro refuse
  /// (ADR 0020 §5).
  license(8);

  const ExitCode(this.code);

  final int code;
}
