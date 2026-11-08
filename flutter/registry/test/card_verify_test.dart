import 'package:fliin_ui/components/card/fl_card.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les quatre variantes, la première avec un en-tête, puis une carte
/// horizontale avec média et coin (`trailing`), et une carte au média bleed.
Widget _cards(BuildContext context, {required bool rtl}) => columnPage(context, [
  for (final (variant, title, description, header) in [
    (
      FlSurfaceVariant.primary,
      tr(rtl, 'Living room sofa', 'أريكة غرفة المعيشة'),
      tr(rtl, 'Delivered within ten days.', 'التوصيل خلال عشرة أيام.'),
      true,
    ),
    (
      FlSurfaceVariant.secondary,
      tr(rtl, 'Next invoice', 'الفاتورة القادمة'),
      tr(rtl, 'March 3, €12.', 'في 3 مارس، 12 يورو.'),
      false,
    ),
    (
      FlSurfaceVariant.tertiary,
      tr(rtl, 'Payment method', 'وسيلة الدفع'),
      tr(rtl, 'Card ending in 4829.', 'بطاقة تنتهي بـ 4829.'),
      false,
    ),
    (
      FlSurfaceVariant.transparent,
      tr(rtl, 'History', 'السجل'),
      tr(rtl, 'Three orders this year.', 'ثلاثة طلبات هذا العام.'),
      false,
    ),
  ])
    FlCard(
      variant: variant,
      children: [
        if (header)
          FlCardHeader(
            children: [
              SizedBox.square(
                dimension: 24,
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: FlScope.of(context).colors.accent, shape: const CircleBorder()),
                ),
              ),
            ],
          ),
        FlCardBody(children: [FlCardTitle(title), FlCardDescription(description)]),
      ],
    ),
  FlCard(
    axis: Axis.horizontal,
    media: FlCardMedia(width: 72, height: 72, child: ColoredBox(color: FlScope.of(context).colors.accentSoft)),
    trailing: SizedBox.square(
      dimension: FlScope.of(context).size.closeButton,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: FlScope.of(context).colors.accent, shape: const CircleBorder()),
      ),
    ),
    children: [
      FlCardBody(
        children: [
          FlCardTitle(tr(rtl, 'Become a creator', 'كن صانع محتوى')),
          FlCardDescription(tr(rtl, 'Earn credits.', 'اكسب رصيدًا.')),
        ],
      ),
    ],
  ),
  FlCard(
    media: FlCardMedia(bleed: true, height: 64, child: ColoredBox(color: FlScope.of(context).colors.successSoft)),
    children: [
      FlCardBody(
        children: [
          FlCardTitle(tr(rtl, 'Lakeside cabin', 'كوخ على البحيرة')),
          FlCardDescription(tr(rtl, 'Two nights.', 'ليلتان.')),
        ],
      ),
    ],
  ),
]);

void main() =>
    verifyItem(item: 'card', testFile: 'test/card_verify_test.dart', size: const Size(390, 2600), showcase: _cards);
