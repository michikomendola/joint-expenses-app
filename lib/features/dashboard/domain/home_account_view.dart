import '../../../data/models/transaction.dart';

/// Which budget Home is showing.
enum HomeAccountView {
  joint,
  personal;

  String get label => this == HomeAccountView.joint ? 'Joint account' : 'Personal';
}

/// Rows that belong on the selected Home screen.
List<TransactionModel> transactionsForHomeView({
  required List<TransactionModel> transactions,
  required HomeAccountView view,
  required String? userId,
}) {
  if (view == HomeAccountView.joint) {
    return transactions.where((t) => t.isJointScope).toList(growable: false);
  }
  if (userId == null) return const [];
  return transactions.where((t) => t.isPersonalFor(userId)).toList(growable: false);
}
