import '../../sales/domain/entities/sale.dart';

class MaisonReceipt {
  const MaisonReceipt({
    required this.invoiceNumber,
    required this.sale,
    this.storeName = 'MAISON AL TEEB',
    this.footer = 'Merci pour votre visite',
  });

  final String invoiceNumber;
  final Sale sale;
  final String storeName;
  final String footer;

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln(storeName)
      ..writeln('--------------------------------')
      ..writeln('Facture: $invoiceNumber')
      ..writeln('Date: ${sale.createdAt}')
      ..writeln('--------------------------------');

    for (final item in sale.items) {
      buffer
        ..writeln(item.productName)
        ..writeln(
          '  ${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} DH'
          ' = ${item.total.toStringAsFixed(2)} DH',
        );
    }

    buffer
      ..writeln('--------------------------------')
      ..writeln('Sous-total: ${sale.subtotal.toStringAsFixed(2)} DH')
      ..writeln('Remise: ${sale.discount.toStringAsFixed(2)} DH')
      ..writeln('TOTAL: ${sale.total.toStringAsFixed(2)} DH')
      ..writeln('Paiement: ${sale.paymentMethod}')
      ..writeln('--------------------------------')
      ..writeln(footer);

    return buffer.toString();
  }
}
