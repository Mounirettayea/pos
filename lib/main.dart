import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('pos_sales');
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const PosApp());
}

class Product {
  const Product({required this.id, required this.name, required this.barcode, required this.sell, required this.buy, required this.stock, required this.min, required this.category});
  final String id;
  final String name;
  final String barcode;
  final String category;
  final double sell;
  final double buy;
  final int stock;
  final int min;

  factory Product.fromMap(Map<String, dynamic> m) {
    return Product(
      id: '${m['id']}',
      name: '${m['name'] ?? ''}',
      barcode: '${m['barcode'] ?? ''}',
      category: '${m['category'] ?? ''}',
      sell: (m['sell_price'] as num?)?.toDouble() ?? 0,
      buy: (m['buy_price'] as num?)?.toDouble() ?? 0,
      stock: (m['stock'] as num?)?.toInt() ?? 0,
      min: (m['min_stock'] as num?)?.toInt() ?? 2,
    );
  }
}

class CartItem {
  CartItem(this.product, this.quantity);
  final Product product;
  int quantity;
  double get total => product.sell * quantity;
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAISON AL TEEB POS',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFD4AF37)),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final db = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (db.auth.currentSession == null) return const LoginPage();
        return const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool loading = false;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (signup) {
        await auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const Icon(Icons.point_of_sale, size: 72),
                const SizedBox(height: 12),
                const Text('MAISON AL TEEB POS', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 28),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? '...' : (signup ? 'إنشاء حساب' : 'دخول')))),
                TextButton(onPressed: loading ? null : () => setState(() => signup = !signup), child: Text(signup ? 'عندي حساب — دخول' : 'إنشاء حساب جديد')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final db = Supabase.instance.client;
  final cart = <CartItem>[];
  List<Product> products = [];
  bool loading = true;
  int tab = 0;
  String search = '';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      final rows = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').order('name');
      products = (rows as List).map((e) => Product.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      if (mounted) message('تعذر تحميل المنتجات: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  double get total => cart.fold(0.0, (sum, item) => sum + item.total);

  void addToCart(Product p) {
    if (p.stock < 1) return message('الستوك سالا');
    final index = cart.indexWhere((x) => x.product.id == p.id);
    setState(() {
      if (index < 0) {
        cart.add(CartItem(p, 1));
      } else if (cart[index].quantity < p.stock) {
        cart[index].quantity++;
      }
    });
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code == null || code.isEmpty) return;
    try {
      final row = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').eq('barcode', code).maybeSingle();
      if (row == null) return message('Barcode غير موجود');
      addToCart(Product.fromMap(Map<String, dynamic>.from(row)));
      setState(() => tab = 1);
    } catch (e) {
      message('خطأ في البحث: $e');
    }
  }

  Future<void> checkout() async {
    if (cart.isEmpty) return message('السلة فارغة');
    final method = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('طريقة الأداء'),
        children: const [
          PayOption('cash', 'نقداً'),
          PayOption('card', 'بطاقة'),
          PayOption('transfer', 'تحويل'),
        ],
      ),
    );
    if (method == null) return;
    final amount = total;
    try {
      final items = cart.map((x) => {'product_id': x.product.id, 'quantity': x.quantity}).toList();
      await db.rpc('pos_checkout', params: {
        'p_subtotal': amount,
        'p_discount': 0,
        'p_total': amount,
        'p_payment_method': method,
        'p_items': items,
      });
      await Hive.box('pos_sales').add({'date': DateTime.now().toIso8601String(), 'total': amount, 'payment_method': method});
      setState(() => cart.clear());
      await refresh();
      message('تم البيع: ${amount.toStringAsFixed(2)} DH');
    } catch (e) {
      message('فشل البيع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[dashboard(), sales(), stock(), history()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAISON AL TEEB POS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: scan, icon: const Icon(Icons.qr_code_scanner)),
          IconButton(onPressed: refresh, icon: const Icon(Icons.sync)),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'customers') await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomersPage(db)));
              if (value == 'expenses') await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(db)));
              if (value == 'reports') await Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(db)));
              if (value == 'logout') await db.auth.signOut();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'customers', child: Text('الزبناء')),
              PopupMenuItem(value: 'expenses', child: Text('المصاريف')),
              PopupMenuItem(value: 'reports', child: Text('التقارير')),
              PopupMenuItem(value: 'logout', child: Text('خروج')),
            ],
          ),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(db))).then((_) => refresh()), icon: const Icon(Icons.add), label: const Text('منتج جديد'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'بيع'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'الستوك'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'المبيعات'),
        ],
      ),
    );
  }

  Widget dashboard() {
    final low = products.where((p) => p.stock <= p.min).length;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            metric('المنتجات', '${products.length}', Icons.inventory_2),
            metric('السلة', '${cart.length}', Icons.shopping_cart),
            metric('Stock منخفض', '$low', Icons.warning),
          ]),
          const SizedBox(height: 20),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('Scan Barcode'), onTap: scan),
            ListTile(leading: const Icon(Icons.people), title: const Text('الزبناء'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomersPage(db)))),
            ListTile(leading: const Icon(Icons.money_off), title: const Text('المصاريف'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(db)))),
            ListTile(leading: const Icon(Icons.bar_chart), title: const Text('التقارير'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(db)))),
          ])),
        ],
      ),
    );
  }

  Widget metric(String label, String value, IconData icon) {
    return SizedBox(width: MediaQuery.of(context).size.width / 2 - 22, child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(label), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]))));
  }

  Widget sales() {
    final list = products.where((p) => search.isEmpty || p.name.toLowerCase().contains(search.toLowerCase()) || p.barcode.contains(search)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اسم أو Barcode'))), IconButton.filled(onPressed: scan, icon: const Icon(Icons.qr_code_scanner))])),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: list.length, itemBuilder: (context, i) { final p = list[i]; return ListTile(leading: CircleAvatar(child: Text('${p.stock}')), title: Text(p.name), subtitle: Text('${p.sell.toStringAsFixed(2)} DH • ${p.category}'), trailing: FilledButton(onPressed: p.stock > 0 ? () => addToCart(p) : null, child: const Text('إضافة'))); })),
      if (cart.isNotEmpty) cartPanel(),
    ]);
  }

  Widget cartPanel() {
    return Card(margin: const EdgeInsets.all(8), child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
      for (final item in cart) Row(children: [Expanded(child: Text('${item.product.name} × ${item.quantity}')), Text('${item.total.toStringAsFixed(2)} DH'), IconButton(onPressed: () => setState(() { if (item.quantity > 1) item.quantity--; else cart.remove(item); }), icon: const Icon(Icons.remove_circle))]),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL'), Text('${total.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: checkout, child: const Text('تأكيد البيع'))),
    ])));
  }

  Widget stock() {
    return RefreshIndicator(onRefresh: refresh, child: ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: products.length, itemBuilder: (context, i) {
      final p = products[i];
      return Card(child: ListTile(title: Text(p.name), subtitle: Text('${p.category} • شراء ${p.buy.toStringAsFixed(2)} • بيع ${p.sell.toStringAsFixed(2)} DH\nBarcode: ${p.barcode.isEmpty ? '-' : p.barcode}'), leading: CircleAvatar(child: Text('${p.stock}')), trailing: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(db, product: p))).then((_) => refresh()), icon: const Icon(Icons.edit))));
    }));
  }

  Widget history() {
    return ValueListenableBuilder<Box>(valueListenable: Hive.box('pos_sales').listenable(), builder: (context, box, child) {
      return ListView(padding: const EdgeInsets.all(12), children: [const Text('المبيعات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), for (final value in box.values.toList().reversed) Card(child: ListTile(leading: const Icon(Icons.receipt), title: Text('${value['total']} DH'), subtitle: Text('${value['date']}')))]);
    });
  }
}

class PayOption extends StatelessWidget {
  const PayOption(this.value, this.label, {super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SimpleDialogOption(onPressed: () => Navigator.pop(context, value), child: Text(label));
}

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Scanner Barcode')), body: MobileScanner(onDetect: (capture) {
      for (final barcode in capture.barcodes) {
        final code = barcode.rawValue;
        if (code != null && code.isNotEmpty) {
          Navigator.pop(context, code);
          break;
        }
      }
    }));
  }
}

