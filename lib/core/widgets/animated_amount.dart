import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/money.dart';

/// Displays a [Money] value and smoothly counts up/down when it changes.
///
/// The tween animates integer minor units; formatting always goes through
/// [CurrencyFormatter] so the displayed value is exact at rest.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.duration = AppConstants.numberAnimation,
    this.textAlign,
    this.maxLines = 1,
  });

  final Money amount;
  final String currency;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amount.minor.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final display = Money.fromMinor(value.round());
        return Text(
          CurrencyFormatter.format(display, currency: currency),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          semanticsLabel: CurrencyFormatter.format(amount, currency: currency),
        );
      },
    );
  }
}
