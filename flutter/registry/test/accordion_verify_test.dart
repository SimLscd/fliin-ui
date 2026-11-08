import 'package:fliin_ui/components/accordion/fl_accordion.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

List<FlAccordionItem<String>> _items(bool rtl, {required bool disabled}) => [
  FlAccordionItem(
    value: 'a',
    title: tr(rtl, 'How do I order?', 'كيف أطلب؟'),
    content: Text(tr(rtl, 'Add to cart, then pay.', 'أضف إلى السلة ثم ادفع.')),
  ),
  FlAccordionItem(
    value: 'b',
    title: tr(rtl, 'Payment methods', 'طرق الدفع'),
    content: Text(tr(rtl, 'Card, Apple Pay and PayPal.', 'البطاقة وApple Pay وPayPal.')),
  ),
  FlAccordionItem(
    value: 'c',
    title: tr(rtl, 'Shipping fees', 'رسوم الشحن'),
    content: Text(tr(rtl, 'Free from €50.', 'مجانية من 50 يورو.')),
    enabled: !disabled,
  ),
];

/// Un accordéon sans fond, la deuxième section ouverte et la troisième
/// désactivée, puis un accordéon sur la surface, la première ouverte.
Widget _accordions(BuildContext context, {required bool rtl}) => columnPage(context, [
  FlAccordion<String>(initialExpanded: const {'b'}, items: _items(rtl, disabled: true)),
  SizedBox(height: FlScope.of(context).space.lg),
  FlAccordion<String>(
    variant: FlAccordionVariant.surface,
    initialExpanded: const {'a'},
    items: _items(rtl, disabled: false),
  ),
]);

void main() => verifyItem(
  item: 'accordion',
  testFile: 'test/accordion_verify_test.dart',
  size: const Size(390, 1600),
  settle: const Duration(milliseconds: 600),
  showcase: _accordions,
);
