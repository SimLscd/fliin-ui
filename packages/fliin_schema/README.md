# fliin_schema

The data model of [Fliin](https://fliin.dev), in Dart types, with no
dependency on Flutter or `dart:io` in the theme code:

- item manifests, the signed registry index and its pointer;
- the lockfile and `fliin.yaml`;
- DTCG design tokens, the theme solver (OKLCH, WCAG contrast) and presets;
- a three-way merge with the output and rules of `git merge-file --diff3`.

Each document is parsed once, with typed errors that name the JSON path at
fault. The `fliin` CLI is built on this package; most apps need the CLI, not
this package.