class ProductForm extends StatefulWidget {
  const ProductForm(this.db, {super.key, this.product});
  final SupabaseClient db;
  final Product? product;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final TextEditingController name;
  late final TextEditingController barcode;
  late final TextEditingController buy;
  late final TextEditingController sell;
  late final TextEditingController stock;
  late final TextEditingController min;
  late final TextEditingController category;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    barcode = TextEditingController(text: p?.barcode ?? '');
    buy = TextEditingController(text: p == null ? '' : p.buy.toString());
    sell = TextEditingController(text: p == null ? '' : p.sell.toString());
    stock = TextEditingController(text: p == null ? '0' : '${p.stock}');
    min = TextEditingController(text: p == null ? '2' : '${p.min}');
    category = TextEditingController(text: p?.category ?? '');
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || sell.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      final data = <String, dynamic>{
        'name': name.text.trim(),
        'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim(),
        'buy_price': double.tryParse(buy.text) ?? 0,
        'sell_price': double.tryParse(sell.text) ?? 0,
        'stock': int.tryParse(stock.text) ?? 0,
        'min_stock': int.tryParse(min.text) ?? 2,
        'category': category.text.trim(),
      };
      if (widget.product == null) {
        final user = widget.db.auth.currentUser;
        if (user == null) throw Exception('خاصك تدخل للحساب');
        data['user_id'] = user.id;
        await widget.db.from('products').insert(data);
      } else {
        await widget.db.from('products').update(data).eq('id', widget.product!.id);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.product == null ? 'منتج جديد' : 'تعديل المنتج')), body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')),
      TextField(controller: barcode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Barcode')),
      TextField(controller: category, decoration: const InputDecoration(labelText: 'الفئة')),
      TextField(controller: buy, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ثمن الشراء')),
      TextField(controller: sell, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ثمن البيع')),
      TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
      TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum stock')),
      const SizedBox(height: 20),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? '...' : 'حفظ')),
    ]));
  }
}

