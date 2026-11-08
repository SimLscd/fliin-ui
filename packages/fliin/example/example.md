# From a new app to an update

`fliin` is a command-line tool: you run it in your Flutter app, it copies the
source of each item into your project. You need Flutter 3.47 or later.

```sh
dart pub global activate fliin
```

## Create an app and add a component

```sh
fliin create my_app      # flutter create, fliin init, and a main.dart with the scope in place
cd my_app
fliin search "a button for the main action"
fliin add button         # copies button, spinner and core into lib/ui/fliin/
```

`add` prints the import and a line to paste. The button is now your code:

```dart
import 'package:my_app/ui/fliin/components/button/fl_button.dart';

FlButton(label: 'Save', onPressed: () {})
```

In an app you already have, run `fliin init` instead of `fliin create`, then
wrap your screens in the scope:

```dart
import 'package:my_app/ui/fliin/core/fliin.dart';

MaterialApp(
  builder: (context, child) => FlScope(
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
)
```

## Check it on 16 variants

```sh
fliin verify button
```

`verify` renders the item inside your app on iOS and Android, light and dark,
text at 1.0× and 2.0×, left to right and right to left, and writes the 16
renders and a `report.json` under `build/fliin/verify/button/`.

## Theme it

```sh
fliin theme --primary "#7C3AED"   # adjusts the palette until every pair passes WCAG AA
fliin theme --preset <code>       # or a preset built on https://fliin.dev/theme
```

## Update it without losing your edits

Change `lib/ui/fliin/components/button/fl_button.dart` as you like, then:

```sh
fliin update --check   # exits 6 when a newer version is published
fliin diff button      # what changed upstream
fliin update           # three-way merge: your edits stay, upstream fixes come in
```

A conflict goes to `fl_button.dart.fliin-new` next to your file instead of
breaking the build. Resolve it, delete the `.fliin-new` file, and
`fliin status` sees the item as up to date.

## Let your agent use it

```sh
fliin agents           # writes the MCP config for Claude Code, Cursor, Codex…
```

`fliin mcp` is a local MCP server: your agent searches items by intent, reads
their API, and asks you to pick between candidates on a local page.

Documentation: https://fliin.dev
