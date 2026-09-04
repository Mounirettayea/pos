import '../../sales/domain/entities/sale.dart';

class PosCart {
  final List<SaleItem> items;

  const PosCart([this.items = const []]);

  PosCart add(SaleItem item) {
    final next = [...items];
    final index = next.indexWhere((e) => e.productId == item.productId);
    if (index == -1) {
      next.add(item);
    } else {
      final old = next[index];
      next[index] = SaleItem(
        productId: old.productId,
        productName: old.productName,
        barcode: old.barcode,
        quantity: old.quantity + item.quantity,
        unitPrice: old.unitPrice,
        unitCost: old.unitCost,
      );
    }
    return PosCart(next);
  }

  PosCart removeProduct(String productId) =>
      PosCart(items.where((e) => e.productId != productId).toList());

  PosCart changeQuantity(String productId, int quantity) {
    if (quantity <= 0) return removeProduct(productId);
    return PosCart(items.map((e) {
      if (e.productId != productId) return e;
      return SaleItem(
        productId: e.productId,
        productName: e.productName,
        barcode: e.barcode,
        quantity: quantity,
        unitPrice: e.unitPrice,
        unitCost: e.unitCost,
      );
    }).toList());
  }

  double get subtotal => items.fold(0, (s, e) => s + e.total);
  int get itemCount => items.fold(0, (s, e) => s + e.quantity);
}
