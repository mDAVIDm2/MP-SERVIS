/// Стабильные id классов трат (JSON / аналитика).
abstract final class CarExpenseGroupIds {
  static const accessories = 'exp_acc';
  static const unplanned = 'exp_unp';
  static const maintenance = 'exp_maint';
  static const ownership = 'exp_own';
  static const fuel = 'exp_fuel';
  static const cleanComfort = 'exp_clean';

  static const ordered = <String>[
    fuel,
    maintenance,
    ownership,
    accessories,
    unplanned,
    cleanComfort,
  ];
}

abstract final class CarExpenseAccessorySubIds {
  static const replace = 'acc_rep';
  static const retrofit = 'acc_ret';
  static const purchase = 'acc_buy';
}

abstract final class CarExpenseUnplannedSubIds {
  static const fine = 'unp_fine';
  static const tireService = 'unp_tire';
  static const other = 'unp_other';
}
