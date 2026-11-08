import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Le canevas d'une grille de [count] téléphones, [columns] par rangée :
/// 390 × 844 sur iOS, 412 × 915 sur Android.
({Size ios, Size android}) phoneGridSize(int count, int columns) {
  final rows = (count / columns).ceil();
  return (ios: Size(columns * 390, rows * 844), android: Size(columns * 412, rows * 915));
}

/// [count] écrans côte à côte, [columns] par rangée, chacun dans un
/// téléphone de la plateforme de la variante, avec sa zone sûre, en
/// français ou en arabe, sous l'`Overlay` qu'une app fournit (un champ
/// focalisé y pose sa sélection) : la forme de `verify.entry` d'un écran.
Widget phoneGrid(
  BuildContext context, {
  required bool rtl,
  required int count,
  required int columns,
  required Widget Function(int index) screen,
}) {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final canvas = MediaQuery.sizeOf(context);
  final rows = (count / columns).ceil();
  final size = Size(canvas.width / columns, canvas.height / rows);
  final safe = ios ? const EdgeInsets.only(top: 47, bottom: 34) : const EdgeInsets.only(top: 24, bottom: 16);
  Widget phone(int index) => SizedBox.fromSize(
    size: size,
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(size: size, padding: safe, viewPadding: safe),
      child: Localizations(
        locale: Locale(rtl ? 'ar' : 'fr'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: ColoredBox(
            color: FlScope.of(context).colors.surface,
            child: Overlay(initialEntries: [OverlayEntry(builder: (context) => screen(index))]),
          ),
        ),
      ),
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var row = 0; row < rows; row++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = row * columns; i < count && i < (row + 1) * columns; i++) phone(i)],
        ),
    ],
  );
}
