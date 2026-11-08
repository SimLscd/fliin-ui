# Suite de conformité DTCG, format 2025.10

Copie du dossier `test-suite/tests/2025.10/format/` du dépôt
`https://github.com/design-tokens/community-group`, commit
`882ebd6716abef9a46d8ef5fb12e82009d6cee2e` (2026-09-08). 220 cas : 93
positifs, 127 négatifs, décrits par `format/manifest.json`.

Licence : W3C 3-clause BSD (`LICENSE`), celle que `LICENSE.md` du dépôt
d'origine donne pour les suites de tests. Aucun fichier n'est modifié.

`format-expected-errors.json` n'est pas copié : il est à Fliin. Il donne,
pour chaque cas négatif, le type de `TokenError` que le parseur doit lever
(ADR 0003 §4). Le manifeste n'a pas cette information.

Pour mettre à jour : recopier le dossier, noter le commit ici, relancer
`dart test test/dtcg_conformance_test.dart`.
