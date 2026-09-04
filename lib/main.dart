import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('pos_sales');

  SupabaseClient? client;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
    client = Supabase.instance.client;
  } catch (_) {
    client = null;
  }

  runApp(MaisonAlTeebApp(client: client));
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category = '',
    this.image = '',
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String image;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? 'Produit'}',
      price: (map['sell_price'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      category: '${map['category'] ?? ''}',
      image: '${map['image_url'] ?? ''}',
    );
  }
}

class CartLine {
  CartLine(this.product, this.quantity);

  final Product product;
  int quantity;

  double get total => product.price * quantity;
}

class MaisonAlTeebApp extends StatelessWidget {
  const MaisonAlTeebApp({super.key, this.client});

  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAISON AL TEEB POS',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF151515),
          elevation: 0,
        ),
      ),
      home: POSHome(client: client),
    );
  }
}

class POSHome extends StatefulWidget {
  const POSHome({super.key, this.client});

  final SupabaseClient? client;

  @override
  State<POSHome> createState() => _POSHomeState();
}

class _POSHomeState extends State<POSHome> {
  int tab = 0;
  List<Product> products = [];
  final List<CartLine> cart = [];
  bool loading = true;
  String error = '';
  String search = '';

  Box get salesBox => Hive.box('pos_sales');

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    List<Product> loaded = [];
    try {
      final client = widget.client;
      if (client != null) {
        final rows = await client
            .from('products')
            .select('id,name,sell_price,stock,category,image_url')
            .order('name');
        loaded = (rows as List)
            .map((row) => Product.fromMap(Map<String, dynamic>.from(row)))
            .toList();
      }
    } catch (_) {
      error = 'تعذر تحميل المنتجات من Supabase';
    }

    if (loaded.isEmpty) {
      loaded = const [
        Product(
          id: 'demo1',
          name: 'عطر Maison Al Teeb',
          price: 159,
          stock: 20,
          category: 'عطور',
        ),
        Product(
          id: 'demo2',
          name: 'زيت أركان طبيعي',
          price: 89,
          stock: 15,
          category: 'زيوت',
        ),
        Product(
          id: 'demo3',
          name: 'Shampoo Argan',
          price: 69,
          stock: 12,
          category: 'عناية',
        ),
      ];
    }

