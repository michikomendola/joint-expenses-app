import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/home_account_view.dart';

/// Joint account or personal budget. Home, Transactions, and Categories share it.
final homeAccountViewProvider =
    NotifierProvider<HomeAccountViewNotifier, HomeAccountView>(HomeAccountViewNotifier.new);

class HomeAccountViewNotifier extends Notifier<HomeAccountView> {
  @override
  HomeAccountView build() => HomeAccountView.joint;

  void select(HomeAccountView view) => state = view;
}
