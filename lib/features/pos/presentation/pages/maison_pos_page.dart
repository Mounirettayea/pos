import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/pos_cart.dart';
import '../../../sales/data/repositories/maison_sales_repository.dart';
import '../../../sales/domain/entities/sale_item.dart';

class MaisonPosPage extends StatefulWidget {
  const MaisonPosPage({super.key});

  @override
  State<MaisonPosPage> createState() => _MaisonPosPageState();
}

class _MaisonPosPageState extends State<MaisonPosPage> {
  PosCart cart = const PosCart();
  final searchController = TextEditingController();
  double discount = 0;
  String paymentMethod = 'cash';
  bool isCheckingOut = false;

  final products = const [
    _PosProduct('p1', 'زيت الخزامى', '30 ml', 59, 'OIL-LAV-30'),
    _PosProduct('p2', 'زيت الليمون', '30 ml', 59, 'OIL-LEM-30'),
    _PosProduct('p3', 'المسك الأسود', '50 ml', 149, 'PER-BMS-50'),
    _PosProduct('p4', 'خمرة دخان', '100 ml', 250, 'PER-KHD-100'),
    _PosProduct('p5', 'صابون اللبان', '100 g', 19, 'SOAP-FRA-100'),
  ];

  List<_PosProduct> get filtered {
    final q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
  }

  void addProduct(_PosProduct p) {
    setState(() {
      cart = cart.add(SaleItem(
        productId: p.id,
        productName: p.name,
        barcode: p.sku,
        quantity: 1,
        unitPrice: p.price,
        unitCost: p.price * .5,
      ));
    });
  }

  double get total => (cart.subtotal - discount).clamp(0, double.infinity).toDouble();

  Future<void> checkout() async {
    if (cart.items.isEmpty || isCheckingOut) return;

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      _showMessage('خاص تسجيل الدخول قبل تسجيل البيع.');
      return;
    }

    setState(() => isCheckingOut = true);
    try {
      final repository = MaisonSalesRepository(client);
      final saleId = await repository.createSale(
        discount: discount,
        paymentMethod: paymentMethod,
        items: cart.items.map((item) => {
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': item.unitCost,
        }).toList(),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vente enregistrée'),
          content: Text('Référence: $saleId\nTotal: ${total.toStringAsFixed(2)} DH\nPaiement: ${paymentMethod == 'cash' ? 'Espèces' : 'Carte'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
      setState(() {
        cart = const PosCart();
        discount = 0;
      });
    } on PostgrestException catch (e) {
      if (mounted) _showMessage('Erreur Supabase: ${e.message}');
    } catch (e) {
      if (mounted) _showMessage('تعذر تسجيل البيع: $e');
    } finally {
      if (mounted) setState(() => isCheckingOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caisse')),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        if (wide) return Row(children: [Expanded(child: _catalog()), SizedBox(width: 380, child: _cartPanel())]);
        return Column(children: [Expanded(child: _catalog()), SizedBox(height: 390, child: _cartPanel())]);
      }),
    );
  }

  Widget _catalog() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      TextField(
        controller: searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher produit / SKU...'),
      ),
      const SizedBox(height: 14),
      Expanded(child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 135, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final p = filtered[i];
          return Card(child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => addProduct(p),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(), Text(p.size), const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${p.price.toStringAsFixed(2)} DH', style: const TextStyle(fontWeight: FontWeight.w900)),
                const Icon(Icons.add_circle_outline),
              ]),
            ])),
          ));
        },
      )),
    ]),
  );

  Widget _cartPanel() => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('Panier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
      const SizedBox(height: 10),
      Expanded(child: cart.items.isEmpty ? const Center(child: Text('Aucun produit')) : ListView.builder(
        itemCount: cart.items.length,
        itemBuilder: (_, i) {
          final item = cart.items[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.productName),
            subtitle: Text('${item.unitPrice.toStringAsFixed(2)} DH × ${item.quantity}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => setState(() => cart = cart.changeQuantity(item.productId, item.quantity - 1)), icon: const Icon(Icons.remove_circle_outline)),
              IconButton(onPressed: () => setState(() => cart = cart.changeQuantity(item.productId, item.quantity + 1)), icon: const Icon(Icons.add_circle_outline)),
            ]),
          );
        },
      )),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sous-total'), Text('${cart.subtotal.toStringAsFixed(2)} DH')]),
      const SizedBox(height: 8),
      Row(children: [
        const Text('Remise'), const Spacer(),
        SizedBox(width: 100, child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'DH', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          onChanged: (v) => setState(() => discount = double.tryParse(v) ?? 0),
        )),
      ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: paymentMethod,
        decoration: const InputDecoration(labelText: 'Paiement'),
        items: const [DropdownMenuItem(value: 'cash', child: Text('Espèces')), DropdownMenuItem(value: 'card', child: Text('Carte'))],
        onChanged: (v) => setState(() => paymentMethod = v ?? 'cash'),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900)),
        Text('${total.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: cart.items.isEmpty || isCheckingOut ? null : checkout,
        icon: isCheckingOut ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
        label: Text(isCheckingOut ? 'Enregistrement...' : 'ENCAISSER'),
      )),
    ])),
  );
}

class _PosProduct {
  const _PosProduct(this.id, this.name, this.size, this.price, this.sku);
  final String id;
  final String name;
  final String size;
  final double price;
  final String sku;
}