    if (!mounted) return;
    setState(() {
      products = loaded;
      loading = false;
    });
  }

  void addProduct(Product product) {
    if (product.stock <= 0) return;

    final index = cart.indexWhere((line) => line.product.id == product.id);
    setState(() {
      if (index == -1) {
        cart.add(CartLine(product, 1));
      } else if (cart[index].quantity < product.stock) {
        cart[index].quantity++;
      }
    });
  }

  void decreaseProduct(CartLine line) {
    setState(() {
      if (line.quantity > 1) {
        line.quantity--;
      } else {
        cart.remove(line);
      }
    });
  }

  double get total => cart.fold(0, (sum, line) => sum + line.total);

  Future<void> checkout() async {
    if (cart.isEmpty) return;

    final items = cart
        .map(
          (line) => {
            'name': line.product.name,
            'qty': line.quantity,
            'price': line.product.price,
          },
        )
        .toList();

    await salesBox.add({
      'date': DateTime.now().toIso8601String(),
      'total': total,
      'items': items,
    });

    final client = widget.client;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final sale = await client
            .from('sales')
            .insert({
              'user_id': user.id,
              'subtotal': total,
              'discount': 0,
              'total': total,
              'profit': 0,
              'payment_method': 'cash',
            })
            .select('id')
            .single();

        for (final line in cart) {
          await client.from('sale_items').insert({
            'sale_id': sale['id'],
            'product_id': line.product.id,
            'quantity': line.quantity,
            'unit_buy_price': 0,
            'unit_sell_price': line.product.price,
            'line_total': line.total,
            'line_profit': line.total,
          });
        }
      } catch (_) {
        // The local sale is already saved; keep POS usable offline.
      }
    }

    if (!mounted) return;
    setState(() => cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل البيع بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboardPage(),
      salePage(),
      productsPage(),
      historyPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MAISON AL TEEB',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: loadProducts,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'بيع',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'المبيعات',
          ),
        ],
      ),
    );
  }

  Widget dashboardPage() {
    final now = DateTime.now();
    double todayTotal = 0;
    for (final value in salesBox.values) {
      if (value is! Map) continue;
      final date = DateTime.tryParse('${value['date']}');
      final amount = value['total'];
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day &&
          amount is num) {
        todayTotal += amount.toDouble();
      }
    }

    final lowStock = products.where((p) => p.stock <= 5).length;

    return RefreshIndicator(
      onRefresh: loadProducts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tableau de bord',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              kpi('مبيعات اليوم', '${todayTotal.toStringAsFixed(2)} DH', Icons.payments),
              kpi('عدد المنتجات', '${products.length}', Icons.inventory_2),
              kpi('السلة الحالية', '${cart.length}', Icons.shopping_cart),
              kpi('مخزون منخفض', '$lowStock', Icons.warning_amber),
            ],
          ),
          const SizedBox(height: 25),
          Card(
            child: Column(
              children: [
                actionTile(
                  Icons.point_of_sale,
                  'بيع جديد',
                  'اختار المنتجات وسجل البيع',
                  () => setState(() => tab = 1),
                ),
                actionTile(
                  Icons.inventory_2,
                  'المنتجات والمخزون',
                  'شوف المنتجات والكميات المتوفرة',
                  () => setState(() => tab = 2),
                ),
                actionTile(
                  Icons.receipt_long,
                  'تاريخ المبيعات',
                  'شوف جميع عمليات البيع',
                  () => setState(() => tab = 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget kpi(String title, String value, IconData icon) {
    final width = MediaQuery.of(context).size.width / 2 - 22;
    return SizedBox(
      width: width > 150 ? width : 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(title),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget actionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget salePage() {
    final filtered = products.where((product) {
      final query = search.trim().toLowerCase();
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث عن منتج...',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) => setState(() => search = value),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('ما كاين حتى منتج'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${product.price.toInt()}'),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.category} • Stock: ${product.stock}',
                          ),
                          trailing: FilledButton(
                            onPressed: product.stock > 0
                                ? () => addProduct(product)
                                : null,
                            child: const Text('إضافة'),
                          ),
                        );
                      },
                    ),
        ),
        if (cart.isNotEmpty) cartPanel(),
      ],
    );
  }

  Widget cartPanel() {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ...cart.map(
              (line) => Row(
                children: [
                  Expanded(
                    child: Text('${line.product.name} × ${line.quantity}'),
                  ),
                  Text('${line.total.toStringAsFixed(2)} DH'),
                  IconButton(
                    onPressed: () => decreaseProduct(line),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${total.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: checkout,
                icon: const Icon(Icons.check),
                label: const Text('تأكيد البيع'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget productsPage() {
    return RefreshIndicator(
      onRefresh: loadProducts,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'المنتجات والمخزون',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ...products.map(
              (product) => Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    '${product.category} • ${product.price.toStringAsFixed(2)} DH',
                  ),
                  trailing: Chip(label: Text('${product.stock}')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget historyPage() {
    final rows = salesBox.values.whereType<Map>().toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'المبيعات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('لا توجد مبيعات بعد')),
          )
        else
          ...rows.map((row) {
            final amount = row['total'];
            final items = row['items'];
            final date = '${row['date'] ?? ''}';
            final totalText = amount is num
                ? '${amount.toDouble().toStringAsFixed(2)} DH'
                : '0.00 DH';
            final itemCount = items is List ? items.length : 0;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(totalText),
                subtitle: Text(date),
                trailing: Text('$itemCount منتجات'),
              ),
            );
          }),
      ],
    );
  }
}
