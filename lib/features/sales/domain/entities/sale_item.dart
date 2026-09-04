import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  double get total => unitPrice * quantity;
  double get profit => (unitPrice - unitCost) * quantity;

  @override
  List<Object?> get props => [productId, productName, barcode, quantity, unitPrice, unitCost];
}