class CustomersPage extends StatelessWidget {
  const CustomersPage(this.db, {super.key});
  final SupabaseClient db;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الزبناء')), body: FutureBuilder<List<dynamic>>(future: db.from('customers').select('id,name,phone').order('name'), builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snapshot.data!;
    return ListView(children: [for (final row in rows) ListTile(leading: const Icon(Icons.person), title: Text('${row['name']}'), subtitle: Text('${row['phone'] ?? ''}'))]);
  }));
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage(this.db, {super.key});
  final SupabaseClient db;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('المصاريف')), body: FutureBuilder<List<dynamic>>(future: db.from('expenses').select('category,amount,note,expense_date').order('expense_date', ascending: false), builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    return ListView(children: [for (final row in snapshot.data!) ListTile(leading: const Icon(Icons.money_off), title: Text('${row['amount']} DH'), subtitle: Text('${row['category'] ?? ''} ${row['note'] ?? ''}'))]);
  }));
}

class ReportsPage extends StatelessWidget {
  const ReportsPage(this.db, {super.key});
  final SupabaseClient db;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('التقارير')), body: FutureBuilder<List<dynamic>>(future: db.from('sales').select('total,profit,payment_method,created_at').order('created_at', ascending: false).limit(100), builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    double total = 0;
    double profit = 0;
    for (final row in snapshot.data!) {
      total += (row['total'] as num?)?.toDouble() ?? 0;
      profit += (row['profit'] as num?)?.toDouble() ?? 0;
    }
    return ListView(padding: const EdgeInsets.all(16), children: [Card(child: ListTile(title: const Text('إجمالي المبيعات'), trailing: Text('${total.toStringAsFixed(2)} DH'))), Card(child: ListTile(title: const Text('الربح'), trailing: Text('${profit.toStringAsFixed(2)} DH'))), const SizedBox(height: 12), for (final row in snapshot.data!) ListTile(title: Text('${row['total']} DH'), subtitle: Text('${row['payment_method'] ?? ''}'))]);
  }));
}
