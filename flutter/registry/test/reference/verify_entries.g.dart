// Généré par packages/fliin/tool/gen_verify_entries.dart depuis items/*.json.
// Ne pas éditer : modifier verify dans le manifeste puis relancer.
// Les entrées sont le Dart des manifestes, tel que fliin verify l'écrit.
// ignore_for_file: type=lint
import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/accordion/fl_accordion.dart';
import 'package:fliin_ui/components/alert/fl_alert.dart';
import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/components/avatar_group/fl_avatar_group.dart';
import 'package:fliin_ui/components/badge/fl_badge.dart';
import 'package:fliin_ui/components/breadcrumbs/fl_breadcrumbs.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/button_group/fl_button_group.dart';
import 'package:fliin_ui/components/calendar/fl_calendar.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/card/fl_card.dart';
import 'package:fliin_ui/components/chart/fl_chart.dart';
import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/checkbox_group/fl_checkbox_group.dart';
import 'package:fliin_ui/components/chip/fl_chip.dart';
import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/components/color_area/fl_color_area.dart';
import 'package:fliin_ui/components/color_field/fl_color_field.dart';
import 'package:fliin_ui/components/color_picker/fl_color_picker.dart';
import 'package:fliin_ui/components/color_slider/fl_color_slider.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:fliin_ui/components/combo_box/fl_combo_box.dart';
import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/date_field/fl_date_field.dart';
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/components/date_range_picker/fl_date_range_picker.dart';
import 'package:fliin_ui/components/dialog/fl_dialog.dart';
import 'package:fliin_ui/components/drawer/fl_drawer.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/fieldset/fl_fieldset.dart';
import 'package:fliin_ui/components/input_group/fl_input_group.dart';
import 'package:fliin_ui/components/input_otp/fl_input_otp.dart';
import 'package:fliin_ui/components/kbd/fl_kbd.dart';
import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/menu/fl_menu.dart';
import 'package:fliin_ui/components/meter/fl_meter.dart';
import 'package:fliin_ui/components/number_field/fl_number_field.dart';
import 'package:fliin_ui/components/page/fl_page.dart';
import 'package:fliin_ui/components/page_indicator/fl_page_indicator.dart';
import 'package:fliin_ui/components/pagination/fl_pagination.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:fliin_ui/components/progress/fl_progress.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';
import 'package:fliin_ui/components/scroll_shadow/fl_scroll_shadow.dart';
import 'package:fliin_ui/components/search_field/fl_search_field.dart';
import 'package:fliin_ui/components/section_header/fl_section_header.dart';
import 'package:fliin_ui/components/segmented/fl_segmented.dart';
import 'package:fliin_ui/components/select/fl_select.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/components/skeleton/fl_skeleton.dart';
import 'package:fliin_ui/components/slider/fl_slider.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/components/stepper/fl_stepper.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/components/switch_group/fl_switch_group.dart';
import 'package:fliin_ui/components/tab_bar/fl_tab_bar.dart';
import 'package:fliin_ui/components/table/fl_table.dart';
import 'package:fliin_ui/components/tabs/fl_tabs.dart';
import 'package:fliin_ui/components/tag_group/fl_tag_group.dart';
import 'package:fliin_ui/components/text/fl_text.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/components/time_field/fl_time_field.dart';
import 'package:fliin_ui/components/toast/fl_toast.dart';
import 'package:fliin_ui/components/toggle_button/fl_toggle_button.dart';
import 'package:fliin_ui/components/toolbar/fl_toolbar.dart';
import 'package:fliin_ui/components/tooltip/fl_tooltip.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

/// Ce que `fliin verify` rend pour un élément aux jetons par défaut.
typedef FlReferenceEntry = ({
  String version,
  Size? canvas,
  Map<TargetPlatform, Size> platformCanvas,
  Duration? settle,
  Widget Function(BuildContext context, FlVariant variant) entry,
});

