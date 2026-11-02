enum ExpenseScope {
  personal,
  joint;

  static ExpenseScope fromString(String? value) =>
      value == 'joint' ? ExpenseScope.joint : ExpenseScope.personal;

  String get dbValue => name;

  String get label => this == ExpenseScope.joint ? 'Joint' : 'Personal';
}

enum TransactionSource {
  manual,
  creditCardStatement;

  static TransactionSource fromString(String? value) =>
      value == 'credit_card_statement'
          ? TransactionSource.creditCardStatement
          : TransactionSource.manual;

  String get dbValue =>
      this == TransactionSource.creditCardStatement ? 'credit_card_statement' : 'manual';
}
