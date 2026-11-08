# fliin

Copy-paste Flutter components and screens. `fliin` installs them as source
files in your app, adapts them to your package and class prefix, checks them
on 16 variants (iOS and Android, light and dark, text at 1.0× and 2.0×, left to
right and right to left), and updates them with a three-way merge that keeps
your local changes.

![The switch page of fliin.dev, with the live Flutter widget](https://fliin.dev/readme/component.png)

One preset code, made on https://fliin.dev/theme, shapes colors, radii, fonts
and spacing across every widget; `fliin theme --preset <code>` applies it, and
every color pair passes the contrast check in light and dark:

![The theme page of fliin.dev](https://fliin.dev/readme/theme.png)

```bash
dart pub global activate fliin

fliin create my_app            # a Flutter app with Fliin set up
cd my_app
fliin search "primary action button"
fliin add button
fliin verify button
fliin update
```

In an existing app, `fliin init` sets Fliin up instead of `fliin create`.

![fliin create, fliin add button and fliin verify button in a terminal](https://fliin.dev/readme/terminal.png)

`fliin verify` renders each item on the 16 variants and fails when one of them
breaks:

![The 16 variants of the button rendered by fliin verify](https://fliin.dev/readme/verify.png)

- Components, `core/` and the icons are free, under the MIT license.
- Blocks and screens are part of Fliin Pro: `fliin login` with your license
  key, then `fliin add` installs them. See https://fliin.dev/pro.
- `fliin mcp` runs a local MCP server, so that coding agents can search items
  by intent and install them.

Every download is checked against a signed index. Nothing leaves your machine
but anonymous GET requests for registry paths, plus your license key, sent to
the Pro registry only.

Documentation: https://fliin.dev
