enum PaymentMethod {
  cash,
  cc,
  gcash,
  maya,
  seabank,
  other;

  static PaymentMethod fromString(String? value) => switch (value) {
        'cc' => PaymentMethod.cc,
        'gcash' => PaymentMethod.gcash,
        'maya' => PaymentMethod.maya,
        'seabank' => PaymentMethod.seabank,
        'other' => PaymentMethod.other,
        _ => PaymentMethod.cash,
      };

  String get dbValue => name;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.cc => 'CC',
        PaymentMethod.gcash => 'GCash',
        PaymentMethod.maya => 'Maya',
        PaymentMethod.seabank => 'SeaBank',
        PaymentMethod.other => 'Other',
      };
}
