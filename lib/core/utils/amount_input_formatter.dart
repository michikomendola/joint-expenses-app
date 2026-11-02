import 'package:flutter/services.dart';

/// Restricts input to a decimal amount with at most two fraction digits and
/// a sane integer length. Accepts both `.` and `,` as the decimal separator
/// (the comma is normalised to a dot). A leading minus is kept only when
/// [allowNegative] is true, so an expense can record a refund.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.maxIntegerDigits = 12, this.allowNegative = false});

  final int maxIntegerDigits;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) return newValue.copyWith(text: '');

    var negative = false;
    if (text.startsWith('-')) {
      if (!allowNegative) return oldValue;
      negative = true;
      text = text.substring(1);
    }
    if (text.contains('-')) return oldValue;
    if (text.isEmpty) {
      return const TextEditingValue(
        text: '-',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    // Only one decimal separator.
    final firstDot = text.indexOf('.');
    if (firstDot != -1) {
      final afterDot = text.substring(firstDot + 1).replaceAll('.', '');
      text = '${text.substring(0, firstDot)}.$afterDot';
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    final parts = text.split('.');
    if (parts[0].length > maxIntegerDigits) return oldValue;
    if (parts.length == 2 && parts[1].length > 2) return oldValue;

    // Avoid leading zeros like "007" (but allow "0." and "0.5").
    if (parts[0].length > 1 && parts[0].startsWith('0')) {
      parts[0] = parts[0].replaceFirst(RegExp(r'^0+'), '');
      if (parts[0].isEmpty) parts[0] = '0';
      text = parts.join('.');
    }

    if (negative) text = '-$text';

    if (text == newValue.text) return newValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length.clamp(0, text.length),
      ),
    );
  }
}
