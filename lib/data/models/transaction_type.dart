enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String value) =>
      value == 'income' ? TransactionType.income : TransactionType.expense;

  String get dbValue => name;

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;

  String get label => isIncome ? 'Income' : 'Expense';

  /// "Received by" for income, "Paid by" for expenses.
  String get actorLabel => isIncome ? 'Received by' : 'Paid by';
}
