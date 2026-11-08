import 'package:fliin_ui/components/switch_group/fl_switch_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un groupe décrit, un interrupteur allumé, un éteint avec son aide et un
/// désactivé ; puis un groupe invalide, avec son erreur ; puis des réglages
/// sur leurs cartes.
Widget _groups(BuildContext context, {required bool rtl}) => Localizations(
  locale: Locale(rtl ? 'ar' : 'en'),
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: Directionality(
    textDirection: Directionality.of(context),
    child: Builder(
      builder: (context) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Padding(
          padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: FlScope.of(context).space.xl,
            children: [
              FlSwitchGroup(
                label: tr(rtl, 'Alerts', 'التنبيهات'),
                description: tr(rtl, 'For each message received', 'لكل رسالة واردة'),
                options: [
                  FlSwitchGroupOption(value: true, onChanged: (_) {}, label: tr(rtl, 'Sounds', 'الأصوات')),
                  FlSwitchGroupOption(
                    value: false,
                    onChanged: (_) {},
                    label: tr(rtl, 'Badges', 'الشارات'),
                    description: tr(rtl, 'On the app icon', 'على أيقونة التطبيق'),
                  ),
                  FlSwitchGroupOption(value: true, onChanged: null, label: tr(rtl, 'Previews', 'المعاينات')),
                ],
              ),
              FlSwitchGroup(
                label: tr(rtl, 'Syncing', 'المزامنة'),
                invalid: true,
                error: tr(rtl, 'Turn on at least one option', 'فعّل خيارًا واحدًا على الأقل'),
                options: [
                  FlSwitchGroupOption(value: false, onChanged: (_) {}, label: tr(rtl, 'Photos', 'الصور')),
                  FlSwitchGroupOption(value: false, onChanged: (_) {}, label: tr(rtl, 'Contacts', 'جهات الاتصال')),
                ],
              ),
              FlSwitchGroup(
                label: tr(rtl, 'Privacy', 'الخصوصية'),
                framed: true,
                options: [
                  FlSwitchGroupOption(
                    value: true,
                    onChanged: (_) {},
                    label: tr(rtl, 'Public profile', 'ملف عام'),
                    description: tr(rtl, 'Visible to everyone', 'مرئي للجميع'),
                  ),
                  FlSwitchGroupOption(value: false, onChanged: (_) {}, label: tr(rtl, 'Online status', 'الحالة')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() => verifyItem(
  item: 'switch-group',
  testFile: 'test/switch_group_verify_test.dart',
  size: const Size(390, 1800),
  showcase: _groups,
);
