import 'package:equatable/equatable.dart';
import 'sale_item.dart';

class Sale extends Equatable {
  final String id;
  final List<SaleItem> items;
  final double discount;
  final double paidAmount;
  final String paymentMethod;
  final DateTime createdAt;

  const Sale({required this.id, required this.items, this.discount = 0, required this.paidAmount, required this.paymentMethod, required this.createdAt});

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get total => (subtotal - discount).clamp(0.0, double.infinity).toDouble();
  double get profit => items.fold(0.0, (sum, item) => sum + item.profit) - discount;
  double get change => (paidAmount - total).clamp(0.0, double.infinity).toDouble();

  @override
  List<Object?> get props => [id, items, discount, paidAmount, paymentMethod, createdAt];
}
