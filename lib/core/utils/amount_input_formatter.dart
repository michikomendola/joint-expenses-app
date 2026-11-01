import 'package:flutter/services.dart';

/// Restricts input to a positive decimal amount with at most two fraction
/// digits and a sane integer length. Accepts both `.` and `,` as the decimal
/// separator (the comma is normalised to a dot).
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.maxIntegerDigits = 12});

  final int maxIntegerDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) return newValue.copyWith(text: '');

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

    if (text == newValue.text) return newValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length.clamp(0, text.length),
      ),
    );
  }
}
