import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 천 단위 구분자 입력 포매터
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'en_US');
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final numericString = newValue.text.replaceAll(',', '');
    if (numericString.isEmpty || int.tryParse(numericString) == null) return oldValue;
    final formatted = _formatter.format(int.parse(numericString));
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// 스프레드시트 스타일 공통 상수
class SheetStyle {
  static const double borderWidth = 1.0;
  static const double cellPaddingH = 8.0;
  static const double cellPaddingV = 10.0;
  static const double fontSize = 13.0;
  static const double headerFontSize = 12.0;

  static Color borderColor(BuildContext context) =>
    Theme.of(context).dividerColor.withValues(alpha: 0.5);

  static Color headerBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color evenRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

  static Color oddRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerLowest;
}
