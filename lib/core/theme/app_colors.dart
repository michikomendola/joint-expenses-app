import 'package:flutter/material.dart';

/// Semantic colours that Material's [ColorScheme] does not cover.
/// Access with `Theme.of(context).extension<AppColors>()!` or the
/// convenience getter `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.onIncome,
    required this.incomeContainer,
    required this.expense,
    required this.onExpense,
    required this.expenseContainer,
    required this.cardShadow,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.balanceGradientStart,
    required this.balanceGradientEnd,
  });

  final Color income;
  final Color onIncome;
  final Color incomeContainer;
  final Color expense;
  final Color onExpense;
  final Color expenseContainer;
  final Color cardShadow;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color balanceGradientStart;
  final Color balanceGradientEnd;

  static const AppColors light = AppColors(
    income: Color(0xFF1F9D63),
    onIncome: Colors.white,
    incomeContainer: Color(0xFFDDF5E8),
    expense: Color(0xFFE5484D),
    onExpense: Colors.white,
    expenseContainer: Color(0xFFFDE4E4),
    cardShadow: Color(0x14202750),
    skeletonBase: Color(0xFFE8EAF2),
    skeletonHighlight: Color(0xFFF4F5F9),
    balanceGradientStart: Color(0xFF3949AB),
    balanceGradientEnd: Color(0xFF5C6BC0),
  );

  static const AppColors dark = AppColors(
    income: Color(0xFF4ADE80),
    onIncome: Color(0xFF05331B),
    incomeContainer: Color(0xFF14352A),
    expense: Color(0xFFF87171),
    onExpense: Color(0xFF3B0D0F),
    expenseContainer: Color(0xFF3D1F22),
    cardShadow: Color(0x00000000),
    skeletonBase: Color(0xFF262838),
    skeletonHighlight: Color(0xFF30334A),
    balanceGradientStart: Color(0xFF3F51B5),
    balanceGradientEnd: Color(0xFF283593),
  );

  @override
  AppColors copyWith({
    Color? income,
    Color? onIncome,
    Color? incomeContainer,
    Color? expense,
    Color? onExpense,
    Color? expenseContainer,
    Color? cardShadow,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? balanceGradientStart,
    Color? balanceGradientEnd,
  }) {
    return AppColors(
      income: income ?? this.income,
      onIncome: onIncome ?? this.onIncome,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      expense: expense ?? this.expense,
      onExpense: onExpense ?? this.onExpense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      cardShadow: cardShadow ?? this.cardShadow,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      balanceGradientStart: balanceGradientStart ?? this.balanceGradientStart,
      balanceGradientEnd: balanceGradientEnd ?? this.balanceGradientEnd,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      onIncome: Color.lerp(onIncome, other.onIncome, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      onExpense: Color.lerp(onExpense, other.onExpense, t)!,
      expenseContainer:
          Color.lerp(expenseContainer, other.expenseContainer, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight:
          Color.lerp(skeletonHighlight, other.skeletonHighlight, t)!,
      balanceGradientStart:
          Color.lerp(balanceGradientStart, other.balanceGradientStart, t)!,
      balanceGradientEnd:
          Color.lerp(balanceGradientEnd, other.balanceGradientEnd, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
