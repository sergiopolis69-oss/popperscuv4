enum PaymentMethod { cash, card, transfer, other }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash: return 'Efectivo';
      case PaymentMethod.card: return 'Tarjeta';
      case PaymentMethod.transfer: return 'Transferencia';
      case PaymentMethod.other: return 'Otra';
    }
  }

  static PaymentMethod fromString(String raw) {
    switch (raw) {
      case 'cash': return PaymentMethod.cash;
      case 'card': return PaymentMethod.card;
      case 'transfer': return PaymentMethod.transfer;
      default: return PaymentMethod.other;
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentMethod.cash: return 'cash';
      case PaymentMethod.card: return 'card';
      case PaymentMethod.transfer: return 'transfer';
      case PaymentMethod.other: return 'other';
    }
  }
}
