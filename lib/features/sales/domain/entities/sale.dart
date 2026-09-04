class SaleItem {
  final String productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  const SaleItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  double get total => quantity * unitPrice;
  double get profit => quantity * (unitPrice - unitCost);
}

class Sale {
  final String id;
  final String invoiceNumber;
  final List<SaleItem> items;
  final double discount;
  final double paidAmount;
  final String paymentMethod;
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.items,
    this.discount = 0,
    required this.paidAmount,
    required this.paymentMethod,
    required this.createdAt,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get profit =>
      items.fold(0, (sum, item) => sum + item.profit) - discount;
  double get change => (paidAmount - total).clamp(0, double.infinity);
}
