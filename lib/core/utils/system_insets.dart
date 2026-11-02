import 'package:flutter/widgets.dart';

/// Bottom padding that keeps a sheet's last control above the system
/// navigation bar.
///
/// A modal bottom sheet draws to the bottom edge of the screen. The sheet's
/// `useSafeArea` flag only insets the top, so the system buttons can cover a
/// Save button unless this padding is added. While the keyboard is open the
/// keyboard inset already clears that bar.
double sheetBottomPadding(BuildContext context, {double base = 20}) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  if (keyboard > 0) return base;
  return base + MediaQuery.viewPaddingOf(context).bottom;
}