/// Par nom d'élément.
final Map<String, FlReferenceEntry> verifyEntries = {
  'accordion': (
    version: '0.2.5',
    canvas: const Size(390, 1100),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 600),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.xl,
              children: [
                FlAccordion<String>(
                  initialExpanded: const {'b'},
                  items: [
                    FlAccordionItem(
                      value: 'a',
                      leading: FlIcon(FlIcons.shoppingCart),
                      title: (variant.dir == TextDirection.rtl
                          ? 'كيف أطلب؟'
                          : 'How do I order?'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'أضف إلى السلة ثم ادفع.'
                            : 'Add to cart, then pay.'),
                      ),
                    ),
                    FlAccordionItem(
                      value: 'b',
                      leading: FlIcon(FlIcons.lock),
                      title: (variant.dir == TextDirection.rtl
                          ? 'طرق الدفع'
                          : 'Payment methods'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'البطاقة وApple Pay وPayPal.'
                            : 'Card, Apple Pay and PayPal.'),
                      ),
                    ),
                    FlAccordionItem(
                      value: 'c',
                      leading: FlIcon(FlIcons.mapPin),
                      title: (variant.dir == TextDirection.rtl
                          ? 'رسوم الشحن'
                          : 'Shipping fees'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'مجانية من 50 يورو.'
                            : 'Free from €50.'),
                      ),
                      enabled: false,
                    ),
                  ],
                ),
                FlAccordion<String>(
                  variant: FlAccordionVariant.surface,
                  initialExpanded: const {'a'},
                  items: [
                    FlAccordionItem(
                      value: 'a',
                      title: (variant.dir == TextDirection.rtl
                          ? 'كيف أطلب؟'
                          : 'How do I order?'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'أضف إلى السلة ثم ادفع.'
                            : 'Add to cart, then pay.'),
                      ),
                    ),
                    FlAccordionItem(
                      value: 'b',
                      title: (variant.dir == TextDirection.rtl
                          ? 'طرق الدفع'
                          : 'Payment methods'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'البطاقة وApple Pay وPayPal.'
                            : 'Card, Apple Pay and PayPal.'),
                      ),
                    ),
                    FlAccordionItem(
                      value: 'c',
                      title: (variant.dir == TextDirection.rtl
                          ? 'رسوم الشحن'
                          : 'Shipping fees'),
                      content: Text(
                        (variant.dir == TextDirection.rtl
                            ? 'مجانية من 50 يورو.'
                            : 'Free from €50.'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'alert': (
    version: '0.2.5',
    canvas: const Size(390, 1100),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                FlAlert(
                  status: FlAlertStatus.neutral,
                  title: (variant.dir == TextDirection.rtl
                      ? 'ميزات جديدة'
                      : 'New features'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'الوضع الداكن متاح.'
                      : 'Dark mode is available.'),
                ),
                FlAlert(
                  status: FlAlertStatus.accent,
                  title: (variant.dir == TextDirection.rtl
                      ? 'التحديث جاهز'
                      : 'Update ready'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'أعد التشغيل لتثبيته.'
                      : 'Restart to install it.'),
                ),
                FlAlert(
                  status: FlAlertStatus.success,
                  title: (variant.dir == TextDirection.rtl
                      ? 'تم حفظ الملف'
                      : 'Profile saved'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'يراه فريقك.'
                      : 'Your team can see it.'),
                ),
                FlAlert(
                  status: FlAlertStatus.warning,
                  title: (variant.dir == TextDirection.rtl
                      ? 'صيانة مجدولة'
                      : 'Scheduled maintenance'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'الأحد من 2 إلى 4.'
                      : 'Sunday from 2 AM to 4 AM.'),
                ),
                FlAlert(
                  status: FlAlertStatus.danger,
                  title: (variant.dir == TextDirection.rtl
                      ? 'تعذر الاتصال'
                      : 'Can’t connect'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'تحقق من شبكتك.'
                      : 'Check your network.'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'app-bar': (
    version: '0.3.3',
    canvas: const Size(390, 560),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: FlScope.of(context).space.lg,
            children: [
              FlAppBar(
                title: (variant.dir == TextDirection.rtl
                    ? 'الإعدادات'
                    : 'Settings'),
                back: FlAppBarBack(
                  label: (variant.dir == TextDirection.rtl ? 'رجوع' : 'Back'),
                  onPressed: () {},
                ),
                actions: [
                  FlAppBarAction(
                    icon: FlIcon(FlIcons.ellipsis),
                    label: (variant.dir == TextDirection.rtl
                        ? 'المزيد'
                        : 'More'),
                    onPressed: () {},
                  ),
                ],
              ),
              FlAppBar(
                title: (variant.dir == TextDirection.rtl
                    ? 'المنتج'
                    : 'Product'),
                filled: false,
                back: FlAppBarBack(
                  label: (variant.dir == TextDirection.rtl ? 'رجوع' : 'Back'),
                  onPressed: () {},
                ),
                actions: [
                  FlAppBarAction(
                    icon: FlIcon(FlIcons.arrowUpFromSquare),
                    label: (variant.dir == TextDirection.rtl
                        ? 'مشاركة'
                        : 'Share'),
                    onPressed: () {},
                  ),
                  FlAppBarAction(
                    icon: FlIcon(FlIcons.heart),
                    label: (variant.dir == TextDirection.rtl
                        ? 'المفضلة'
                        : 'Favorite'),
                    onPressed: () {},
                  ),
                ],
              ),
              FlAppBar(
                title: (variant.dir == TextDirection.rtl
                    ? 'الملف الشخصي'
                    : 'Profile'),
                titleSize: FlAppBarTitleSize.small,
                back: FlAppBarBack(
                  label: (variant.dir == TextDirection.rtl ? 'رجوع' : 'Back'),
                  onPressed: () {},
                ),
                actions: [
                  FlAppBarAction.text(
                    label: (variant.dir == TextDirection.rtl ? 'حفظ' : 'Save'),
                    onPressed: () {},
                  ),
                ],
              ),
              FlAppBar(
                title: (variant.dir == TextDirection.rtl
                    ? 'الرسائل'
                    : 'Messages'),
                titleSize: FlAppBarTitleSize.large,
                actions: [
                  FlAppBarAction(
                    icon: FlIcon(FlIcons.magnifier),
                    label: (variant.dir == TextDirection.rtl
                        ? 'بحث'
                        : 'Search'),
                    onPressed: () {},
                  ),
                  FlAppBarAction(
                    icon: FlIcon(FlIcons.pencil),
                    label: (variant.dir == TextDirection.rtl ? 'جديد' : 'New'),
                    onPressed: () {},
                  ),
                ],
              ),
              SizedBox(
                height: 160,
                child: CustomScrollView(
                  controller: ScrollController(initialScrollOffset: 200),
                  slivers: [
                    FlSliverAppBar(
                      appBar: FlAppBar(
                        title: (variant.dir == TextDirection.rtl
                            ? 'الرسائل'
                            : 'Messages'),
                        titleSize: FlAppBarTitleSize.large,
                        back: FlAppBarBack(
                          label: (variant.dir == TextDirection.rtl
                              ? 'رجوع'
                              : 'Back'),
                          onPressed: () {},
                        ),
                        actions: [
                          FlAppBarAction(
                            icon: FlIcon(FlIcons.magnifier),
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    SliverList.list(
                      children: [
                        for (var i = 0; i < 12; i++)
                          Padding(
                            padding: EdgeInsetsDirectional.symmetric(
                              horizontal: FlScope.of(context).space.lg,
                              vertical: FlScope.of(context).space.xs,
                            ),
                            child: SizedBox(
                              height: 40,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: FlScope.of(context)
                                      .colors
                                      .surfaceSecondary,
                                  shape: FlContinuousBorder(
                                    radius: FlScope.of(context).shape.radiusMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  'avatar-group': (
    version: '0.2.5',
    canvas: const Size(390, 440),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                for (final s in FlAvatarSize.values.where(
                  (s) => s != FlAvatarSize.xl,
                ))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FlAvatarGroup(
                      avatars: [
                        FlAvatar(
                          initials: (variant.dir == TextDirection.rtl
                              ? 'ج د'
                              : 'JD'),
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'جين دو'
                              : 'Jane Doe'),
                        ),
                        FlAvatar(
                          initials: (variant.dir == TextDirection.rtl
                              ? 'ك و'
                              : 'KW'),
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'كيت ويلسون'
                              : 'Kate Wilson'),
                          color: FlAvatarColor.success,
                        ),
                        FlAvatar(
                          initials: (variant.dir == TextDirection.rtl
                              ? 'إ ت'
                              : 'EC'),
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'إميلي تشن'
                              : 'Emily Chen'),
                          color: FlAvatarColor.warning,
                        ),
                        FlAvatar(
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'ضيف'
                              : 'Guest'),
                          variant: FlAvatarVariant.soft,
                          color: FlAvatarColor.danger,
                        ),
                      ],
                      max: 2,
                      total: 8,
                      size: s,
                      countLabel: (n) => (variant.dir == TextDirection.rtl
                          ? 'و$n آخرين'
                          : 'and $n more'),
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FlAvatarGroup(
                    avatars: [
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'ج د'
                            : 'JD'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'جين دو'
                            : 'Jane Doe'),
                      ),
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'ك و'
                            : 'KW'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'كيت ويلسون'
                            : 'Kate Wilson'),
                        color: FlAvatarColor.success,
                      ),
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'إ ت'
                            : 'EC'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'إميلي تشن'
                            : 'Emily Chen'),
                        color: FlAvatarColor.warning,
                      ),
                      FlAvatar(
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'ضيف'
                            : 'Guest'),
                        variant: FlAvatarVariant.soft,
                        color: FlAvatarColor.danger,
                      ),
                    ],
                    max: 3,
                    overlap: FlAvatarGroupOverlap.ring,
                    countLabel: (n) => (variant.dir == TextDirection.rtl
                        ? 'و$n آخرين'
                        : 'and $n more'),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FlAvatarGroup(
                    avatars: [
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'ج د'
                            : 'JD'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'جين دو'
                            : 'Jane Doe'),
                      ),
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'ك و'
                            : 'KW'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'كيت ويلسون'
                            : 'Kate Wilson'),
                        color: FlAvatarColor.success,
                      ),
                      FlAvatar(
                        initials: (variant.dir == TextDirection.rtl
                            ? 'إ ت'
                            : 'EC'),
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'إميلي تشن'
                            : 'Emily Chen'),
                        color: FlAvatarColor.warning,
                      ),
                      FlAvatar(
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'ضيف'
                            : 'Guest'),
                        variant: FlAvatarVariant.soft,
                        color: FlAvatarColor.danger,
                      ),
                    ],
                    size: FlAvatarSize.sm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'avatar': (
    version: '0.2.5',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.md,
              children: [
                for (final v in FlAvatarVariant.values)
                  Wrap(
                    spacing: FlScope.of(context).space.sm,
                    runSpacing: FlScope.of(context).space.sm,
                    children: [
                      for (final c in FlAvatarColor.values)
                        FlAvatar(
                          initials: (variant.dir == TextDirection.rtl
                              ? 'ج د'
                              : 'JD'),
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'جين دو'
                              : 'Jane Doe'),
                          variant: v,
                          color: c,
                        ),
                    ],
                  ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final s in FlAvatarSize.values)
                      FlAvatar(
                        size: s,
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'ضيف'
                            : 'Guest'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'badge': (
    version: '0.2.4',
    canvas: const Size(390, 420),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                for (final v in FlBadgeVariant.values)
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: FlScope.of(context).space.sm,
                    ),
                    child: Wrap(
                      spacing: FlScope.of(context).space.lg,
                      runSpacing: FlScope.of(context).space.lg,
                      children: [
                        for (final c in FlBadgeColor.values)
                          FlBadge.count(
                            count: 5,
                            semanticLabel: (variant.dir == TextDirection.rtl
                                ? '5 غير مقروءة'
                                : '5 unread'),
                            variant: v,
                            color: c,
                            size: FlBadgeSize.sm,
                            child: Semantics(
                              label: (variant.dir == TextDirection.rtl
                                  ? 'الرسائل'
                                  : 'Messages'),
                              child: SizedBox.square(
                                dimension: FlScope.of(context).space.xs * 10,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: FlScope.of(context).colors.control,
                                    shape: FlContinuousBorder(
                                      radius: FlScope.of(context)
                                          .shape
                                          .radiusXl,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: FlScope.of(context).space.sm,
                  ),
                  child: Wrap(
                    spacing: FlScope.of(context).space.lg,
                    runSpacing: FlScope.of(context).space.lg,
                    children: [
                      for (final s in FlBadgeSize.values)
                        FlBadge.count(
                          count: 120,
                          color: FlBadgeColor.danger,
                          size: s,
                          child: Semantics(
                            label: (variant.dir == TextDirection.rtl
                                ? 'الرسائل'
                                : 'Messages'),
                            child: SizedBox.square(
                              dimension: FlScope.of(context).space.xs * 10,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: FlScope.of(context).colors.control,
                                  shape: FlContinuousBorder(
                                    radius: FlScope.of(context).shape.radiusXl,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: FlScope.of(context).space.sm,
                  ),
                  child: Wrap(
                    spacing: FlScope.of(context).space.lg,
                    runSpacing: FlScope.of(context).space.lg,
                    children: [
                      FlBadge.text(
                        text: (variant.dir == TextDirection.rtl
                            ? 'جديد'
                            : 'New'),
                        color: FlBadgeColor.accent,
                        size: FlBadgeSize.sm,
                        child: Semantics(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الجديد'
                              : 'What’s new'),
                          child: SizedBox.square(
                            dimension: FlScope.of(context).space.xs * 10,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: FlScope.of(context).colors.control,
                                shape: FlContinuousBorder(
                                  radius: FlScope.of(context).shape.radiusXl,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final p in FlBadgePlacement.values)
                        FlBadge.dot(
                          semanticLabel: (variant.dir == TextDirection.rtl
                              ? 'متصل'
                              : 'online'),
                          color: FlBadgeColor.success,
                          placement: p,
                          child: Semantics(
                            label: (variant.dir == TextDirection.rtl
                                ? 'جين'
                                : 'Jane'),
                            child: SizedBox.square(
                              dimension: FlScope.of(context).space.xs * 10,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: FlScope.of(context).colors.control,
                                  shape: FlContinuousBorder(
                                    radius: FlScope.of(context).shape.radiusXl,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'breadcrumbs': (
    version: '0.1.1',
    canvas: const Size(390, 300),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlBreadcrumbs(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'مسار التنقل'
                      : 'Breadcrumbs'),
                  items: [
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الرئيسية'
                          : 'Home'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'المنتجات'
                          : 'Products'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الإلكترونيات'
                          : 'Electronics'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'حاسوب'
                          : 'Computer'),
                      onPressed: () {},
                    ),
                  ],
                ),
                FlBreadcrumbs(
                  items: [
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الرئيسية'
                          : 'Home'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'المنزل والحديقة والأثاث والديكور'
                          : 'Home and garden, furniture and decor'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'أثاث خارجي'
                          : 'Outdoor furniture'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'طقم حديقة من خشب الساج'
                          : 'Oiled solid teak garden lounge set'),
                      onPressed: () {},
                    ),
                  ],
                ),
                FlBreadcrumbs(
                  maxItems: 3,
                  expandLabel: (variant.dir == TextDirection.rtl
                      ? 'عرض المسار كاملا'
                      : 'Show the whole path'),
                  items: [
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الرئيسية'
                          : 'Home'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'المستندات'
                          : 'Documents'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'المشاريع'
                          : 'Projects'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? '٢٠٢٦'
                          : '2026'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'العروض'
                          : 'Quotes'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'العميل أ'
                          : 'Client A'),
                      onPressed: () {},
                    ),
                  ],
                ),
                FlBreadcrumbs(
                  enabled: false,
                  items: [
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الرئيسية'
                          : 'Home'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الإعدادات'
                          : 'Settings'),
                      onPressed: () {},
                    ),
                    FlBreadcrumb(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الحساب'
                          : 'Account'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'button-group': (
    version: '0.1.1',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  children: [
                    for (final look in [
                      FlButtonVariant.primary,
                      FlButtonVariant.tertiary,
                      FlButtonVariant.outline,
                      FlButtonVariant.ghost,
                      FlButtonVariant.danger,
                    ])
                      FlButtonGroup(
                        variant: look,
                        items: [
                          FlButtonGroupItem(
                            label: (variant.dir == TextDirection.rtl
                                ? 'نسخ'
                                : 'Copy'),
                            onPressed: () {},
                          ),
                          FlButtonGroupItem(
                            label: (variant.dir == TextDirection.rtl
                                ? 'لصق'
                                : 'Paste'),
                            onPressed: () {},
                          ),
                          FlButtonGroupItem(
                            label: (variant.dir == TextDirection.rtl
                                ? 'قص'
                                : 'Cut'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    FlButtonGroup(
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'تحرير'
                          : 'Edit'),
                      items: [
                        FlButtonGroupItem.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تعديل'
                              : 'Edit'),
                          icon: FlIcon(FlIcons.pencil),
                          onPressed: () {},
                        ),
                        FlButtonGroupItem.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'مشاركة'
                              : 'Share'),
                          icon: FlIcon(FlIcons.arrowUpFromSquare),
                          onPressed: () {},
                        ),
                        FlButtonGroupItem.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'حذف'
                              : 'Delete'),
                          icon: FlIcon(FlIcons.trashBin),
                          onPressed: null,
                        ),
                      ],
                    ),
                    FlButtonGroup(
                      axis: Axis.vertical,
                      variant: FlButtonVariant.outline,
                      items: [
                        FlButtonGroupItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'السابق'
                              : 'Previous'),
                          leading: FlIcon(FlIcons.chevronLeft),
                          onPressed: () {},
                        ),
                        FlButtonGroupItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'التالي'
                              : 'Next'),
                          trailing: FlIcon(FlIcons.chevronRight),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                FlButtonGroup(
                  expanded: true,
                  items: [
                    FlButtonGroupItem(
                      label: (variant.dir == TextDirection.rtl ? 'يوم' : 'Day'),
                      selected: false,
                      onPressed: () {},
                    ),
                    FlButtonGroupItem(
                      label: (variant.dir == TextDirection.rtl
                          ? 'أسبوع'
                          : 'Week'),
                      selected: true,
                      onPressed: () {},
                    ),
                    FlButtonGroupItem(
                      label: (variant.dir == TextDirection.rtl
                          ? 'شهر'
                          : 'Month'),
                      selected: false,
                      onPressed: () {},
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FlButtonGroup(
                    enabled: false,
                    variant: FlButtonVariant.primary,
                    items: [
                      FlButtonGroupItem(
                        label: (variant.dir == TextDirection.rtl
                            ? 'نسخ'
                            : 'Copy'),
                        onPressed: () {},
                      ),
                      FlButtonGroupItem(
                        label: (variant.dir == TextDirection.rtl
                            ? 'لصق'
                            : 'Paste'),
                        onPressed: () {},
                      ),
                      FlButtonGroupItem(
                        label: (variant.dir == TextDirection.rtl
                            ? 'قص'
                            : 'Cut'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'button': (
    version: '0.2.5',
    canvas: const Size(390, 1200),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'حفظ التغييرات'
                      : 'Save',
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'متابعة'
                      : 'Continue',
                  variant: FlButtonVariant.secondary,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl ? 'إلغاء' : 'Cancel',
                  variant: FlButtonVariant.tertiary,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl ? 'تعديل' : 'Edit',
                  variant: FlButtonVariant.outline,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'معرفة المزيد'
                      : 'Learn more',
                  variant: FlButtonVariant.ghost,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl ? 'حذف' : 'Delete',
                  variant: FlButtonVariant.danger,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl ? 'إزالة' : 'Remove',
                  variant: FlButtonVariant.dangerSoft,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'متابعة'
                      : 'Continue',
                  variant: FlButtonVariant.secondary,
                  statesController: WidgetStatesController({
                    WidgetState.pressed,
                  }),
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl ? 'إزالة' : 'Remove',
                  variant: FlButtonVariant.dangerSoft,
                  statesController: WidgetStatesController({
                    WidgetState.pressed,
                  }),
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'جارٍ الإرسال'
                      : 'Sending',
                  loading: true,
                  onPressed: () {},
                ),
                FlButton(
                  label: variant.dir == TextDirection.rtl
                      ? 'غير متاح'
                      : 'Unavailable',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'calendar': (
    version: '0.2.5',
    canvas: const Size(760, 1300),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Wrap(
              spacing: FlScope.of(context).space.lg,
              runSpacing: FlScope.of(context).space.lg,
              children: [
                SizedBox(
                  width: 320,
                  child: FlCalendar(
                    value: DateTime(2026, 10, 14),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تاريخ الموعد'
                        : 'Appointment date'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlCalendar(
                    value: null,
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    focusedDate: DateTime(2026, 10, 24),
                    minDate: DateTime(2026, 10, 8),
                    maxDate: DateTime(2026, 10, 28),
                    isUnavailable: (day) =>
                        day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday,
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تاريخ التسليم'
                        : 'Delivery date'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlCalendar(
                    value: DateTime(2026, 10, 14),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    defaultYearPickerOpen: true,
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تاريخ الميلاد'
                        : 'Date of birth'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlCalendar(
                    value: DateTime(2026, 10, 14),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    enabled: false,
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'التاريخ'
                        : 'Date'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'card': (
    version: '0.2.3',
    canvas: const Size(390, 900),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                FlCard(
                  variant: FlSurfaceVariant.primary,
                  children: [
                    FlCardHeader(
                      children: [
                        SizedBox.square(
                          dimension: 24,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: FlScope.of(context).colors.accent,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    FlCardBody(
                      children: [
                        FlCardTitle(
                          (variant.dir == TextDirection.rtl
                              ? 'أريكة غرفة المعيشة'
                              : 'Living room sofa'),
                        ),
                        FlCardDescription(
                          (variant.dir == TextDirection.rtl
                              ? 'التوصيل خلال عشرة أيام.'
                              : 'Delivered within ten days.'),
                        ),
                      ],
                    ),
                  ],
                ),
                FlCard(
                  variant: FlSurfaceVariant.secondary,
                  children: [
                    FlCardBody(
                      children: [
                        FlCardTitle(
                          (variant.dir == TextDirection.rtl
                              ? 'الفاتورة القادمة'
                              : 'Next invoice'),
                        ),
                        FlCardDescription(
                          (variant.dir == TextDirection.rtl
                              ? 'في 3 مارس، 12 يورو.'
                              : 'March 3, €12.'),
                        ),
                      ],
                    ),
                  ],
                ),
                FlCard(
                  variant: FlSurfaceVariant.tertiary,
                  children: [
                    FlCardBody(
                      children: [
                        FlCardTitle(
                          (variant.dir == TextDirection.rtl
                              ? 'وسيلة الدفع'
                              : 'Payment method'),
                        ),
                        FlCardDescription(
                          (variant.dir == TextDirection.rtl
                              ? 'بطاقة تنتهي بـ 4829.'
                              : 'Card ending in 4829.'),
                        ),
                      ],
                    ),
                  ],
                ),
                FlCard(
                  variant: FlSurfaceVariant.transparent,
                  children: [
                    FlCardBody(
                      children: [
                        FlCardTitle(
                          (variant.dir == TextDirection.rtl
                              ? 'السجل'
                              : 'History'),
                        ),
                        FlCardDescription(
                          (variant.dir == TextDirection.rtl
                              ? 'ثلاثة طلبات هذا العام.'
                              : 'Three orders this year.'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'chart': (
    version: '0.2.4',
    canvas: const Size(390, 1040),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final days = [
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'ن' : 'M'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الاثنين'
                    : 'Monday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'ث' : 'T'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الثلاثاء'
                    : 'Tuesday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'ر' : 'W'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الأربعاء'
                    : 'Wednesday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'خ' : 'T'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الخميس'
                    : 'Thursday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'ج' : 'F'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الجمعة'
                    : 'Friday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'س' : 'S'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'السبت'
                    : 'Saturday'),
              ),
              FlChartPoint(
                (variant.dir == TextDirection.rtl ? 'ح' : 'S'),
                semanticLabel: (variant.dir == TextDirection.rtl
                    ? 'الأحد'
                    : 'Sunday'),
              ),
            ];
            final spent = FlChartSeries(
              label: (variant.dir == TextDirection.rtl
                  ? 'المصاريف'
                  : 'Spending'),
              values: const [32, 18, 45, 84, 27, 61, 12],
            );
            final before = FlChartSeries(
              label: (variant.dir == TextDirection.rtl
                  ? 'الأسبوع السابق'
                  : 'Previous week'),
              values: const [20, 40, 30, 52, 35, 48, 25],
            );
            return ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.xl,
                  children: [
                    FlChart.bar(
                      points: days,
                      series: [spent],
                      formatValue: (double value) =>
                          (variant.dir == TextDirection.rtl
                          ? '\u2066${value.round()} €\u2069'
                          : '€${value.round()}'),
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'مصاريف الأسبوع'
                          : 'This week’s spending'),
                      plotHeight: 120,
                      initialSelection: 3,
                    ),
                    FlChart.bar(
                      points: days,
                      series: [spent, before],
                      formatValue: (double value) =>
                          (variant.dir == TextDirection.rtl
                          ? '\u2066${value.round()} €\u2069'
                          : '€${value.round()}'),
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'المصاريف اليومية'
                          : 'Spending per day'),
                      plotHeight: 100,
                    ),
                    FlChart.line(
                      points: [
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'يناير' : 'Jan'),
                        ),
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'فبراير' : 'Feb'),
                        ),
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'مارس' : 'Mar'),
                        ),
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'أبريل' : 'Apr'),
                        ),
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'مايو' : 'May'),
                        ),
                        FlChartPoint(
                          (variant.dir == TextDirection.rtl ? 'يونيو' : 'Jun'),
                        ),
                      ],
                      series: [
                        FlChartSeries(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الرصيد'
                              : 'Balance'),
                          values: const [1200, 1450, 1380, 1720, 1650, 1980],
                        ),
                        FlChartSeries(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الهدف'
                              : 'Goal'),
                          values: const [1300, 1400, 1500, 1600, 1700, 1800],
                        ),
                      ],
                      formatValue: (double value) =>
                          (variant.dir == TextDirection.rtl
                          ? '\u2066${value.round()} €\u2069'
                          : '€${value.round()}'),
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'تطور الرصيد'
                          : 'Balance over time'),
                      plotHeight: 100,
                      initialSelection: 4,
                    ),
                    FlChartTable(
                      points: days.take(3).toList(),
                      series: [spent],
                      formatValue: (double value) =>
                          (variant.dir == TextDirection.rtl
                          ? '\u2066${value.round()} €\u2069'
                          : '€${value.round()}'),
                      pointsLabel: (variant.dir == TextDirection.rtl
                          ? 'اليوم'
                          : 'Day'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'checkbox-group': (
    version: '0.2.2',
    canvas: const Size(390, 1040),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: Locale(variant.dir == TextDirection.rtl ? 'ar' : 'en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.xl,
                  children: [
                    FlCheckboxGroup<String>(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الاهتمامات'
                          : 'Interests'),
                      description: (variant.dir == TextDirection.rtl
                          ? 'اختر كل ما يناسبك'
                          : 'Choose everything you like'),
                      value: const {'cuisine'},
                      onChanged: (_) {},
                      options: [
                        FlCheckboxGroupOption(
                          value: 'cuisine',
                          label: (variant.dir == TextDirection.rtl
                              ? 'الطبخ'
                              : 'Cooking'),
                        ),
                        FlCheckboxGroupOption(
                          value: 'voyage',
                          label: (variant.dir == TextDirection.rtl
                              ? 'السفر'
                              : 'Travel'),
                          description: (variant.dir == TextDirection.rtl
                              ? 'رحلات وعروض'
                              : 'Stays and deals'),
                        ),
                        FlCheckboxGroupOption(
                          value: 'sport',
                          label: (variant.dir == TextDirection.rtl
                              ? 'الرياضة'
                              : 'Sports'),
                          disabled: true,
                        ),
                      ],
                    ),
                    FlCheckboxGroup<String>(
                      label: (variant.dir == TextDirection.rtl
                          ? 'التنبيهات'
                          : 'Alerts'),
                      required: true,
                      invalid: true,
                      error: (variant.dir == TextDirection.rtl
                          ? 'اختر قناة واحدة على الأقل'
                          : 'Choose at least one channel'),
                      value: const {},
                      onChanged: (_) {},
                      options: [
                        FlCheckboxGroupOption(
                          value: 'mail',
                          label: (variant.dir == TextDirection.rtl
                              ? 'البريد'
                              : 'Email'),
                        ),
                        FlCheckboxGroupOption(value: 'sms', label: 'SMS'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'checkbox': (
    version: '0.2.3',
    canvas: null,
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                for (final (fr, ar, on, enabled) in [
                  ('Terms accepted', 'قبول الشروط', true, true),
                  ('Newsletter', 'النشرة الإخبارية', false, true),
                  ('Select all', 'تحديد الكل', null, true),
                  ('Required', 'إلزامي', true, false),
                ])
                  Row(
                    spacing: FlScope.of(context).space.md,
                    children: [
                      Expanded(
                        child: Text(
                          variant.dir == TextDirection.rtl ? ar : fr,
                          style: TextStyle(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                        ),
                      ),
                      FlCheckbox(
                        value: on,
                        tristate: true,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                        onChanged: enabled ? (_) {} : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'chip': (
    version: '0.2.3',
    canvas: const Size(390, 1000),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                for (final v in FlChipVariant.values)
                  Wrap(
                    spacing: FlScope.of(context).space.sm,
                    runSpacing: FlScope.of(context).space.sm,
                    children: [
                      for (final c in FlChipColor.values)
                        FlChip(
                          label: (variant.dir == TextDirection.rtl
                              ? const [
                                  'جديد',
                                  'مسودة',
                                  'مدفوع',
                                  'قيد الانتظار',
                                  'مرفوض',
                                ]
                              : const [
                                  'New',
                                  'Draft',
                                  'Paid',
                                  'Pending',
                                  'Declined',
                                ])[c.index],
                          variant: v,
                          color: c,
                          size: FlChipSize.lg,
                        ),
                    ],
                  ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final s in FlChipSize.values)
                      FlChip(
                        label: (variant.dir == TextDirection.rtl
                            ? const [
                                'جديد',
                                'مسودة',
                                'مدفوع',
                                'قيد الانتظار',
                                'مرفوض',
                              ]
                            : const [
                                'New',
                                'Draft',
                                'Paid',
                                'Pending',
                                'Declined',
                              ])[1],
                        variant: FlChipVariant.secondary,
                        color: FlChipColor.neutral,
                        size: s,
                        onPressed: () {},
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'close-button': (
    version: '0.2.5',
    canvas: const Size(390, 120),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.sm,
              children: [
                Row(
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    FlCloseButton(
                      label: (variant.dir == TextDirection.rtl
                          ? 'إغلاق'
                          : 'Close'),
                      onPressed: () {},
                    ),
                    FlCloseButton(
                      label: (variant.dir == TextDirection.rtl
                          ? 'إغلاق'
                          : 'Close'),
                      onPressed: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'color-area': (
    version: '0.1.0',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            final theme = FlScope.of(context);
            String tr(String fr, String ar) => rtl ? ar : fr;
            return ColoredBox(
              color: theme.colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.lg,
                  children: [
                    FlColorArea(
                      value: const HSVColor.fromAHSV(1, 291, 0.45, 0.8),
                      xLabel: tr('Saturation', 'التشبع'),
                      yLabel: tr('Brightness', 'السطوع'),
                      onChanged: (_) {},
                    ),
                    Row(
                      spacing: theme.space.lg,
                      children: [
                        Expanded(
                          child: FlColorArea(
                            value: const HSVColor.fromAHSV(1, 200, 1, 0.9),
                            xChannel: FlColorChannel.hue,
                            yChannel: FlColorChannel.saturation,
                            showDots: true,
                            xLabel: tr('Hue', 'الصبغة'),
                            yLabel: tr('Saturation', 'التشبع'),
                            onChanged: (_) {},
                          ),
                        ),
                        Expanded(
                          child: FlColorArea(
                            value: const HSVColor.fromAHSV(1, 140, 0.6, 0.7),
                            xLabel: tr('Saturation', 'التشبع'),
                            yLabel: tr('Brightness', 'السطوع'),
                            onChanged: null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'color-field': (
    version: '0.1.0',
    canvas: const Size(390, 700),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            final theme = FlScope.of(context);
            String tr(String fr, String ar) => rtl ? ar : fr;
            return ColoredBox(
              color: theme.colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.lg,
                  children: [
                    FlColorField(
                      label: tr('Color', 'اللون'),
                      value: HSVColor.fromAHSV(1, 208, 0.98, 0.97).toColor(),
                      onChanged: (_) {},
                    ),
                    FlColorField(
                      label: tr('Background color', 'لون الخلفية'),
                      value: null,
                      placeholder: '#FF5733',
                      helper: tr(
                        'Six hexadecimal digits',
                        'ستة أرقام سداسية عشرية',
                      ),
                      onChanged: (_) {},
                    ),
                    FlColorField(
                      label: tr('Brand color', 'لون العلامة'),
                      value: HSVColor.fromAHSV(1, 0, 0, 0).toColor(),
                      required: true,
                      error: tr('Choose a lighter color', 'اختر لونًا أفتح'),
                      onChanged: (_) {},
                    ),
                    FlColorField(
                      label: tr('Overlay', 'الطبقة'),
                      value: HSVColor.fromAHSV(0.5, 217, 0.76, 0.96).toColor(),
                      alpha: true,
                      onChanged: (_) {},
                    ),
                    FlColorField(
                      label: tr('Theme color', 'لون السمة'),
                      value: HSVColor.fromAHSV(1, 160, 0.9, 0.73).toColor(),
                      enabled: false,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'color-picker': (
    version: '0.1.1',
    canvas: const Size(390, 900),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            String tr(String fr, String ar) => rtl ? ar : fr;
            final labels = FlColorPickerLabels(
              saturation: tr('Saturation', 'التشبع'),
              brightness: tr('Brightness', 'السطوع'),
              hue: tr('Hue', 'الصبغة'),
              alpha: tr('Opacity', 'العتامة'),
              hex: tr('Hexadecimal', 'ست عشري'),
              swatches: tr('Presets', 'ألوان جاهزة'),
            );
            final presets = [
              for (final (fr, ar, hue, s, v) in const [
                ('Pink', 'وردي', 350.0, 0.74, 0.96),
                ('Purple', 'بنفسجي', 258.0, 0.64, 0.96),
                ('Blue', 'أزرق', 217.0, 0.76, 0.96),
                ('Cyan', 'سماوي', 189.0, 0.97, 0.83),
                ('Emerald', 'زمردي', 160.0, 0.9, 0.73),
                ('Amber', 'كهرماني', 38.0, 0.92, 0.96),
              ])
                FlColorSwatchItem<Color>(
                  value: HSVColor.fromAHSV(1, hue, s, v).toColor(),
                  color: HSVColor.fromAHSV(1, hue, s, v).toColor(),
                  label: tr(fr, ar),
                ),
            ];
            return Localizations(
              locale: Locale(rtl ? 'ar' : 'en'),
              delegates: const [DefaultWidgetsLocalizations.delegate],
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => ColoredBox(
                      color: FlScope.of(context).colors.surface,
                      child: Padding(
                        padding: EdgeInsetsDirectional.all(
                          FlScope.of(context).space.lg,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: FlScope.of(context).space.lg,
                            children: [
                              FlColorPicker(
                                label: tr('Choose a color', 'اختر لونًا'),
                                value: const HSVColor.fromAHSV(
                                  1,
                                  217,
                                  0.76,
                                  0.96,
                                ),
                                labels: labels,
                                swatches: presets,
                                showField: true,
                                showAlpha: true,
                                defaultOpen: true,
                                onChanged: (_) {},
                              ),
                              const SizedBox(height: 520),
                              FlColorPicker(
                                label: tr('Label color', 'لون الملصق'),
                                value: const HSVColor.fromAHSV(
                                  1,
                                  160,
                                  0.9,
                                  0.73,
                                ),
                                labels: labels,
                                onChanged: (_) {},
                              ),
                              FlColorPicker(
                                label: tr('Locked color', 'لون مقفل'),
                                value: const HSVColor.fromAHSV(
                                  1,
                                  350,
                                  0.74,
                                  0.96,
                                ),
                                labels: labels,
                                onChanged: null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ),
  'color-slider': (
    version: '0.1.0',
    canvas: const Size(390, 700),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            final theme = FlScope.of(context);
            String tr(String fr, String ar) => rtl ? ar : fr;
            const red = HSVColor.fromAHSV(1, 0, 1, 1);
            const blue = HSVColor.fromAHSV(0.5, 217, 0.76, 0.96);
            return ColoredBox(
              color: theme.colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.lg,
                  children: [
                    FlColorSlider(
                      value: red,
                      channel: FlColorChannel.hue,
                      label: tr('Hue', 'الصبغة'),
                      onChanged: (_) {},
                    ),
                    FlColorSlider(
                      value: red,
                      channel: FlColorChannel.saturation,
                      space: FlColorSpace.hsl,
                      label: tr('Saturation', 'التشبع'),
                      onChanged: (_) {},
                    ),
                    FlColorSlider(
                      value: red,
                      channel: FlColorChannel.lightness,
                      space: FlColorSpace.hsl,
                      label: tr('Lightness', 'الإضاءة'),
                      onChanged: (_) {},
                    ),
                    FlColorSlider(
                      value: blue,
                      channel: FlColorChannel.alpha,
                      label: tr('Opacity', 'العتامة'),
                      onChanged: (_) {},
                    ),
                    FlColorSlider(
                      value: blue,
                      channel: FlColorChannel.brightness,
                      label: tr('Brightness', 'السطوع'),
                      onChanged: null,
                    ),
                    SizedBox(
                      height: 160,
                      child: Row(
                        spacing: theme.space.xl,
                        children: [
                          FlColorSlider(
                            value: blue,
                            channel: FlColorChannel.hue,
                            axis: Axis.vertical,
                            showLabel: false,
                            label: tr('Hue', 'الصبغة'),
                            onChanged: (_) {},
                          ),
                          FlColorSlider(
                            value: blue,
                            channel: FlColorChannel.alpha,
                            axis: Axis.vertical,
                            label: tr('Opacity', 'العتامة'),
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'color-swatch-picker': (
    version: '0.3.0',
    canvas: const Size(390, 520),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: Locale(variant.dir == TextDirection.rtl ? 'ar' : 'en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: FlScope.of(context).space.xl,
                  children: [
                    FlColorSwatchPicker<String>(
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'اللون'
                          : 'Color'),
                      value: 'Purple',
                      onChanged: (_) {},
                      items: [
                        for (final (fr, ar, color) in const [
                          ('Pink', 'وردي', 0xFFF43F5E),
                          ('Fuchsia', 'فوشيا', 0xFFD946EF),
                          ('Purple', 'بنفسجي', 0xFF8B5CF6),
                          ('Blue', 'أزرق', 0xFF3B82F6),
                          ('Cyan', 'سماوي', 0xFF06B6D4),
                          ('Emerald', 'زمردي', 0xFF10B981),
                          ('Lime', 'ليموني', 0xFF84CC16),
                          ('White', 'أبيض', 0xFFFAFAFA),
                          ('Black', 'أسود', 0xFF18181B),
                        ])
                          FlColorSwatchItem(
                            value: fr,
                            color: Color(color),
                            label: variant.dir == TextDirection.rtl ? ar : fr,
                            disabled: fr == 'Cyan',
                          ),
                      ],
                    ),
                    FlColorSwatchPicker<String>(
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'لون الملصق'
                          : 'Label color'),
                      value: 'Lime',
                      size: FlColorSwatchSize.lg,
                      shape: FlColorSwatchShape.square,
                      onChanged: (_) {},
                      items: [
                        for (final (fr, ar, color) in const [
                          ('Pink', 'وردي', 0xFFF43F5E),
                          ('Fuchsia', 'فوشيا', 0xFFD946EF),
                          ('Purple', 'بنفسجي', 0xFF8B5CF6),
                          ('Blue', 'أزرق', 0xFF3B82F6),
                          ('Cyan', 'سماوي', 0xFF06B6D4),
                          ('Emerald', 'زمردي', 0xFF10B981),
                          ('Lime', 'ليموني', 0xFF84CC16),
                          ('White', 'أبيض', 0xFFFAFAFA),
                          ('Black', 'أسود', 0xFF18181B),
                        ])
                          FlColorSwatchItem(
                            value: fr,
                            color: Color(color),
                            label: variant.dir == TextDirection.rtl ? ar : fr,
                            disabled: fr == 'Cyan',
                          ),
                      ],
                    ),
                    FlColorSwatchPicker<String>(
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'لون التقويم'
                          : 'Calendar color'),
                      value: 'White',
                      size: FlColorSwatchSize.sm,
                      enabled: false,
                      onChanged: (_) {},
                      items: [
                        for (final (fr, ar, color) in const [
                          ('Pink', 'وردي', 0xFFF43F5E),
                          ('Fuchsia', 'فوشيا', 0xFFD946EF),
                          ('Purple', 'بنفسجي', 0xFF8B5CF6),
                          ('Blue', 'أزرق', 0xFF3B82F6),
                          ('Cyan', 'سماوي', 0xFF06B6D4),
                          ('Emerald', 'زمردي', 0xFF10B981),
                          ('Lime', 'ليموني', 0xFF84CC16),
                          ('White', 'أبيض', 0xFFFAFAFA),
                          ('Black', 'أسود', 0xFF18181B),
                        ])
                          FlColorSwatchItem(
                            value: fr,
                            color: Color(color),
                            label: variant.dir == TextDirection.rtl ? ar : fr,
                            disabled: fr == 'Cyan',
                          ),
                      ],
                    ),
                    Row(
                      spacing: FlScope.of(context).space.sm,
                      children: [
                        FlColorSwatch(
                          color: const Color(0xFF3B82F6),
                          label: variant.dir == TextDirection.rtl
                              ? 'أزرق'
                              : 'Blue',
                        ),
                        FlColorSwatch(
                          color: const Color(0xFFFAFAFA),
                          label: variant.dir == TextDirection.rtl
                              ? 'أبيض'
                              : 'White',
                          shape: FlColorSwatchShape.square,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'color-swatch': (
    version: '0.1.0',
    canvas: const Size(390, 440),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            final theme = FlScope.of(context);
            String tr(String fr, String ar) => rtl ? ar : fr;
            final tints = [
              (tr('Blue', 'أزرق'), const HSVColor.fromAHSV(1, 217, 0.76, 0.96)),
              (tr('Pink', 'وردي'), const HSVColor.fromAHSV(1, 350, 0.74, 0.96)),
              (
                tr('Emerald', 'زمردي'),
                const HSVColor.fromAHSV(1, 160, 0.9, 0.73),
              ),
              (tr('White', 'أبيض'), const HSVColor.fromAHSV(1, 0, 0, 0.98)),
            ];
            return ColoredBox(
              color: theme.colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.xl,
                  children: [
                    for (final shape in FlColorSwatchShape.values)
                      Wrap(
                        spacing: theme.space.md,
                        runSpacing: theme.space.md,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final size in FlColorSwatchSize.values)
                            FlColorSwatch(
                              color: tints.first.$2.toColor(),
                              label: tints.first.$1,
                              size: size,
                              shape: shape,
                            ),
                        ],
                      ),
                    Wrap(
                      spacing: theme.space.md,
                      runSpacing: theme.space.md,
                      children: [
                        for (final (name, tint) in tints)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: theme.space.xs,
                            children: [
                              FlColorSwatch(
                                color: tint.toColor(),
                                label: name,
                                size: FlColorSwatchSize.xl,
                              ),
                              ExcludeSemantics(
                                child: Text(
                                  flColorHex(tint.toColor()),
                                  textDirection: TextDirection.ltr,
                                  style: theme.typography
                                      .resolve(FlTextRole.textXs)
                                      .copyWith(
                                        color: theme.colors.onSurfaceMuted,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        for (final (name, tint) in tints.take(3))
                          FlColorSwatch(
                            color: tint.withAlpha(0.4).toColor(),
                            label: tr('$name at 40%', '$name ٤٠٪'),
                            size: FlColorSwatchSize.xl,
                            shape: FlColorSwatchShape.square,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'combo-box': (
    version: '0.2.3',
    canvas: const Size(390, 520),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: FlScope.of(context).space.md,
                    children: [
                      FlComboBox<int>(
                        label: (variant.dir == TextDirection.rtl
                            ? 'البلد'
                            : 'Country'),
                        triggerLabel: (variant.dir == TextDirection.rtl
                            ? 'كل البلدان'
                            : 'All countries'),
                        value: FlSelectOption(
                          value: 0,
                          label: (variant.dir == TextDirection.rtl
                              ? 'المملكة المتحدة'
                              : 'United Kingdom'),
                        ),
                        onChanged: null,
                        suggestions: (_) => const [],
                        countText: (count) => (variant.dir == TextDirection.rtl
                            ? '$count اقتراحات'
                            : '$count suggestions'),
                        emptyText: (variant.dir == TextDirection.rtl
                            ? 'لا توجد مدينة'
                            : 'No city'),
                        loadingText: (variant.dir == TextDirection.rtl
                            ? 'جارٍ البحث…'
                            : 'Searching…'),
                        errorText: (variant.dir == TextDirection.rtl
                            ? 'تعذّر البحث'
                            : 'The search failed'),
                      ),
                      FlComboBox<int>(
                        autofocus: true,
                        label: (variant.dir == TextDirection.rtl
                            ? 'المدينة'
                            : 'City'),
                        placeholder: (variant.dir == TextDirection.rtl
                            ? 'ابحث عن مدينة'
                            : 'Search for a city'),
                        triggerLabel: (variant.dir == TextDirection.rtl
                            ? 'كل المدن'
                            : 'All cities'),
                        value: FlSelectOption(
                          value: 0,
                          label: (variant.dir == TextDirection.rtl
                              ? 'بريستول'
                              : 'Bristol'),
                        ),
                        onChanged: (_) {},
                        suggestions: (query) => [
                          for (final (i, (name, region))
                              in (variant.dir == TextDirection.rtl
                                      ? const [
                                          ('بريستول', null),
                                          ('ليدز', null),
                                          ('يورك', null),
                                          ('لندن', 'إنجلترا'),
                                        ]
                                      : const [
                                          ('Bristol', null),
                                          ('Leeds', null),
                                          ('York', null),
                                          ('London', 'England'),
                                        ])
                                  .indexed)
                            if (name.toLowerCase().contains(
                              query.toLowerCase(),
                            ))
                              FlSelectOption(
                                value: i,
                                label: name,
                                description: region,
                              ),
                        ],
                        countText: (count) => (variant.dir == TextDirection.rtl
                            ? '$count اقتراحات'
                            : '$count suggestions'),
                        emptyText: (variant.dir == TextDirection.rtl
                            ? 'لا توجد مدينة'
                            : 'No city'),
                        loadingText: (variant.dir == TextDirection.rtl
                            ? 'جارٍ البحث…'
                            : 'Searching…'),
                        errorText: (variant.dir == TextDirection.rtl
                            ? 'تعذّر البحث'
                            : 'The search failed'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'control-field': (
    version: '0.2.3',
    canvas: const Size(390, 900),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: Locale(variant.dir == TextDirection.rtl ? 'ar' : 'en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.md,
                  children: [
                    FlControlField(
                      value: true,
                      onChanged: (_) {},
                      label: variant.dir == TextDirection.rtl
                          ? 'الإشعارات'
                          : 'Notifications',
                      description: variant.dir == TextDirection.rtl
                          ? 'الأصوات والتنبيهات'
                          : 'Sounds and banners',
                    ),
                    FlControlField(
                      value: false,
                      onChanged: (_) {},
                      indicator: FlControlFieldIndicator.checkbox,
                      invalid: true,
                      required: true,
                      label: variant.dir == TextDirection.rtl
                          ? 'قبول الشروط'
                          : 'Terms accepted',
                      error: variant.dir == TextDirection.rtl
                          ? 'مطلوب'
                          : 'Required',
                    ),
                    FlControlField(
                      value: true,
                      onChanged: null,
                      indicator: FlControlFieldIndicator.radio,
                      label: variant.dir == TextDirection.rtl
                          ? 'وضع الطيران'
                          : 'Airplane mode',
                      description: variant.dir == TextDirection.rtl
                          ? 'غير متاح'
                          : 'Unavailable',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'core': (
    version: '0.2.9',
    canvas: null,
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Center(
            child: FlPressable(
              onPressed: () {},
              label: 'Press',
              borderRadius: FlScope.of(context).shape.buttonRadius,
              builder: (context, states) => Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.md,
                ),
                child: Text(
                  variant.dir == TextDirection.rtl ? 'اضغط' : 'Press',
                  style: TextStyle(color: FlScope.of(context).colors.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'date-field': (
    version: '0.2.5',
    canvas: const Size(390, 640),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlDateField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تاريخ الميلاد'
                      : 'Date of birth'),
                  value: null,
                  onChanged: (_) {},
                  autofocus: true,
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlDateField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تاريخ الانتهاء'
                      : 'Expiry date'),
                  value: DateTime(2031, 3, 9),
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlDateField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تاريخ الوصول'
                      : 'Arrival date'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'كما هو مدوّن على التذكرة'
                      : 'As shown on the ticket'),
                  required: true,
                  value: null,
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlDateField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تاريخ التسليم'
                      : 'Delivery date'),
                  error: (variant.dir == TextDirection.rtl
                      ? 'هذا التاريخ مضى'
                      : 'This date has passed'),
                  value: DateTime(2026, 10, 2),
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlDateField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تاريخ الإرسال'
                      : 'Send date'),
                  value: DateTime(2026, 10, 14),
                  onChanged: null,
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'date-picker': (
    version: '0.2.4',
    canvas: const Size(390, 900),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: FlScope.of(context).space.lg,
                      children: [
                        FlDatePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تاريخ الموعد'
                              : 'Appointment date'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'اختر تاريخًا'
                              : 'Choose a date'),
                          clearLabel: (variant.dir == TextDirection.rtl
                              ? 'مسح التاريخ'
                              : 'Clear the date'),
                          value: DateTime(2026, 10, 14),
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          defaultOpen: true,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        const SizedBox(height: 360),
                        FlDatePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تاريخ التسليم'
                              : 'Delivery date'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'اختر تاريخًا'
                              : 'Choose a date'),
                          description: (variant.dir == TextDirection.rtl
                              ? 'من الاثنين إلى الجمعة'
                              : 'Monday to Friday'),
                          required: true,
                          value: null,
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        FlDatePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تاريخ العودة'
                              : 'Return date'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'اختر تاريخًا'
                              : 'Choose a date'),
                          error: (variant.dir == TextDirection.rtl
                              ? 'هذا التاريخ مضى'
                              : 'This date has passed'),
                          value: DateTime(2026, 10, 2),
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        FlDatePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تاريخ الإرسال'
                              : 'Send date'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'اختر تاريخًا'
                              : 'Choose a date'),
                          value: DateTime(2026, 10, 14),
                          onChanged: null,
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'date-range-picker': (
    version: '0.2.3',
    canvas: const Size(390, 1000),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: FlScope.of(context).space.lg,
                      children: [
                        FlDateRangePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'تواريخ الإقامة'
                              : 'Stay dates'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'الوصول – المغادرة'
                              : 'Check-in – check-out'),
                          clearLabel: (variant.dir == TextDirection.rtl
                              ? 'مسح التواريخ'
                              : 'Clear the dates'),
                          value: FlDateRange(
                            DateTime(2026, 10, 12),
                            DateTime(2026, 10, 16),
                          ),
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          defaultOpen: true,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        const SizedBox(height: 390),
                        FlDateRangePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الإجازة'
                              : 'Time off'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'البداية – النهاية'
                              : 'Start – end'),
                          description: (variant.dir == TextDirection.rtl
                              ? 'خمسة أيام على الأكثر'
                              : 'Five days at most'),
                          required: true,
                          value: null,
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        FlDateRangePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الاستئجار'
                              : 'Rental'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'البداية – النهاية'
                              : 'Start – end'),
                          error: (variant.dir == TextDirection.rtl
                              ? 'السيارة مستأجرة بالفعل'
                              : 'The vehicle is already rented'),
                          value: FlDateRange(
                            DateTime(2026, 10, 20),
                            DateTime(2026, 10, 22),
                          ),
                          onChanged: (_) {},
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                        FlDateRangePicker(
                          label: (variant.dir == TextDirection.rtl
                              ? 'فترة التقرير'
                              : 'Report period'),
                          placeholder: (variant.dir == TextDirection.rtl
                              ? 'البداية – النهاية'
                              : 'Start – end'),
                          value: FlDateRange(
                            DateTime(2026, 10, 1),
                            DateTime(2026, 10, 7),
                          ),
                          onChanged: null,
                          presentation: FlDatePickerPresentation.popover,
                          today: DateTime(2026, 10, 24),
                          strings: FlCalendarStrings.language(
                            variant.dir == TextDirection.rtl ? 'ar' : 'en',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'dialog': (
    version: '0.2.4',
    canvas: const Size(390, 560),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Navigator(
          onGenerateInitialRoutes: (navigator, _) => [
            PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: const SizedBox.expand(),
              ),
            ),
            FlDialogRoute<void>(
              context: context,
              barrierLabel: (variant.dir == TextDirection.rtl
                  ? 'إغلاق'
                  : 'Close'),
              builder: (context) => FlDialog(
                title: (variant.dir == TextDirection.rtl
                    ? 'حذف الملف؟'
                    : 'Delete the file?'),
                closeLabel: (variant.dir == TextDirection.rtl
                    ? 'إغلاق'
                    : 'Close'),
                content: Text(
                  (variant.dir == TextDirection.rtl
                      ? 'سينقل الملف إلى سلة المهملات لمدة 30 يومًا، ثم يُحذف من جميع أجهزتك.'
                      : 'The file will stay in the trash for 30 days, then be erased from all your devices.'),
                ),
                actions: [
                  FlButton(
                    label: (variant.dir == TextDirection.rtl
                        ? 'إلغاء'
                        : 'Cancel'),
                    variant: FlButtonVariant.ghost,
                    size: FlButtonSize.sm,
                    onPressed: () => Navigator.pop(context),
                  ),
                  FlButton(
                    label: (variant.dir == TextDirection.rtl
                        ? 'حذف'
                        : 'Delete'),
                    size: FlButtonSize.sm,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'drawer': (
    version: '0.3.0',
    canvas: const Size(390, 640),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Navigator(
          onGenerateInitialRoutes: (navigator, _) => [
            PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: const SizedBox.expand(),
              ),
            ),
            FlDrawerRoute<void>(
              context: context,
              barrierLabel: (variant.dir == TextDirection.rtl
                  ? 'إغلاق القائمة'
                  : 'Close the menu'),
              builder: (context) => FlDrawer(
                title: (variant.dir == TextDirection.rtl
                    ? 'التنقل'
                    : 'Navigation'),
                closeLabel: (variant.dir == TextDirection.rtl
                    ? 'إغلاق'
                    : 'Close'),
                footer: FlDrawerItem(
                  label: (variant.dir == TextDirection.rtl
                      ? 'تسجيل الخروج'
                      : 'Sign out'),
                  icon: FlIcons.arrowRightFromSquare,
                  danger: true,
                  onPressed: () => Navigator.pop(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    FlDrawerSection(
                      children: [
                        FlDrawerItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الرئيسية'
                              : 'Home'),
                          icon: FlIcons.house,
                          selected: true,
                          onPressed: () {},
                        ),
                        FlDrawerItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الطلبات'
                              : 'Orders'),
                          icon: FlIcons.shoppingCart,
                          onPressed: () {},
                        ),
                        FlDrawerItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الرسائل'
                              : 'Messages'),
                          icon: FlIcons.envelope,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    FlDrawerSection(
                      title: (variant.dir == TextDirection.rtl
                          ? 'الحساب'
                          : 'Account'),
                      children: [
                        FlDrawerItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'الإعدادات'
                              : 'Settings'),
                          icon: FlIcons.gear,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'field': (
    version: '0.2.3',
    canvas: const Size(390, 830),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlFieldScope(
                  invalid: false,
                  disabled: false,
                  required: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: FlScope.of(context).space.xs,
                    children: [
                      FlLabel(
                        (variant.dir == TextDirection.rtl
                            ? 'البريد الإلكتروني'
                            : 'Email address'),
                      ),
                      FlDescription(
                        (variant.dir == TextDirection.rtl
                            ? 'للإيصالات فقط.'
                            : 'For receipts only.'),
                        hideOnInvalid: true,
                      ),
                      FlFieldError(
                        (variant.dir == TextDirection.rtl
                            ? 'عنوان غير صالح.'
                            : 'Invalid address.'),
                      ),
                    ],
                  ),
                ),
                FlFieldScope(
                  invalid: true,
                  disabled: false,
                  required: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: FlScope.of(context).space.xs,
                    children: [
                      FlLabel(
                        (variant.dir == TextDirection.rtl
                            ? 'البريد الإلكتروني'
                            : 'Email address'),
                      ),
                      FlDescription(
                        (variant.dir == TextDirection.rtl
                            ? 'للإيصالات فقط.'
                            : 'For receipts only.'),
                        hideOnInvalid: true,
                      ),
                      FlFieldError(
                        (variant.dir == TextDirection.rtl
                            ? 'عنوان غير صالح.'
                            : 'Invalid address.'),
                      ),
                    ],
                  ),
                ),
                FlFieldScope(
                  invalid: false,
                  disabled: true,
                  required: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: FlScope.of(context).space.xs,
                    children: [
                      FlLabel(
                        (variant.dir == TextDirection.rtl
                            ? 'البريد الإلكتروني'
                            : 'Email address'),
                      ),
                      FlDescription(
                        (variant.dir == TextDirection.rtl
                            ? 'للإيصالات فقط.'
                            : 'For receipts only.'),
                        hideOnInvalid: true,
                      ),
                      FlFieldError(
                        (variant.dir == TextDirection.rtl
                            ? 'عنوان غير صالح.'
                            : 'Invalid address.'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'fieldset': (
    version: '0.1.1',
    canvas: const Size(390, 640),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: FlScope.of(context).space.xxl,
                          children: [
                            FlFieldset(
                              legend: (variant.dir == TextDirection.rtl
                                  ? 'الملف الشخصي'
                                  : 'Profile'),
                              description: (variant.dir == TextDirection.rtl
                                  ? 'يظهر في صفحتك العامة.'
                                  : 'Visible on your public page.'),
                              actions: [
                                FlButton(
                                  label: (variant.dir == TextDirection.rtl
                                      ? 'حفظ'
                                      : 'Save'),
                                  onPressed: () {},
                                ),
                                FlButton(
                                  label: (variant.dir == TextDirection.rtl
                                      ? 'إلغاء'
                                      : 'Cancel'),
                                  variant: FlButtonVariant.tertiary,
                                  onPressed: () {},
                                ),
                              ],
                              children: [
                                FlTextField(
                                  label: (variant.dir == TextDirection.rtl
                                      ? 'الاسم'
                                      : 'Name'),
                                  required: true,
                                  controller: TextEditingController(
                                    text: (variant.dir == TextDirection.rtl
                                        ? 'ليلى حداد'
                                        : 'Camille Martin'),
                                  ),
                                ),
                                FlTextField(
                                  label: (variant.dir == TextDirection.rtl
                                      ? 'البريد الإلكتروني'
                                      : 'Email'),
                                  placeholder: 'camille@example.com',
                                ),
                              ],
                            ),
                            FlFieldset(
                              legend: (variant.dir == TextDirection.rtl
                                  ? 'التوصيل'
                                  : 'Shipping'),
                              description: (variant.dir == TextDirection.rtl
                                  ? 'أين نرسل الطلب.'
                                  : 'Where to send the order.'),
                              error: (variant.dir == TextDirection.rtl
                                  ? 'أدخل عنوان التوصيل.'
                                  : 'Enter a shipping address.'),
                              children: [
                                FlTextField(
                                  label: (variant.dir == TextDirection.rtl
                                      ? 'العنوان'
                                      : 'Address'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'icons': (
    version: '0.2.2',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.xl,
              children: [
                Wrap(
                  spacing: FlScope.of(context).space.lg,
                  runSpacing: FlScope.of(context).space.lg,
                  children: [
                    for (final icon in [
                      FlIcons.arrowLeft,
                      FlIcons.chevronRight,
                      FlIcons.xmark,
                      FlIcons.bars,
                      FlIcons.house,
                      FlIcons.magnifier,
                      FlIcons.gear,
                      FlIcons.plus,
                      FlIcons.check,
                      FlIcons.trashBin,
                      FlIcons.arrowUpFromSquare,
                      FlIcons.heart,
                      FlIcons.heartFill,
                      FlIcons.starFill,
                      FlIcons.circleInfo,
                      FlIcons.triangleExclamation,
                      FlIcons.bell,
                      FlIcons.person,
                      FlIcons.lock,
                      FlIcons.calendar,
                      FlIcons.shoppingCart,
                      FlIcons.comment,
                      FlIcons.playFill,
                      FlIcons.pauseFill,
                    ])
                      FlIcon(icon),
                  ],
                ),
                IconTheme(
                  data: IconThemeData(
                    size: FlScope.of(context).size.buttonIconLg,
                    color: FlScope.of(context).colors.accent,
                  ),
                  child: Row(
                    spacing: FlScope.of(context).space.lg,
                    children: [
                      FlIcon(FlIcons.arrowLeft),
                      FlIcon(FlIcons.chevronRight),
                      FlIcon(FlIcons.paperPlane),
                      FlIcon(FlIcons.playFill),
                      FlIcon(FlIcons.heartFill),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'input-group': (
    version: '0.2.2',
    canvas: const Size(390, 520),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: FlScope.of(context).space.lg,
                        children: [
                          FlInputGroup(
                            prefix: const Text('https://'),
                            decorativePrefix: true,
                            child: FlInput(
                              label: variant.dir == TextDirection.rtl
                                  ? 'الموقع'
                                  : 'Website',
                              placeholder: variant.dir == TextDirection.rtl
                                  ? 'مثال'
                                  : 'example',
                            ),
                          ),
                          FlInputGroup(
                            suffix: const Text('€'),
                            decorativeSuffix: true,
                            child: FlInput(
                              label: variant.dir == TextDirection.rtl
                                  ? 'المبلغ'
                                  : 'Amount',
                              controller: TextEditingController(text: '42'),
                            ),
                          ),
                          FlInputGroup(
                            prefix: const Text('https://'),
                            suffix: const Text('.com'),
                            decorativePrefix: true,
                            decorativeSuffix: true,
                            child: FlInput(
                              label: variant.dir == TextDirection.rtl
                                  ? 'الموقع'
                                  : 'Website',
                              controller: TextEditingController(text: 'fliin'),
                              invalid: true,
                            ),
                          ),
                          FlInputGroup(
                            prefix: const Text('@'),
                            decorativePrefix: true,
                            disabled: true,
                            child: FlInput(
                              label: variant.dir == TextDirection.rtl
                                  ? 'المعرّف'
                                  : 'Username',
                              controller: TextEditingController(text: 'demo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'input-otp': (
    version: '0.2.6',
    canvas: const Size(390, 320),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: FlScope.of(context).space.lg,
                        children: [
                          FlInputOtp(
                            label: (variant.dir == TextDirection.rtl
                                ? 'رمز التحقق'
                                : 'Verification code'),
                            groups: const [3, 3],
                            controller: TextEditingController(text: '12'),
                            autofocus: true,
                          ),
                          FlInputOtp(
                            label: (variant.dir == TextDirection.rtl
                                ? 'الرمز السري'
                                : 'PIN code'),
                            groups: const [4],
                            placeholder: '0000',
                          ),
                          FlInputOtp(
                            label: (variant.dir == TextDirection.rtl
                                ? 'رمز التحقق'
                                : 'Verification code'),
                            groups: const [3, 3],
                            controller: TextEditingController(text: '123456'),
                            invalid: true,
                          ),
                          FlInputOtp(
                            label: (variant.dir == TextDirection.rtl
                                ? 'رمز التحقق'
                                : 'Verification code'),
                            groups: const [3, 3],
                            controller: TextEditingController(text: '123'),
                            disabled: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'kbd': (
    version: '0.1.1',
    canvas: const Size(390, 260),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FlKbd(
                      keys: const [FlKbdKey.command],
                      text: 'K',
                      semanticLabel: (variant.dir == TextDirection.rtl
                          ? 'أمر K'
                          : 'Command K'),
                    ),
                    FlKbd(
                      keys: const [FlKbdKey.command, FlKbdKey.shift],
                      text: 'Z',
                    ),
                    FlKbd(
                      keys: const [FlKbdKey.option, FlKbdKey.control],
                      text: 'F',
                    ),
                    FlKbd(keys: const [FlKbdKey.enter]),
                    FlKbd(keys: const [FlKbdKey.escape]),
                    FlKbd(keys: const [FlKbdKey.tab]),
                  ],
                ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FlKbd(keys: const [FlKbdKey.up]),
                    FlKbd(keys: const [FlKbdKey.down]),
                    FlKbd(keys: const [FlKbdKey.left]),
                    FlKbd(keys: const [FlKbdKey.right]),
                    FlKbd(keys: const [FlKbdKey.space]),
                    FlKbd(keys: const [FlKbdKey.delete]),
                  ],
                ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (variant.dir == TextDirection.rtl ? 'نسخ' : 'Copy'),
                      style: FlScope.of(context).typography
                          .resolve(FlTextRole.textSm)
                          .copyWith(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                    ),
                    FlKbd(
                      keys: const [FlKbdKey.command],
                      text: 'C',
                      variant: FlKbdVariant.light,
                    ),
                    Text(
                      (variant.dir == TextDirection.rtl ? 'لصق' : 'Paste'),
                      style: FlScope.of(context).typography
                          .resolve(FlTextRole.textSm)
                          .copyWith(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                    ),
                    FlKbd(
                      keys: const [FlKbdKey.command],
                      text: 'V',
                      variant: FlKbdVariant.light,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'link-button': (
    version: '0.2.4',
    canvas: const Size(390, 300),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.md,
              children: [
                for (final s in FlButtonSize.values)
                  FlLinkButton(
                    label: (variant.dir == TextDirection.rtl
                        ? 'معرفة المزيد'
                        : 'Learn more'),
                    size: s,
                    underline: true,
                    onPressed: () {},
                  ),
                FlLinkButton(
                  label: (variant.dir == TextDirection.rtl
                      ? 'سياسة الخصوصية'
                      : 'Privacy'),
                  underline: true,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'list-row': (
    version: '0.2.7',
    canvas: const Size(390, 460),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlListGroup(
                  children: [
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? 'واي فاي'
                          : 'Wi-Fi'),
                      subtitle: (variant.dir == TextDirection.rtl
                          ? 'المنزل'
                          : 'Home'),
                      trailing: const FlListRowChevron(),
                      onPressed: () {},
                    ),
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? 'اللغة'
                          : 'Language'),
                      value: (variant.dir == TextDirection.rtl
                          ? 'العربية'
                          : 'English'),
                    ),
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? 'بلوتوث'
                          : 'Bluetooth'),
                      subtitle: (variant.dir == TextDirection.rtl
                          ? 'غير متاح'
                          : 'Unavailable'),
                      trailing: const FlListRowChevron(),
                      enabled: false,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'menu': (
    version: '0.2.5',
    canvas: const Size(390, 360),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: FlMenu(
                      items: [
                        FlMenuItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'نسخ'
                              : 'Copy'),
                          onPressed: () {},
                        ),
                        FlMenuItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'لصق'
                              : 'Paste'),
                          onPressed: null,
                        ),
                        const FlMenuDivider(),
                        FlMenuItem(
                          label: (variant.dir == TextDirection.rtl
                              ? 'حذف'
                              : 'Delete'),
                          destructive: true,
                          onPressed: () {},
                        ),
                      ],
                      builder: (context, controller) {
                        if (!controller.isOpen)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!controller.isOpen) controller.open();
                          });
                        return FlPressable(
                          onPressed: controller.open,
                          label: (variant.dir == TextDirection.rtl
                              ? 'خيارات'
                              : 'Options'),
                          borderRadius: FlScope.of(context).shape.buttonRadius,
                          builder: (context, states) => Padding(
                            padding: EdgeInsetsDirectional.all(
                              FlScope.of(context).space.md,
                            ),
                            child: Text(
                              (variant.dir == TextDirection.rtl
                                  ? 'خيارات'
                                  : 'Options'),
                              style: TextStyle(
                                color: FlScope.of(context).colors.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'meter': (
    version: '0.1.1',
    canvas: const Size(390, 400),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlMeter(
                  label: (variant.dir == TextDirection.rtl
                      ? 'التخزين'
                      : 'Storage'),
                  value: 64,
                  valueLabel: (_) => (variant.dir == TextDirection.rtl
                      ? '٦٫٤ من ١٠ غ.ب'
                      : '6.4 GB of 10'),
                ),
                FlMeter(
                  label: (variant.dir == TextDirection.rtl
                      ? 'البطارية'
                      : 'Battery'),
                  value: 82,
                  size: FlMeterSize.sm,
                  color: FlMeterColor.success,
                ),
                FlMeter(
                  label: (variant.dir == TextDirection.rtl
                      ? 'الباقة'
                      : 'Data plan'),
                  value: 88,
                  size: FlMeterSize.md,
                  color: FlMeterColor.warning,
                ),
                FlMeter(
                  label: (variant.dir == TextDirection.rtl ? 'القرص' : 'Disk'),
                  value: 97,
                  size: FlMeterSize.lg,
                  color: FlMeterColor.danger,
                ),
                FlMeter(
                  label: (variant.dir == TextDirection.rtl
                      ? 'كلمات مرور قوية'
                      : 'Strong passwords'),
                  value: 3,
                  max: 4,
                  color: FlMeterColor.neutral,
                ),
                FlMeter(
                  label: (variant.dir == TextDirection.rtl
                      ? 'الذاكرة'
                      : 'Memory'),
                  value: 40,
                  showLabel: false,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'number-field': (
    version: '0.2.4',
    canvas: const Size(390, 1060),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: FlScope.of(context).space.md,
                        children: [
                          FlNumberField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'الكمية'
                                : 'Quantity'),
                            value: 2,
                            min: 1,
                            max: 10,
                            format: FlIntegerFormat(
                              digits: variant.dir == TextDirection.rtl
                                  ? FlDigits.arabicIndic
                                  : FlDigits.latin,
                            ),
                            decrementLabel: (variant.dir == TextDirection.rtl
                                ? 'إنقاص'
                                : 'Decrease'),
                            incrementLabel: (variant.dir == TextDirection.rtl
                                ? 'زيادة'
                                : 'Increase'),
                            helper: (variant.dir == TextDirection.rtl
                                ? '١٠ على الأكثر'
                                : '10 at most'),
                            onChanged: (_) {},
                          ),
                          FlNumberField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'المسافرون'
                                : 'Travelers'),
                            value: 1,
                            min: 1,
                            max: 10,
                            format: FlIntegerFormat(
                              digits: variant.dir == TextDirection.rtl
                                  ? FlDigits.arabicIndic
                                  : FlDigits.latin,
                            ),
                            decrementLabel: (variant.dir == TextDirection.rtl
                                ? 'إنقاص'
                                : 'Decrease'),
                            incrementLabel: (variant.dir == TextDirection.rtl
                                ? 'زيادة'
                                : 'Increase'),
                            onChanged: (_) {},
                          ),
                          FlNumberField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'الليالي'
                                : 'Nights'),
                            value: 3,
                            min: 1,
                            max: 10,
                            format: FlIntegerFormat(
                              digits: variant.dir == TextDirection.rtl
                                  ? FlDigits.arabicIndic
                                  : FlDigits.latin,
                            ),
                            decrementLabel: (variant.dir == TextDirection.rtl
                                ? 'إنقاص'
                                : 'Decrease'),
                            incrementLabel: (variant.dir == TextDirection.rtl
                                ? 'زيادة'
                                : 'Increase'),
                            variant: FlInputVariant.secondary,
                            onChanged: (_) {},
                          ),
                          FlNumberField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'المقاعد'
                                : 'Seats'),
                            value: 12,
                            min: 1,
                            max: 10,
                            format: FlIntegerFormat(
                              digits: variant.dir == TextDirection.rtl
                                  ? FlDigits.arabicIndic
                                  : FlDigits.latin,
                            ),
                            decrementLabel: (variant.dir == TextDirection.rtl
                                ? 'إنقاص'
                                : 'Decrease'),
                            incrementLabel: (variant.dir == TextDirection.rtl
                                ? 'زيادة'
                                : 'Increase'),
                            error: (variant.dir == TextDirection.rtl
                                ? 'بقي ١٠ مقاعد'
                                : '10 seats left'),
                            onChanged: (_) {},
                          ),
                          FlNumberField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'الغرف'
                                : 'Rooms'),
                            value: 4,
                            min: 1,
                            max: 10,
                            format: FlIntegerFormat(
                              digits: variant.dir == TextDirection.rtl
                                  ? FlDigits.arabicIndic
                                  : FlDigits.latin,
                            ),
                            decrementLabel: (variant.dir == TextDirection.rtl
                                ? 'إنقاص'
                                : 'Decrease'),
                            incrementLabel: (variant.dir == TextDirection.rtl
                                ? 'زيادة'
                                : 'Increase'),
                            enabled: false,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'page-indicator': (
    version: '0.2.2',
    canvas: const Size(390, 300),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                for (final (count, index) in const [
                  (3, 0),
                  (3, 1),
                  (3, 2),
                  (7, 4),
                ])
                  SizedBox(
                    height: FlScope.of(context).hitTarget,
                    child: Center(
                      child: FlPageIndicator(
                        count: count,
                        index: index,
                        semanticLabel: (variant.dir == TextDirection.rtl
                            ? 'العرض'
                            : 'Introduction'),
                        pageLabel: (page, count) =>
                            (variant.dir == TextDirection.rtl
                            ? 'الصفحة $page من $count'
                            : 'Page $page of $count'),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'page': (
    version: '0.2.6',
    canvas: const Size(780, 844),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width / 2,
              height: MediaQuery.sizeOf(context).height,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(
                    MediaQuery.sizeOf(context).width / 2,
                    MediaQuery.sizeOf(context).height,
                  ),
                ),
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 47, bottom: 34),
                    ),
                    child: FlPage(
                      appBar: FlAppBar(
                        title: (variant.dir == TextDirection.rtl
                            ? 'الإعدادات'
                            : 'Settings'),
                        titleSize: FlAppBarTitleSize.large,
                      ),
                      refresh: FlPageRefresh(
                        label: (variant.dir == TextDirection.rtl
                            ? 'تحديث'
                            : 'Refresh'),
                        onRefresh: () async {},
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsetsDirectional.all(
                            FlScope.of(context).space.lg,
                          ),
                          sliver: SliverList.list(
                            children: [
                              for (var i = 0; i < 14; i++)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    bottom: FlScope.of(context).space.sm,
                                  ),
                                  child: SizedBox(
                                    height: 56,
                                    child: DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color: FlScope.of(context)
                                            .colors
                                            .surfaceRaised,
                                        shape: FlContinuousBorder(
                                          radius: FlScope.of(context)
                                              .shape
                                              .radiusCard,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width / 2,
              height: MediaQuery.sizeOf(context).height,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(
                    MediaQuery.sizeOf(context).width / 2,
                    MediaQuery.sizeOf(context).height,
                  ),
                ),
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 47, bottom: 34),
                    ),
                    child: FlPage(
                      appBar: FlAppBar(
                        title: (variant.dir == TextDirection.rtl
                            ? 'السلة'
                            : 'Cart'),
                      ),
                      tabBar: FlPageBar(
                        info: [
                          Text(
                            (variant.dir == TextDirection.rtl
                                ? 'تم رفض الدفع. لم يُخصم أي مبلغ.'
                                : 'Payment declined. You weren’t charged.'),
                            style: FlScope.of(context).typography
                                .resolve(FlTextRole.textSm)
                                .copyWith(
                                  color: FlScope.of(context).colors.danger,
                                ),
                          ),
                        ],
                        action: SizedBox(
                          height: 48,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: FlScope.of(context).colors.accent,
                              shape: FlContinuousBorder(
                                radius: FlScope.of(context).shape.radiusButton,
                              ),
                            ),
                          ),
                        ),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsetsDirectional.all(
                            FlScope.of(context).space.lg,
                          ),
                          sliver: SliverList.list(
                            children: [
                              for (var i = 0; i < 8; i++)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    bottom: FlScope.of(context).space.sm,
                                  ),
                                  child: SizedBox(
                                    height: 56,
                                    child: DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color: FlScope.of(context)
                                            .colors
                                            .surfaceRaised,
                                        shape: FlContinuousBorder(
                                          radius: FlScope.of(context)
                                              .shape
                                              .radiusCard,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'pagination': (
    version: '0.1.1',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.xl,
                  children: [
                    FlPagination(
                      page: 1,
                      pageCount: 3,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.md,
                      showNavLabels: true,
                      showPages: true,
                    ),
                    FlPagination(
                      page: 6,
                      pageCount: 20,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.md,
                      showNavLabels: false,
                      showPages: true,
                    ),
                    FlPagination(
                      page: 2,
                      pageCount: 3,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.sm,
                      showNavLabels: false,
                      showPages: true,
                    ),
                    FlPagination(
                      page: 2,
                      pageCount: 3,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.lg,
                      showNavLabels: false,
                      showPages: true,
                    ),
                    FlPagination(
                      page: 3,
                      pageCount: 12,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.md,
                      showNavLabels: false,
                      showPages: true,
                      summary: (variant.dir == TextDirection.rtl
                          ? '٢١–٣٠ من ١٢٠ نتيجة'
                          : '21–30 of 120 results'),
                    ),
                    FlPagination(
                      page: 2,
                      pageCount: 5,
                      onChanged: (_) {},
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.md,
                      showNavLabels: false,
                      showPages: false,
                    ),
                    FlPagination(
                      page: 2,
                      pageCount: 5,
                      onChanged: null,
                      previousLabel: (variant.dir == TextDirection.rtl
                          ? 'السابق'
                          : 'Previous'),
                      nextLabel: (variant.dir == TextDirection.rtl
                          ? 'التالي'
                          : 'Next'),
                      pageLabel: (int n) => variant.dir == TextDirection.rtl
                          ? 'الصفحة ${String.fromCharCodes('$n'.codeUnits.map((c) => c + 1584))}'
                          : 'Page $n',
                      format: (int n) => variant.dir == TextDirection.rtl
                          ? String.fromCharCodes(
                              '$n'.codeUnits.map((c) => c + 1584),
                            )
                          : '$n',
                      size: FlPaginationSize.md,
                      showNavLabels: false,
                      showPages: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'popover': (
    version: '0.2.4',
    canvas: const Size(390, 340),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: Builder(
                      builder: (context) {
                        final controller = FlPopoverController();
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => controller.open(),
                        );
                        return FlPopover(
                          controller: controller,
                          label: (variant.dir == TextDirection.rtl
                              ? 'عوامل التصفية'
                              : 'Filters'),
                          title: (variant.dir == TextDirection.rtl
                              ? 'عوامل التصفية'
                              : 'Filters'),
                          description: (variant.dir == TextDirection.rtl
                              ? 'الأحدث أولاً، في كل المجلدات.'
                              : 'Newest first, in all folders.'),
                          closeLabel: (variant.dir == TextDirection.rtl
                              ? 'إغلاق'
                              : 'Close'),
                          width: 280,
                          child: FlPressable(
                            onPressed: controller.toggle,
                            label: (variant.dir == TextDirection.rtl
                                ? 'عوامل التصفية'
                                : 'Filters'),
                            borderRadius: FlScope.of(context)
                                .shape
                                .buttonRadius,
                            builder: (context, states) => Padding(
                              padding: EdgeInsetsDirectional.all(
                                FlScope.of(context).space.md,
                              ),
                              child: Text(
                                (variant.dir == TextDirection.rtl
                                    ? 'عوامل التصفية'
                                    : 'Filters'),
                                style: TextStyle(
                                  color: FlScope.of(context).colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'progress': (
    version: '0.2.5',
    canvas: const Size(390, 360),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 600),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                FlProgress.linear(
                  value: 0.4,
                  label: (variant.dir == TextDirection.rtl
                      ? 'الرفع'
                      : 'Uploading'),
                  showLabel: true,
                ),
                for (final s in FlProgressSize.values)
                  FlProgress.linear(
                    value: 0.7,
                    size: s,
                    color: FlProgressColor.values[s.index + 2],
                    label: (variant.dir == TextDirection.rtl
                        ? 'التخزين'
                        : 'Storage'),
                  ),
                FlProgress.linear(
                  label: (variant.dir == TextDirection.rtl
                      ? 'التحضير'
                      : 'Preparing'),
                ),
                Row(
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    for (final s in FlProgressSize.values)
                      FlProgress.circular(
                        value: 0.7,
                        size: s,
                        label: (variant.dir == TextDirection.rtl
                            ? 'المزامنة'
                            : 'Syncing'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'radio': (
    version: '0.2.3',
    canvas: null,
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: Locale(variant.dir == TextDirection.rtl ? 'ar' : 'en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: FlRadioGroup<int>(
                  groupValue: 2,
                  onChanged: (_) {},
                  children: [
                    for (final (fr, ar, on, enabled) in [
                      ('Standard', 'عادي', 1, true),
                      ('Express', 'سريع', 2, true),
                      (
                        'Parcel locker (unavailable)',
                        'خزانة (غير متاحة)',
                        3,
                        false,
                      ),
                    ])
                      FlRadioGroupItem<int>(
                        value: on,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                        disabled: enabled ? null : true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'range-calendar': (
    version: '0.2.3',
    canvas: const Size(760, 2000),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Wrap(
              spacing: FlScope.of(context).space.lg,
              runSpacing: FlScope.of(context).space.lg,
              children: [
                SizedBox(
                  width: 320,
                  child: FlRangeCalendar(
                    value: FlDateRange(
                      DateTime(2026, 10, 8),
                      DateTime(2026, 10, 19),
                    ),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تواريخ الإقامة'
                        : 'Stay dates'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlRangeCalendar(
                    value: FlDateRange(
                      DateTime(2026, 10, 27),
                      DateTime(2026, 11, 4),
                    ),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    focusedDate: DateTime(2026, 10, 27),
                    weeksInMonth: 6,
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تواريخ الاستئجار'
                        : 'Rental dates'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlRangeCalendar(
                    value: FlDateRange(
                      DateTime(2026, 10, 12),
                      DateTime(2026, 10, 16),
                    ),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    isUnavailable: (day) =>
                        day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday,
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'أسبوع العمل'
                        : 'Work week'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlRangeCalendar(
                    value: FlDateRange(
                      DateTime(2026, 10, 21),
                      DateTime(2026, 10, 21),
                    ),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    minDate: DateTime(2026, 10, 5),
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'الفترة'
                        : 'Period'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: FlRangeCalendar(
                    value: null,
                    initialStart: DateTime(2026, 10, 12),
                    onChanged: (_) {},
                    today: DateTime(2026, 10, 24),
                    strings: FlCalendarStrings.language(
                      variant.dir == TextDirection.rtl ? 'ar' : 'en',
                    ),
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'تواريخ الإجازة'
                        : 'Vacation dates'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'scroll-shadow': (
    version: '0.2.1',
    canvas: const Size(390, 280),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                SizedBox(
                  height: 160,
                  child: FlScrollShadow(
                    child: ListView(
                      controller: ScrollController(initialScrollOffset: 80),
                      children: [
                        for (var i = 0; i < 8; i++)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              bottom: FlScope.of(context).space.sm,
                            ),
                            child: SizedBox(
                              width: null,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: FlScope.of(context)
                                      .colors
                                      .surfaceSecondary,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(
                                      FlScope.of(context).shape.radiusMd,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: FlScrollShadow(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < 8; i++)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: FlScope.of(context).space.sm,
                            ),
                            child: SizedBox(
                              width: 96,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: FlScope.of(context)
                                      .colors
                                      .surfaceSecondary,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(
                                      FlScope.of(context).shape.radiusMd,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'search-field': (
    version: '0.2.4',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: FlScope.of(context).space.lg,
                        children: [
                          FlSearchField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            clearLabel: (variant.dir == TextDirection.rtl
                                ? 'مسح البحث'
                                : 'Clear search'),
                            placeholder: (variant.dir == TextDirection.rtl
                                ? 'ابحث…'
                                : 'Search…'),
                          ),
                          FlSearchField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            clearLabel: (variant.dir == TextDirection.rtl
                                ? 'مسح البحث'
                                : 'Clear search'),
                            controller: TextEditingController(
                              text: (variant.dir == TextDirection.rtl
                                  ? 'تفاح'
                                  : 'Apple'),
                            ),
                          ),
                          FlSearchField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            clearLabel: (variant.dir == TextDirection.rtl
                                ? 'مسح البحث'
                                : 'Clear search'),
                            controller: TextEditingController(
                              text: (variant.dir == TextDirection.rtl
                                  ? 'تفاح'
                                  : 'Apple'),
                            ),
                            variant: FlInputVariant.secondary,
                            searchIcon: false,
                          ),
                          FlSearchField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            clearLabel: (variant.dir == TextDirection.rtl
                                ? 'مسح البحث'
                                : 'Clear search'),
                            controller: TextEditingController(
                              text: (variant.dir == TextDirection.rtl
                                  ? 'تفاح'
                                  : 'Apple'),
                            ),
                            invalid: true,
                          ),
                          FlSearchField(
                            label: (variant.dir == TextDirection.rtl
                                ? 'بحث'
                                : 'Search'),
                            clearLabel: (variant.dir == TextDirection.rtl
                                ? 'مسح البحث'
                                : 'Clear search'),
                            controller: TextEditingController(
                              text: (variant.dir == TextDirection.rtl
                                  ? 'تفاح'
                                  : 'Apple'),
                            ),
                            disabled: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'section-header': (
    version: '0.2.2',
    canvas: const Size(390, 280),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlSectionHeader(
                  title: (variant.dir == TextDirection.rtl
                      ? 'الحساب'
                      : 'Account'),
                ),
                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: FlScope.of(context).colors.surfaceRaised,
                      shape: FlContinuousBorder(
                        radius: FlScope.of(context).shape.radiusCard,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: FlScope.of(context).space.xl),
                FlSectionHeader(
                  title: (variant.dir == TextDirection.rtl
                      ? 'الأخيرة'
                      : 'Recent'),
                  action: FlSectionHeaderAction(
                    label: (variant.dir == TextDirection.rtl
                        ? 'عرض الكل'
                        : 'See all'),
                    onPressed: () {},
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: FlScope.of(context).colors.surfaceRaised,
                      shape: FlContinuousBorder(
                        radius: FlScope.of(context).shape.radiusCard,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'segmented': (
    version: '0.3.4',
    canvas: const Size(390, 640),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlSegmented<String>(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'الفترة'
                      : 'Period'),
                  value: 'Week',
                  onChanged: (_) {},
                  segments: [
                    for (final (fr, ar) in const [
                      ('Day', 'يوم'),
                      ('Week', 'أسبوع'),
                      ('Month', 'شهر'),
                    ])
                      FlSegment(
                        value: fr,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                      ),
                  ],
                ),
                FlSegmented<String>(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'الفوترة'
                      : 'Billing'),
                  value: 'Yearly',
                  size: FlSegmentedSize.sm,
                  onChanged: (_) {},
                  segments: [
                    for (final (fr, ar) in const [
                      ('Monthly', 'شهري'),
                      ('Yearly', 'سنوي'),
                    ])
                      FlSegment(
                        value: fr,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                      ),
                  ],
                ),
                FlSegmented<String>(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'العرض'
                      : 'View'),
                  value: 'Grid',
                  size: FlSegmentedSize.lg,
                  onChanged: (_) {},
                  segments: [
                    for (final (fr, ar) in const [
                      ('List', 'قائمة'),
                      ('Grid', 'شبكة'),
                      ('Map', 'خريطة'),
                    ])
                      FlSegment(
                        value: fr,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                        icon: Builder(
                          builder: (context) => Center(
                            child: SizedBox.square(
                              dimension: IconTheme.of(context).size! / 2,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: IconTheme.of(context).color,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                FlSegmented<String>(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'المدة'
                      : 'Duration'),
                  value: '30 d',
                  onChanged: (_) {},
                  segments: [
                    for (final (i, (fr, ar)) in const [
                      ('7 d', '٧ أيام'),
                      ('30 d', '٣٠ يومًا'),
                      ('90 d', '٩٠ يومًا'),
                      ('6 mo', '٦ أشهر'),
                      ('1 year', 'سنة'),
                    ].indexed)
                      FlSegment(
                        value: fr,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                        disabled: i == 3,
                      ),
                  ],
                ),
                FlSegmented<String>(
                  semanticLabel: (variant.dir == TextDirection.rtl
                      ? 'السمة'
                      : 'Theme'),
                  value: 'Light',
                  enabled: false,
                  onChanged: (_) {},
                  segments: [
                    for (final (fr, ar) in const [
                      ('Light', 'فاتح'),
                      ('Dark', 'داكن'),
                    ])
                      FlSegment(
                        value: fr,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'select': (
    version: '0.2.6',
    canvas: const Size(390, 420),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    FlScope.of(context).space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: FlScope.of(context).space.md,
                    children: [
                      FlSelect<int>(
                        label: (variant.dir == TextDirection.rtl
                            ? 'الحجم'
                            : 'Size'),
                        placeholder: (variant.dir == TextDirection.rtl
                            ? 'اختر حجمًا'
                            : 'Choose a size'),
                        options: const [],
                        selection: FlSingleSelection(
                          value: null,
                          onChanged: null,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final controller = FlSelectController();
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => controller.open(),
                          );
                          return FlSelect<int>(
                            controller: controller,
                            label: (variant.dir == TextDirection.rtl
                                ? 'الفاكهة'
                                : 'Fruit'),
                            placeholder: (variant.dir == TextDirection.rtl
                                ? 'اختر فاكهة'
                                : 'Choose a fruit'),
                            listLabel: (variant.dir == TextDirection.rtl
                                ? 'الفواكه'
                                : 'Fruits'),
                            options: [
                              for (final (i, name)
                                  in (variant.dir == TextDirection.rtl
                                          ? const ['تفاح', 'برتقال', 'موز']
                                          : const ['Apple', 'Orange', 'Banana'])
                                      .indexed)
                                FlSelectOption(value: i, label: name),
                            ],
                            selection: FlSingleSelection(
                              value: 0,
                              onChanged: (_) {},
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'separator': (
    version: '0.2.2',
    canvas: const Size(390, 420),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Text(
                  (variant.dir == TextDirection.rtl
                      ? 'الوضع الداكن'
                      : 'Dark mode'),
                  style: TextStyle(color: FlScope.of(context).colors.onSurface),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: FlScope.of(context).space.sm,
                  ),
                  child: FlSeparator(),
                ),
                Text(
                  (variant.dir == TextDirection.rtl
                      ? 'الإشعارات'
                      : 'Notifications'),
                  style: TextStyle(color: FlScope.of(context).colors.onSurface),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: FlScope.of(context).space.sm,
                  ),
                  child: FlSeparator(variant: FlSeparatorVariant.thick),
                ),
                SizedBox(
                  height: 32,
                  child: Row(
                    spacing: FlScope.of(context).space.sm,
                    children: [
                      Flexible(
                        child: Text(
                          (variant.dir == TextDirection.rtl
                              ? 'واي فاي'
                              : 'Wi-Fi'),
                          style: TextStyle(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                        ),
                      ),
                      FlSeparator(axis: Axis.vertical),
                      Flexible(
                        child: Text(
                          (variant.dir == TextDirection.rtl
                              ? 'بلوتوث'
                              : 'Bluetooth'),
                          style: TextStyle(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'sheet': (
    version: '0.2.4',
    canvas: null,
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: FlScope.of(context).colors.surface),
            FlSheet(
              label: (variant.dir == TextDirection.rtl ? 'مشاركة' : 'Share'),
              title: (variant.dir == TextDirection.rtl ? 'مشاركة' : 'Share'),
              description: (variant.dir == TextDirection.rtl
                  ? 'أرسل نسخة أو انسخ الرابط.'
                  : 'Send a copy or copy the link.'),
              closeLabel: (variant.dir == TextDirection.rtl
                  ? 'إغلاق'
                  : 'Close'),
              barrierLabel: (variant.dir == TextDirection.rtl
                  ? 'إغلاق الورقة'
                  : 'Close the sheet'),
              snaps: const [0.6, 1],
              onDismiss: () {},
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  (variant.dir == TextDirection.rtl
                      ? 'إرسال نسخة'
                      : 'Send a copy'),
                  style: TextStyle(color: FlScope.of(context).colors.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  'skeleton': (
    version: '0.2.1',
    canvas: const Size(390, 320),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlSkeletonGroup(
                  label: (variant.dir == TextDirection.rtl
                      ? 'جارٍ تحميل الملف الشخصي'
                      : 'Loading the profile'),
                  child: Row(
                    spacing: FlScope.of(context).space.md,
                    children: [
                      const FlSkeleton.item(
                        width: 40,
                        height: 40,
                        radius: double.infinity,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: FlScope.of(context).space.xs,
                          children: [
                            FlSkeleton.item(
                              width: 128,
                              height: 12,
                              radius: FlScope.of(context).shape.radiusMd,
                            ),
                            FlSkeleton.item(
                              width: 96,
                              height: 12,
                              radius: FlScope.of(context).shape.radiusMd,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FlSkeleton(
                  label: (variant.dir == TextDirection.rtl
                      ? 'جارٍ تحميل الصورة'
                      : 'Loading the image'),
                  variant: FlSkeletonVariant.pulse,
                  height: 80,
                  radius: FlScope.of(context).shape.radiusLg,
                ),
                FlSkeleton(
                  label: (variant.dir == TextDirection.rtl
                      ? 'جارٍ تحميل العنوان'
                      : 'Loading the title'),
                  variant: FlSkeletonVariant.none,
                  height: 16,
                  radius: FlScope.of(context).shape.radiusMd,
                ),
                FlSkeleton(
                  label: (variant.dir == TextDirection.rtl
                      ? 'جارٍ تحميل الاسم'
                      : 'Loading the name'),
                  loading: false,
                  height: 16,
                  radius: FlScope.of(context).shape.radiusMd,
                  child: Text(
                    (variant.dir == TextDirection.rtl
                        ? 'آدا لوفليس'
                        : 'Ada Lovelace'),
                    style: TextStyle(
                      color: FlScope.of(context).colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'slider': (
    version: '0.2.5',
    canvas: const Size(390, 520),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                FlSlider(
                  value: 0.4,
                  label: (variant.dir == TextDirection.rtl
                      ? 'مستوى الصوت'
                      : 'Volume'),
                  showLabel: true,
                  onChanged: (_) {},
                ),
                FlSlider(
                  value: 0.75,
                  divisions: 4,
                  label: (variant.dir == TextDirection.rtl
                      ? 'السطوع'
                      : 'Brightness'),
                  showLabel: true,
                  onChanged: (_) {},
                ),
                FlSlider(
                  value: 0.6,
                  label: (variant.dir == TextDirection.rtl
                      ? 'التباين'
                      : 'Contrast'),
                  showLabel: true,
                  onChanged: null,
                ),
                FlRangeSlider(
                  values: (start: 0.2, end: 0.7),
                  label: (variant.dir == TextDirection.rtl ? 'السعر' : 'Price'),
                  startLabel: (variant.dir == TextDirection.rtl
                      ? 'أدنى سعر'
                      : 'Minimum price'),
                  endLabel: (variant.dir == TextDirection.rtl
                      ? 'أعلى سعر'
                      : 'Maximum price'),
                  showLabel: true,
                  onChanged: (_) {},
                ),
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      FlSlider(
                        value: 0.6,
                        label: (variant.dir == TextDirection.rtl
                            ? 'الجهير'
                            : 'Bass'),
                        axis: Axis.vertical,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'spinner': (
    version: '0.2.2',
    canvas: const Size(390, 200),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Row(
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'جارٍ التحميل'
                          : 'Loading'),
                      size: FlSpinnerSize.sm,
                    ),
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'جارٍ التحميل'
                          : 'Loading'),
                    ),
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'جارٍ التحميل'
                          : 'Loading'),
                      size: FlSpinnerSize.lg,
                    ),
                  ],
                ),
                Row(
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الإرسال'
                          : 'Sending'),
                      tone: FlSpinnerTone.success,
                    ),
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الإرسال'
                          : 'Sending'),
                      tone: FlSpinnerTone.warning,
                    ),
                    FlSpinner(
                      label: (variant.dir == TextDirection.rtl
                          ? 'الإرسال'
                          : 'Sending'),
                      tone: FlSpinnerTone.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'stepper': (
    version: '0.1.4',
    canvas: const Size(390, 600),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlListGroup(
                  children: [
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? "البالغون"
                          : "Adults"),
                      subtitle: (variant.dir == TextDirection.rtl
                          ? "١٣ سنة فأكثر"
                          : "13 and older"),
                      enabled: true,
                      trailing: FlStepper(
                        label: (variant.dir == TextDirection.rtl
                            ? "البالغون"
                            : "Adults"),
                        value: 2,
                        min: 1,
                        max: 6,
                        decrementLabel: (variant.dir == TextDirection.rtl
                            ? "أقل"
                            : "Fewer"),
                        incrementLabel: (variant.dir == TextDirection.rtl
                            ? "أكثر"
                            : "Plus"),
                        format: (int n) => variant.dir == TextDirection.rtl
                            ? "$n".replaceAllMapped(
                                RegExp("[0-9]"),
                                (m) => "٠١٢٣٤٥٦٧٨٩"[int.parse(m[0]!)],
                              )
                            : "$n",
                        onChanged: (_) {},
                      ),
                    ),
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? "الأطفال"
                          : "Children"),
                      subtitle: (variant.dir == TextDirection.rtl
                          ? "من ٢ إلى ١٢ سنة"
                          : "Ages 2 to 12"),
                      enabled: true,
                      trailing: FlStepper(
                        label: (variant.dir == TextDirection.rtl
                            ? "الأطفال"
                            : "Children"),
                        value: 0,
                        min: 0,
                        max: 4,
                        decrementLabel: (variant.dir == TextDirection.rtl
                            ? "أقل"
                            : "Fewer"),
                        incrementLabel: (variant.dir == TextDirection.rtl
                            ? "أكثر"
                            : "Plus"),
                        format: (int n) => variant.dir == TextDirection.rtl
                            ? "$n".replaceAllMapped(
                                RegExp("[0-9]"),
                                (m) => "٠١٢٣٤٥٦٧٨٩"[int.parse(m[0]!)],
                              )
                            : "$n",
                        onChanged: (_) {},
                      ),
                    ),
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? "الرضّع"
                          : "Infants"),
                      subtitle: (variant.dir == TextDirection.rtl
                          ? "أقل من سنتين"
                          : "Under 2"),
                      enabled: true,
                      trailing: FlStepper(
                        label: (variant.dir == TextDirection.rtl
                            ? "الرضّع"
                            : "Infants"),
                        value: 2,
                        min: 0,
                        max: 2,
                        decrementLabel: (variant.dir == TextDirection.rtl
                            ? "أقل"
                            : "Fewer"),
                        incrementLabel: (variant.dir == TextDirection.rtl
                            ? "أكثر"
                            : "Plus"),
                        format: (int n) => variant.dir == TextDirection.rtl
                            ? "$n".replaceAllMapped(
                                RegExp("[0-9]"),
                                (m) => "٠١٢٣٤٥٦٧٨٩"[int.parse(m[0]!)],
                              )
                            : "$n",
                        onChanged: (_) {},
                      ),
                    ),
                    FlListRow(
                      title: (variant.dir == TextDirection.rtl
                          ? "الحيوانات"
                          : "Pets"),
                      enabled: false,
                      trailing: FlStepper(
                        label: (variant.dir == TextDirection.rtl
                            ? "الحيوانات"
                            : "Pets"),
                        value: 1,
                        min: 0,
                        max: 2,
                        decrementLabel: (variant.dir == TextDirection.rtl
                            ? "أقل"
                            : "Fewer"),
                        incrementLabel: (variant.dir == TextDirection.rtl
                            ? "أكثر"
                            : "Plus"),
                        format: (int n) => variant.dir == TextDirection.rtl
                            ? "$n".replaceAllMapped(
                                RegExp("[0-9]"),
                                (m) => "٠١٢٣٤٥٦٧٨٩"[int.parse(m[0]!)],
                              )
                            : "$n",
                        onChanged: null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'surface': (
    version: '0.2.1',
    canvas: const Size(390, 760),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlSurface(
                  child: Text(
                    (variant.dir == TextDirection.rtl
                        ? 'اشتراك احترافي'
                        : 'Pro subscription'),
                    style: TextStyle(
                      color: FlScope.of(context).colors.onSurface,
                    ),
                  ),
                ),
                FlSurface(
                  variant: FlSurfaceVariant.secondary,
                  child: Text(
                    (variant.dir == TextDirection.rtl
                        ? 'الفاتورة القادمة في 3 مارس'
                        : 'Next invoice on March 3'),
                    style: TextStyle(
                      color: FlScope.of(context).colors.onSurface,
                    ),
                  ),
                ),
                FlSurface(
                  variant: FlSurfaceVariant.tertiary,
                  child: Text(
                    (variant.dir == TextDirection.rtl
                        ? 'وسيلة الدفع'
                        : 'Payment method'),
                    style: TextStyle(
                      color: FlScope.of(context).colors.onSurface,
                    ),
                  ),
                ),
                FlSurface(
                  variant: FlSurfaceVariant.transparent,
                  child: Text(
                    (variant.dir == TextDirection.rtl ? 'السجل' : 'History'),
                    style: TextStyle(
                      color: FlScope.of(context).colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'switch-group': (
    version: '0.2.3',
    canvas: const Size(390, 1100),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: Locale(variant.dir == TextDirection.rtl ? 'ar' : 'en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: ColoredBox(
              color: FlScope.of(context).colors.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.all(
                  FlScope.of(context).space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: FlScope.of(context).space.xl,
                  children: [
                    FlSwitchGroup(
                      label: (variant.dir == TextDirection.rtl
                          ? 'التنبيهات'
                          : 'Alerts'),
                      description: (variant.dir == TextDirection.rtl
                          ? 'لكل رسالة واردة'
                          : 'For each message received'),
                      options: [
                        FlSwitchGroupOption(
                          value: true,
                          onChanged: (_) {},
                          label: (variant.dir == TextDirection.rtl
                              ? 'الأصوات'
                              : 'Sounds'),
                        ),
                        FlSwitchGroupOption(
                          value: false,
                          onChanged: (_) {},
                          label: (variant.dir == TextDirection.rtl
                              ? 'الشارات'
                              : 'Badges'),
                          description: (variant.dir == TextDirection.rtl
                              ? 'على أيقونة التطبيق'
                              : 'On the app icon'),
                        ),
                        FlSwitchGroupOption(
                          value: true,
                          onChanged: null,
                          label: (variant.dir == TextDirection.rtl
                              ? 'المعاينات'
                              : 'Previews'),
                        ),
                      ],
                    ),
                    FlSwitchGroup(
                      label: (variant.dir == TextDirection.rtl
                          ? 'المزامنة'
                          : 'Syncing'),
                      invalid: true,
                      error: (variant.dir == TextDirection.rtl
                          ? 'فعّل خيارًا واحدًا على الأقل'
                          : 'Turn on at least one option'),
                      options: [
                        FlSwitchGroupOption(
                          value: false,
                          onChanged: (_) {},
                          label: (variant.dir == TextDirection.rtl
                              ? 'الصور'
                              : 'Photos'),
                        ),
                        FlSwitchGroupOption(
                          value: false,
                          onChanged: (_) {},
                          label: (variant.dir == TextDirection.rtl
                              ? 'جهات الاتصال'
                              : 'Contacts'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  'switch': (
    version: '0.2.4',
    canvas: null,
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                for (final (fr, ar, on, enabled) in [
                  ('Wi-Fi', 'واي فاي', true, true),
                  ('Bluetooth', 'بلوتوث', false, true),
                  ('Airplane mode', 'وضع الطيران', true, false),
                ])
                  Row(
                    spacing: FlScope.of(context).space.md,
                    children: [
                      Expanded(
                        child: Text(
                          variant.dir == TextDirection.rtl ? ar : fr,
                          style: TextStyle(
                            color: FlScope.of(context).colors.onSurface,
                          ),
                        ),
                      ),
                      FlSwitch(
                        value: on,
                        label: variant.dir == TextDirection.rtl ? ar : fr,
                        onChanged: enabled ? (_) {} : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'tab-bar': (
    version: '0.3.1',
    canvas: const Size(390, 760),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final theme = FlScope.of(context);
            final rtl = variant.dir == TextDirection.rtl;
            Widget glyph(ShapeBorder shape) => Builder(
              builder: (context) => SizedBox.square(
                dimension: 18,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: IconTheme.of(context).color,
                    shape: shape,
                  ),
                ),
              ),
            );
            List<FlBottomTab> tabs(
              int count, {
              bool badge = false,
              bool filled = false,
            }) => [
              for (final (i, (en, ar)) in [
                ('Home', 'الرئيسية'),
                ('Messages', 'الرسائل'),
                ('Alerts', 'التنبيهات'),
                ('Profile', 'الملف'),
                ('Settings', 'الإعدادات'),
              ].take(count).indexed)
                FlBottomTab(
                  label: rtl ? ar : en,
                  icon: glyph(const CircleBorder()),
                  selectedIcon: filled
                      ? glyph(const RoundedRectangleBorder())
                      : null,
                  badge: badge && i == 1
                      ? Semantics(
                          label: rtl ? 'غير مقروءة' : 'Unread',
                          child: SizedBox.square(
                            dimension: 10,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: theme.colors.dangerFill,
                                shape: const CircleBorder(),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
            ];
            Widget over(Widget bar) => SizedBox(
              height: 120,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final color in [
                          theme.colors.accentSoft,
                          theme.colors.successSoft,
                          theme.colors.dangerSoft,
                        ])
                          Expanded(child: ColoredBox(color: color)),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: bar,
                  ),
                ],
              ),
            );
            return ColoredBox(
              color: theme.colors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.lg,
                children: [
                  FlBottomTabBar(index: 0, onSelected: (_) {}, tabs: tabs(3)),
                  FlBottomTabBar(
                    index: 4,
                    onSelected: (_) {},
                    tabs: tabs(5, badge: true),
                  ),
                  FlBottomTabBar(
                    index: 1,
                    onSelected: (_) {},
                    tabs: tabs(4, filled: true),
                  ),
                  FlBottomTabBar(
                    index: 2,
                    onSelected: (_) {},
                    labels: FlBottomTabLabels.selected,
                    tabs: tabs(4),
                  ),
                  over(
                    FlBottomTabBar(
                      index: 1,
                      onSelected: (_) {},
                      translucent: true,
                      tabs: tabs(4),
                    ),
                  ),
                  over(
                    FlBottomTabBar(
                      index: 0,
                      onSelected: (_) {},
                      floating: true,
                      translucent: true,
                      indicator: FlBottomTabIndicator.capsule,
                      tabs: tabs(4, badge: true, filled: true),
                    ),
                  ),
                  FlBottomTabBar(
                    index: 3,
                    onSelected: (_) {},
                    floating: true,
                    labels: FlBottomTabLabels.never,
                    tabs: tabs(4),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ),
  'table': (
    version: '0.1.1',
    canvas: const Size(390, 1000),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Builder(
          builder: (context) {
            final rtl = variant.dir == TextDirection.rtl;
            final theme = FlScope.of(context);
            String tr(String fr, String ar) => rtl ? ar : fr;
            final people = [
              (
                tr('Kate Moore', 'كيت مور'),
                tr('CEO', 'المديرة'),
                tr('Active', 'نشطة'),
                'kate@acme.com',
              ),
              (
                tr('John Smith', 'جون سميث'),
                tr('CTO', 'المدير التقني'),
                tr('Active', 'نشط'),
                'john@acme.com',
              ),
              (
                tr('Sara Johnson', 'سارة جونسون'),
                tr('CMO', 'مديرة التسويق'),
                tr('On leave', 'في إجازة'),
                'sara@acme.com',
              ),
            ];
            final columns = [
              FlTableColumn<(String, String, String, String)>(
                id: 'name',
                label: tr('Name', 'الاسم'),
                text: (p) => p.$1,
                width: 132,
                sortable: true,
              ),
              FlTableColumn<(String, String, String, String)>(
                id: 'role',
                label: tr('Role', 'الدور'),
                text: (p) => p.$2,
                width: 112,
                sortable: true,
              ),
              FlTableColumn<(String, String, String, String)>(
                id: 'status',
                label: tr('Status', 'الحالة'),
                text: (p) => p.$3,
                width: 104,
              ),
              FlTableColumn<(String, String, String, String)>(
                id: 'email',
                label: tr('Email', 'البريد'),
                text: (p) => p.$4,
                width: 152,
              ),
            ];
            final labels = FlTableLabels(
              ascending: tr('Ascending', 'تصاعدي'),
              descending: tr('Descending', 'تنازلي'),
              selectAll: tr('Select all', 'تحديد الكل'),
              loading: tr('Loading', 'جارٍ التحميل'),
              empty: tr('No results', 'لا توجد نتائج'),
            );
            return ColoredBox(
              color: theme.colors.surface,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(theme.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.lg,
                  children: [
                    FlTable<(String, String, String, String)>(
                      label: tr('Team', 'الفريق'),
                      columns: columns,
                      rows: people,
                      rowKey: (p) => p.$4,
                      labels: labels,
                      sort: (
                        column: 'name',
                        direction: FlSortDirection.ascending,
                      ),
                      onSortChanged: (_) {},
                      selected: const {'john@acme.com'},
                      onSelectionChanged: (_) {},
                    ),
                    FlTable<(String, String, String, String)>(
                      label: tr('Roles', 'الأدوار'),
                      variant: FlTableVariant.secondary,
                      columns: columns.take(2).toList(),
                      rows: people,
                      rowKey: (p) => p.$4,
                      labels: labels,
                      sort: (
                        column: 'role',
                        direction: FlSortDirection.descending,
                      ),
                      onSortChanged: (_) {},
                      loading: true,
                    ),
                    FlTable<(String, String, String, String)>(
                      label: tr('Team', 'الفريق'),
                      layout: FlTableLayout.stacked,
                      columns: columns,
                      rows: people.take(2).toList(),
                      rowKey: (p) => p.$4,
                      labels: labels,
                      selected: const {'kate@acme.com'},
                      onSelectionChanged: (_) {},
                    ),
                    FlTable<(String, String, String, String)>(
                      label: tr('Invitations', 'الدعوات'),
                      columns: columns.take(2).toList(),
                      rows: const [],
                      rowKey: (p) => p.$4,
                      labels: labels,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
  'tabs': (
    version: '0.3.3',
    canvas: const Size(390, 360),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.md,
              children: [
                FlTabs(
                  controller: FlTabController(length: 3, initialIndex: 1),
                  labels: [
                    (variant.dir == TextDirection.rtl ? 'الرسائل' : 'Messages'),
                    (variant.dir == TextDirection.rtl ? 'المكالمات' : 'Calls'),
                    (variant.dir == TextDirection.rtl
                        ? 'جهات الاتصال'
                        : 'Contacts'),
                  ],
                ),
                FlTabs(
                  controller: FlTabController(length: 3),
                  variant: FlTabsVariant.secondary,
                  labels: [
                    (variant.dir == TextDirection.rtl ? 'الرسائل' : 'Messages'),
                    (variant.dir == TextDirection.rtl ? 'المكالمات' : 'Calls'),
                    (variant.dir == TextDirection.rtl
                        ? 'جهات الاتصال'
                        : 'Contacts'),
                  ],
                ),
                FlTabs(
                  controller: FlTabController(length: 3),
                  disabled: const {1},
                  separators: true,
                  labels: [
                    (variant.dir == TextDirection.rtl ? 'الرسائل' : 'Messages'),
                    (variant.dir == TextDirection.rtl ? 'المكالمات' : 'Calls'),
                    (variant.dir == TextDirection.rtl
                        ? 'جهات الاتصال'
                        : 'Contacts'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'tag-group': (
    version: '0.2.4',
    canvas: const Size(390, 340),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.lg,
              children: [
                FlTagGroup<int>(
                  tags: [
                    for (final (i, label)
                        in (variant.dir == TextDirection.rtl
                                ? const ['أخبار', 'سفر', 'ألعاب', 'طبخ']
                                : const ['News', 'Travel', 'Games', 'Cooking'])
                            .indexed)
                      FlTag(i, label, disabled: i == 3),
                  ],
                  selection: FlTagSelection.multiple,
                  selected: const {1, 2},
                  onSelectionChanged: (_) {},
                ),
                FlTagGroup<int>(
                  tags: [
                    for (final (i, label)
                        in (variant.dir == TextDirection.rtl
                                ? const ['أخبار', 'سفر']
                                : const ['News', 'Travel'])
                            .indexed)
                      FlTag(i, label),
                  ],
                  variant: FlTagGroupVariant.surface,
                  size: FlTagSize.lg,
                  onRemove: (_) {},
                  removeLabel: (label) => (variant.dir == TextDirection.rtl
                      ? 'إزالة $label'
                      : 'Remove $label'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'text-field': (
    version: '0.2.6',
    canvas: const Size(390, 800),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 300),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(
            textDirection: variant.dir,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ColoredBox(
                    color: FlScope.of(context).colors.surface,
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(
                        FlScope.of(context).space.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: FlScope.of(context).space.md,
                        children: [
                          Builder(
                            builder: (context) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                      final field = FocusManager
                                          .instance
                                          .primaryFocus
                                          ?.context
                                          ?.findAncestorStateOfType<
                                            EditableTextState
                                          >();
                                      if (field == null ||
                                          field
                                              .textEditingValue
                                              .text
                                              .isNotEmpty)
                                        return;
                                      final (
                                        text,
                                        word,
                                      ) = variant.dir == TextDirection.rtl
                                          ? ('موعدنا غدا عند الظهر', 'غدا')
                                          : (
                                              'Appointment tomorrow at noon',
                                              'tomorrow',
                                            );
                                      final start = text.indexOf(word);
                                      field
                                        ..userUpdateTextEditingValue(
                                          TextEditingValue(
                                            text: text,
                                            selection: TextSelection(
                                              baseOffset: start,
                                              extentOffset: start + word.length,
                                            ),
                                          ),
                                          SelectionChangedCause.longPress,
                                        )
                                        ..showToolbar();
                                    }),
                              );
                              return FlTextField(
                                label: variant.dir == TextDirection.rtl
                                    ? 'الموعد'
                                    : 'Appointment',
                                autofocus: true,
                              );
                            },
                          ),
                          const SizedBox(height: 140),
                          FlTextField(
                            label: variant.dir == TextDirection.rtl
                                ? 'البريد الإلكتروني'
                                : 'Email',
                            controller: TextEditingController(text: 'name@'),
                            error: variant.dir == TextDirection.rtl
                                ? 'عنوان غير صالح'
                                : 'Invalid address',
                          ),
                          FlTextField(
                            label: variant.dir == TextDirection.rtl
                                ? 'المعرّف'
                                : 'Username',
                            controller: TextEditingController(text: 'demo'),
                            enabled: false,
                          ),
                          FlTextField(
                            label: variant.dir == TextDirection.rtl
                                ? 'كلمة المرور'
                                : 'Password',
                            controller: TextEditingController(text: 'secret'),
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'text': (
    version: '0.2.2',
    canvas: const Size(390, 820),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlText(
                  (variant.dir == TextDirection.rtl ? 'الإعدادات' : 'Settings'),
                  type: FlTextType.h2,
                ),
                FlText(
                  (variant.dir == TextDirection.rtl ? 'الخصوصية' : 'Privacy'),
                  type: FlTextType.h5,
                ),
                FlText(
                  (variant.dir == TextDirection.rtl
                      ? 'تبقى بياناتك على هذا الجهاز.'
                      : 'Your data stays on this device.'),
                ),
                FlText(
                  (variant.dir == TextDirection.rtl
                      ? 'آخر مزامنة الساعة 9:41'
                      : 'Last synced at 9:41'),
                  type: FlTextType.bodySm,
                  tone: FlTextTone.muted,
                ),
                const FlText('flutter pub get', type: FlTextType.code),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'time-field': (
    version: '0.2.4',
    canvas: const Size(390, 640),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlTimeField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'وقت الموعد'
                      : 'Appointment time'),
                  value: null,
                  onChanged: (_) {},
                  autofocus: true,
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlTimeField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'المنبّه'
                      : 'Alarm'),
                  value: const FlTime(7, 30),
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlTimeField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'وقت الوصول'
                      : 'Arrival time'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'التوقيت المحلي'
                      : 'Local time'),
                  required: true,
                  value: null,
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlTimeField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'الاستلام'
                      : 'Pickup'),
                  error: (variant.dir == TextDirection.rtl
                      ? 'يغلق المتجر الساعة ٧ مساءً'
                      : 'The store closes at 7 PM'),
                  value: const FlTime(20, 15),
                  onChanged: (_) {},
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
                FlTimeField(
                  label: (variant.dir == TextDirection.rtl
                      ? 'المغادرة'
                      : 'Departure'),
                  value: const FlTime(14, 5),
                  onChanged: null,
                  strings: FlDateFieldStrings.language(
                    variant.dir == TextDirection.rtl ? 'ar' : 'en',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'toast': (
    version: '0.2.6',
    canvas: const Size(390, 900),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                FlToast(
                  title: (variant.dir == TextDirection.rtl
                      ? 'تم نسخ الرابط'
                      : 'Link copied'),
                  closeLabel: (variant.dir == TextDirection.rtl
                      ? 'إغلاق'
                      : 'Close'),
                ),
                FlToast(
                  title: (variant.dir == TextDirection.rtl
                      ? 'تم حفظ الملف'
                      : 'Profile saved'),
                  description: (variant.dir == TextDirection.rtl
                      ? 'يراه فريقك.'
                      : 'Visible to the team.'),
                  variant: FlToastVariant.success,
                  icon: Builder(
                    builder: (context) => SizedBox.square(
                      dimension: IconTheme.of(context).size,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: IconTheme.of(context).color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                FlToast(
                  title: (variant.dir == TextDirection.rtl
                      ? 'تعذّر الإرسال'
                      : 'Couldn’t send'),
                  variant: FlToastVariant.danger,
                  action: FlToastAction(
                    label: (variant.dir == TextDirection.rtl
                        ? 'إعادة'
                        : 'Try again'),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'toggle-button': (
    version: '0.1.1',
    canvas: const Size(390, 360),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  children: [
                    for (final on in [false, true])
                      FlToggleButton(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مفضلة'
                            : 'Favorite'),
                        selected: on,
                        leading: FlIcon(on ? FlIcons.heartFill : FlIcons.heart),
                        onChanged: (_) {},
                      ),
                    for (final on in [false, true])
                      FlToggleButton(
                        label: (variant.dir == TextDirection.rtl
                            ? 'حفظ'
                            : 'Save'),
                        selected: on,
                        variant: FlToggleButtonVariant.ghost,
                        leading: FlIcon(FlIcons.bookmark),
                        onChanged: (_) {},
                      ),
                  ],
                ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  children: [
                    for (final size in FlButtonSize.values)
                      for (final on in [false, true])
                        FlToggleButton.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'مفضلة'
                              : 'Favorite'),
                          selected: on,
                          size: size,
                          icon: FlIcon(on ? FlIcons.starFill : FlIcons.star),
                          onChanged: (_) {},
                        ),
                  ],
                ),
                Wrap(
                  spacing: FlScope.of(context).space.sm,
                  runSpacing: FlScope.of(context).space.sm,
                  children: [
                    for (final on in [false, true])
                      FlToggleButton(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مفضلة'
                            : 'Favorite'),
                        selected: on,
                        leading: FlIcon(FlIcons.heart),
                        onChanged: null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'toolbar': (
    version: '0.1.1',
    canvas: const Size(390, 560),
    platformCanvas: const {},
    settle: null,
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FlScope.of(context).space.sm,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FlToolbar(
                    semanticLabel: (variant.dir == TextDirection.rtl
                        ? 'إجراءات'
                        : 'Actions'),
                    children: [
                      FlToggleButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مفضلة'
                            : 'Favorite'),
                        selected: true,
                        variant: FlToggleButtonVariant.ghost,
                        icon: FlIcon(FlIcons.heartFill),
                        onChanged: (_) {},
                      ),
                      FlToggleButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'حفظ'
                            : 'Save'),
                        selected: false,
                        variant: FlToggleButtonVariant.ghost,
                        icon: FlIcon(FlIcons.bookmark),
                        onChanged: (_) {},
                      ),
                      const FlSeparator(),
                      FlButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'تعديل'
                            : 'Edit'),
                        variant: FlButtonVariant.ghost,
                        icon: FlIcon(FlIcons.pencil),
                        onPressed: () {},
                      ),
                      FlButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مشاركة'
                            : 'Share'),
                        variant: FlButtonVariant.ghost,
                        icon: FlIcon(FlIcons.arrowUpFromSquare),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: FlScope.of(context).space.md,
                  ),
                  child: Center(
                    child: FlToolbar(
                      variant: FlToolbarVariant.attached,
                      children: [
                        FlButtonGroup(
                          items: [
                            FlButtonGroupItem.icon(
                              label: (variant.dir == TextDirection.rtl
                                  ? 'تعديل'
                                  : 'Edit'),
                              icon: FlIcon(FlIcons.pencil),
                              onPressed: () {},
                            ),
                            FlButtonGroupItem.icon(
                              label: (variant.dir == TextDirection.rtl
                                  ? 'مشاركة'
                                  : 'Share'),
                              icon: FlIcon(FlIcons.arrowUpFromSquare),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const FlSeparator(),
                        FlToggleButton.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'مفضلة'
                              : 'Favorite'),
                          selected: true,
                          icon: FlIcon(FlIcons.starFill),
                          onChanged: (_) {},
                        ),
                        FlButton.icon(
                          label: (variant.dir == TextDirection.rtl
                              ? 'حذف'
                              : 'Delete'),
                          variant: FlButtonVariant.tertiary,
                          icon: FlIcon(FlIcons.trashBin),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FlToolbar(
                    axis: Axis.vertical,
                    children: [
                      FlToggleButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مفضلة'
                            : 'Favorite'),
                        selected: false,
                        variant: FlToggleButtonVariant.ghost,
                        icon: FlIcon(FlIcons.heart),
                        onChanged: (_) {},
                      ),
                      FlToggleButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'حفظ'
                            : 'Save'),
                        selected: false,
                        variant: FlToggleButtonVariant.ghost,
                        icon: FlIcon(FlIcons.bookmark),
                        onChanged: (_) {},
                      ),
                      const FlSeparator(),
                      FlButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'تعديل'
                            : 'Edit'),
                        variant: FlButtonVariant.ghost,
                        icon: FlIcon(FlIcons.pencil),
                        onPressed: () {},
                      ),
                      FlButton.icon(
                        label: (variant.dir == TextDirection.rtl
                            ? 'مشاركة'
                            : 'Share'),
                        variant: FlButtonVariant.ghost,
                        icon: FlIcon(FlIcons.arrowUpFromSquare),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  'tooltip': (
    version: '0.2.2',
    canvas: const Size(390, 300),
    platformCanvas: const {},
    settle: const Duration(milliseconds: 400),
    entry: (context, variant) => FlScope(
      brightness: variant.brightness,
      platform: variant.platform,
      child: Builder(
        builder: (context) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: FlScope.of(context).colors.surface,
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final controller = FlTooltipController();
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => controller.show(),
                      );
                      return FlTooltip(
                        message: (variant.dir == TextDirection.rtl
                            ? 'حفظ المسودة'
                            : 'Save draft'),
                        controller: controller,
                        child: FlPressable(
                          onPressed: () {},
                          label: (variant.dir == TextDirection.rtl
                              ? 'حفظ'
                              : 'Save'),
                          borderRadius: FlScope.of(context).shape.buttonRadius,
                          builder: (context, states) => Padding(
                            padding: EdgeInsetsDirectional.all(
                              FlScope.of(context).space.md,
                            ),
                            child: Text(
                              (variant.dir == TextDirection.rtl
                                  ? 'حفظ'
                                  : 'Save'),
                              style: TextStyle(
                                color: FlScope.of(context).colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
};
