import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un champ requis valide, un champ invalide et un champ désactivé, chacun
/// avec son libellé, sa description et son erreur.
Widget _fields(BuildContext context, {required bool rtl}) {
  Widget field({bool invalid = false, bool disabled = false}) => FlFieldScope(
    invalid: invalid,
    disabled: disabled,
    required: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: FlScope.of(context).space.xs,
      children: [
        FlLabel(tr(rtl, 'Email address', 'البريد الإلكتروني')),
        FlDescription(tr(rtl, 'For receipts only.', 'للإيصالات فقط.'), hideOnInvalid: true),
        FlFieldError(tr(rtl, 'Invalid address.', 'عنوان غير صالح.')),
      ],
    ),
  );
  return columnPage(context, [field(), field(invalid: true), field(disabled: true)]);
}

void main() =>
    verifyItem(item: 'field', testFile: 'test/field_verify_test.dart', size: const Size(390, 700), showcase: _fields);
