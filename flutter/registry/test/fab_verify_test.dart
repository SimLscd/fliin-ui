import 'package:fliin_ui/components/fab/fl_fab.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les quatre variantes, les trois tailles, la forme étendue et l'état
/// désactivé, puis un groupe ouvert en cadran et un autre en menu, chacun dans sa moitié
/// du reste de la page : le voile ne couvre que son parent.
Widget _fabs(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  Widget row(List<Widget> children) => Wrap(
    spacing: theme.space.lg,
    runSpacing: theme.space.lg,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
  final add = tr(rtl, 'Ajouter', 'إضافة');
  final write = tr(rtl, 'Écrire', 'كتابة');
  return ColoredBox(
    color: theme.colors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.all(theme.space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.lg,
            children: [
              row([
                FlFab(label: add, icon: FlIcon(FlIcons.plus), onPressed: () {}),
                FlFab(
                  label: tr(rtl, 'Rechercher', 'بحث'),
                  icon: FlIcon(FlIcons.magnifier),
                  variant: FlFabVariant.secondary,
                  onPressed: () {},
                ),
                FlFab(
                  label: tr(rtl, 'Haut de page', 'العودة إلى الأعلى'),
                  icon: FlIcon(FlIcons.arrowUp),
                  variant: FlFabVariant.surface,
                  onPressed: () {},
                ),
                FlFab(
                  label: tr(rtl, 'Supprimer', 'حذف'),
                  icon: FlIcon(FlIcons.trashBin),
                  variant: FlFabVariant.danger,
                  onPressed: () {},
                ),
              ]),
              row([
                for (final size in FlFabSize.values)
                  FlFab(label: add, icon: FlIcon(FlIcons.plus), size: size, onPressed: () {}),
              ]),
              row([
                FlFab(label: write, icon: FlIcon(FlIcons.pencil), extended: true, onPressed: () {}),
                FlFab(
                  label: tr(rtl, 'Envoyer', 'إرسال'),
                  icon: FlIcon(FlIcons.paperPlane),
                  extended: true,
                  variant: FlFabVariant.surface,
                  size: FlFabSize.sm,
                  onPressed: () {},
                ),
              ]),
              row([
                FlFab(label: add, icon: FlIcon(FlIcons.plus), onPressed: null),
                FlFab(label: write, icon: FlIcon(FlIcons.pencil), extended: true, onPressed: null),
              ]),
            ],
          ),
        ),
        for (final layout in FlFabLayout.values)
          Expanded(
            child: Stack(
              children: [
                FlFabGroup(
                  label: tr(rtl, 'Créer', 'إنشاء'),
                  barrierLabel: tr(rtl, 'Fermer', 'إغلاق'),
                  icon: FlIcon(FlIcons.plus),
                  open: true,
                  layout: layout,
                  placement: layout == FlFabLayout.dial ? FlFabPlacement.bottomEnd : FlFabPlacement.bottomStart,
                  actions: [
                    FlFabAction(label: tr(rtl, 'Événement', 'حدث'), icon: FlIcon(FlIcons.calendar), onPressed: () {}),
                    FlFabAction(label: tr(rtl, 'Message', 'رسالة'), icon: FlIcon(FlIcons.envelope), onPressed: () {}),
                    FlFabAction(label: tr(rtl, 'Note', 'ملاحظة'), icon: FlIcon(FlIcons.pencil), onPressed: () {}),
                    FlFabAction(
                      label: tr(rtl, 'Vider les brouillons', 'إفراغ المسودات'),
                      icon: FlIcon(FlIcons.trashBin),
                      destructive: true,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

void main() => verifyItem(
  item: 'fab',
  testFile: 'test/fab_verify_test.dart',
  size: const Size(390, 1040),
  settle: overlaySettle,
  showcase: _fabs,
);
