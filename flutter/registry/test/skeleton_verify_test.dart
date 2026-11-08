import 'package:fliin_ui/components/skeleton/fl_skeleton.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Immobile, comme en mouvement réduit : le harnais capturerait le reflet à
/// un instant qui dépend des frames.
Widget _still(BuildContext context, Widget child) =>
    MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child);

/// Un profil qui charge (groupe : avatar et deux lignes), une image qui
/// pulse, une ligne immobile, une ligne chargée, puis un paragraphe
/// (`FlSkeletonText`).
Widget _skeletons(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  return _still(
    context,
    columnPage(context, [
      FlSkeletonGroup(
        label: tr(rtl, 'Loading the profile', 'جارٍ تحميل الملف الشخصي'),
        child: Row(
          spacing: theme.space.md,
          children: [
            const FlSkeleton.item(width: 40, height: 40, radius: double.infinity),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: theme.space.xs,
                children: [
                  FlSkeleton.item(width: 128, height: 12, radius: theme.shape.radiusMd),
                  FlSkeleton.item(width: 96, height: 12, radius: theme.shape.radiusMd),
                ],
              ),
            ),
          ],
        ),
      ),
      FlSkeleton(
        label: tr(rtl, 'Loading the image', 'جارٍ تحميل الصورة'),
        variant: FlSkeletonVariant.pulse,
        height: 80,
        radius: theme.shape.radiusLg,
      ),
      FlSkeleton(
        label: tr(rtl, 'Loading the title', 'جارٍ تحميل العنوان'),
        variant: FlSkeletonVariant.none,
        height: 16,
        radius: theme.shape.radiusMd,
      ),
      FlSkeleton(
        label: tr(rtl, 'Loading the name', 'جارٍ تحميل الاسم'),
        loading: false,
        height: 16,
        radius: theme.shape.radiusMd,
        child: showcaseText(context, tr(rtl, 'Ada Lovelace', 'آدا لوفليس')),
      ),
      FlSkeletonText(label: tr(rtl, 'Loading the article', 'جارٍ تحميل المقال')),
    ]),
  );
}

void main() => verifyItem(
  item: 'skeleton',
  testFile: 'test/skeleton_verify_test.dart',
  size: const Size(390, 400),
  showcase: _skeletons,
);
