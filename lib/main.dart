import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  const Product({required this.id, required this.name, required this.sell, required this.buy, required this.stock, required this.min, required this.category, required this.barcode});
  final String id;
  final String name;
  final double sell;
  final double buy;
  final int stock;
  final int min;
  final String category;
  final String barcode;

  factory Product.fromMap(Map<String, dynamic> m) {
    return Product(
      id: '${m['id']}',
      name: '${m['name'] ?? ''}',
      sell: (m['sell_price'] as num?)?.toDouble() ?? 0,
      buy: (m['buy_price'] as num?)?.toDouble() ?? 0,
      stock: (m['stock'] as num?)?.toInt() ?? 0,
      min: (m['min_stock'] as num?)?.toInt() ?? 2,
      category: '${m['category'] ?? ''}',
      barcode: '${m['barcode'] ?? ''}',
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  final db = Supabase.instance.client;
  @override Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snap) {
        if (db.auth.currentSession != null) return const HomePage();
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool signup = false;
  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => loading = true);
    try {
      if (signup) {
        await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب. إذا طلب التأكيد، أكد البريد ثم سجل الدخول.')));
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(children: [
      const Icon(Icons.point_of_sale, size: 72),
      const SizedBox(height: 12),
      const Text('MAISON AL TEEB POS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 28),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? '...' : (signup ? 'إنشاء حساب' : 'دخول')))),
      TextButton(onPressed: loading ? null : () => setState(() => signup = !signup), child: Text(signup ? 'عندي حساب — دخول' : 'إنشاء حساب جديد')),
    ]))));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final db = Supabase.instance.client;
  final cart = <CartItem>[];
  List<Product> products = [];
  bool loading = true;
  String search = '';
  int tab = 0;

  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').order('name');
      products = (data as List).map((e) => Product.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) { if (mounted) showError('تعذر تحميل المنتجات: $e'); }
    if (mounted) setState(() => loading = false);
  }
  void showError(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  double get total => cart.fold(0, (sum, x) => sum + x.total);
  void add(Product p) {
    if (p.stock < 1) return showError('Stock سالا');
    final i = cart.indexWhere((x) => x.product.id == p.id);
    setState(() {
      if (i < 0) cart.add(CartItem(p, 1));
      else if (cart[i].quantity < p.stock) cart[i].quantity++;
    });
  }
  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code == null || code.isEmpty) return;
    try {
      final row = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').eq('barcode', code).maybeSingle();
      if (row == null) return showError('Barcode غير موجود');
      add(Product.fromMap(Map<String, dynamic>.from(row)));
      setState(() => tab = 1);
    } catch (e) { showError('$e'); }
  }
  Future<void> checkout() async {
    if (cart.isEmpty) return;
    final method = await showDialog<String>(context: context, builder: (_) => SimpleDialog(title: const Text('طريقة الأداء'), children: const [
      _PayOption('cash', 'نقداً'), _PayOption('card', 'بطاقة'), _PayOption('transfer', 'تحويل'),
    ]));
    if (method == null) return;
    try {
      final items = cart.map((x) => {'product_id': x.product.id, 'quantity': x.quantity}).toList();
      await db.rpc('pos_checkout', params: {'p_subtotal': total, 'p_discount': 0, 'p_total': total, 'p_payment_method': method, 'p_items': items});
      await Hive.box('pos_sales').add({'date': DateTime.now().toIso8601String(), 'total': total});
      final paid = total;
      setState(() => cart.clear());
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم البيع: ${paid.toStringAsFixed(2)} DH')));
    } catch (e) { showError('فشل البيع: $e'); }
  }
  @override Widget build(BuildContext context) {
    final pages = <Widget>[_dashboard(), _sales(), _stock(), _history()];
    return Scaffold(
      appBar: AppBar(title: const Text('MAISON AL TEEB POS', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: scan, icon: const Icon(Icons.qr_code_scanner)), IconButton(onPressed: refresh, icon: const Icon(Icons.sync)), PopupMenuButton<String>(onSelected: (v) async { if (v == 'customers') { await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomersPage(db))); } if (v == 'expenses') { await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(db))); } if (v == 'reports') { await Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(db))); } if (v == 'logout') { await db.auth.signOut(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'customers', child: Text('الزبناء')), PopupMenuItem(value: 'expenses', child: Text('المصاريف')), PopupMenuItem(value: 'reports', child: Text('التقارير')), PopupMenuItem(value: 'logout', child: Text('خروج'))])]),
      body: pages[tab],
      floatingActionButton: tab == 2 ? FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(db: db))).then((_) => refresh()), icon: const Icon(Icons.add), label: const Text('منتج جديد')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'), NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'بيع'), NavigationDestination(icon: Icon(Icons.inventory_2), label: 'الستوك'), NavigationDestination(icon: Icon(Icons.receipt_long), label: 'المبيعات')]),
    );
  }
  Widget _dashboard() {
    final low = products.where((p) => p.stock <= p.min).length;
    double today = 0;
    final now = DateTime.now();
    for (final v in Hive.box('pos_sales').values) {
      if (v is Map) { final d = DateTime.tryParse('${v['date']}'); if (d != null && d.year == now.year && d.month == now.month && d.day == now.day) today += (v['total'] as num?)?.toDouble() ?? 0; }
    }
    return RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [metric('مبيعات اليوم', '${today.toStringAsFixed(2)} DH', Icons.payments), metric('المنتجات', '${products.length}', Icons.inventory_2), metric('السلة', '${cart.length}', Icons.shopping_cart), metric('Stock منخفض', '$low', Icons.warning)]),
      const SizedBox(height: 20),
      Card(child: Column(children: [ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('Scanner Barcode'), onTap: scan), ListTile(leading: const Icon(Icons.people), title: const Text('الزبناء'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomersPage(db)))), ListTile(leading: const Icon(Icons.money_off), title: const Text('المصاريف'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(db)))), ListTile(leading: const Icon(Icons.bar_chart), title: const Text('التقارير'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(db))))])),
    ]));
  }
  Widget metric(String label, String value, IconData icon) => SizedBox(width: MediaQuery.of(context).size.width / 2 - 22, child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(label), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]))));
  Widget _sales() {
    final list = products.where((p) => search.isEmpty || p.name.toLowerCase().contains(search.toLowerCase()) || p.barcode.contains(search)).toList();
    return Column(children: [Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اسم أو Barcode'))), IconButton.filled(onPressed: scan, icon: const Icon(Icons.qr_code_scanner))])), Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: list.length, itemBuilder: (_, i) { final p = list[i]; return ListTile(leading: CircleAvatar(child: Text('${p.stock}')), title: Text(p.name), subtitle: Text('${p.sell.toStringAsFixed(2)} DH • ${p.category}'), trailing: FilledButton(onPressed: p.stock > 0 ? () => add(p) : null, child: const Text('إضافة'))); })), if (cart.isNotEmpty) Card(margin: const EdgeInsets.all(8), child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [for (final x in cart) Row(children: [Expanded(child: Text('${x.product.name} × ${x.quantity}')), Text('${x.total.toStringAsFixed(2)} DH'), IconButton(onPressed: () => setState(() { if (x.quantity > 1) x.quantity--; else cart.remove(x); }), icon: const Icon(Icons.remove_circle))]), const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL'), Text('${total.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]), SizedBox(width: double.infinity, child: FilledButton(onPressed: checkout, child: const Text('تأكيد البيع'))]))));
  }
  Widget _stock() => RefreshIndicator(onRefresh: refresh, child: ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: products.length, itemBuilder: (_, i) { final p = products[i]; return Card(child: ListTile(title: Text(p.name), subtitle: Text('${p.category} • شراء ${p.buy.toStringAsFixed(2)} • بيع ${p.sell.toStringAsFixed(2)} DH\nBarcode: ${p.barcode.isEmpty ? '-' : p.barcode}'), leading: CircleAvatar(child: Text('${p.stock}')), trailing: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(db: db, product: p))).then((_) => refresh()), icon: const Icon(Icons.edit)))); });
  Widget _history() => ValueListenableBuilder<Box>(valueListenable: Hive.box('pos_sales').listenable(), builder: (_, box, __) => ListView(padding: const EdgeInsets.all(12), children: [const Text('المبيعات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), for (final v in box.values.toList().reversed) Card(child: ListTile(leading: const Icon(Icons.receipt), title: Text('${v['total']} DH'), subtitle: Text('${v['date']}')))]));
}

class _PayOption extends StatelessWidget {
  const _PayOption(this.value, this.label);
  final String value;
  final String label;
  @override Widget build(BuildContext context) => SimpleDialogOption(onPressed: () => Navigator.pop(context, value), child: Text(label));
}

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Scanner Barcode')), body: MobileScanner(onDetect: (capture) { for (final b in capture.barcodes) { final code = b.rawValue; if (code != null && code.isNotEmpty) { Navigator.pop(context, code); break; } } }));
}

class ProductForm extends StatefulWidget {
  const ProductForm({super.key, required this.db, this.product});
  final SupabaseClient db;
  final Product? product;
  @override State<ProductForm> createState() => _ProductFormState();
}
class _ProductFormState extends State<ProductForm> {
  late final TextEditingController name, barcode, buy, sell, stock, min, category;
  bool saving = false;
  @override void initState() { super.initState(); final p = widget.product; name = TextEditingController(text: p?.name ?? ''); barcode = TextEditingController(text: p?.barcode ?? ''); buy = TextEditingController(text: p == null ? '' : '${p.buy}'); sell = TextEditingController(text: p == null ? '' : '${p.sell}'); stock = TextEditingController(text: p == null ? '0' : '${p.stock}'); min = TextEditingController(text: p == null ? '2' : '${p.min}'); category = TextEditingController(text: p?.category ?? ''); }
  @override void dispose() { name.dispose(); barcode.dispose(); buy.dispose(); sell.dispose(); stock.dispose(); min.dispose(); category.dispose(); super.dispose(); }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      final data = <String, dynamic>{'name': name.text.trim(), 'barcode': barcode.text.trim().isEmpty ? null : barcode.text.trim(), 'buy_price': double.tryParse(buy.text) ?? 0, 'sell_price': double.tryParse(sell.text) ?? 0, 'stock': int.tryParse(stock.text) ?? 0, 'min_stock': int.tryParse(min.text) ?? 2, 'category': category.text.trim()};
      if (widget.product == null) { data['id'] = const Uuid().v4(); data['user_id'] = widget.db.auth.currentUser?.id; }
      if (widget.product == null) await widget.db.from('products').insert(data); else await widget.db.from('products').update(data).eq('id', widget.product!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.product == null ? 'منتج جديد' : 'تعديل المنتج')), body: ListView(padding: const EdgeInsets.all(16), children: [field(name, 'اسم المنتج'), Row(children: [Expanded(child: field(barcode, 'Barcode')), IconButton.filled(onPressed: () async { final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage())); if (code != null) setState(() => barcode.text = code); }, icon: const Icon(Icons.qr_code_scanner))]), Row(children: [Expanded(child: field(buy, 'ثمن الشراء', number: true)), const SizedBox(width: 8), Expanded(child: field(sell, 'ثمن البيع', number: true))]), Row(children: [Expanded(child: field(stock, 'Stock', number: true)), const SizedBox(width: 8), Expanded(child: field(min, 'Minimum', number: true))]), field(category, 'الفئة'), const SizedBox(height: 12), FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'حفظ...' : 'حفظ'))]));
  Widget field(TextEditingController c, String label, {bool number = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label)));
}

class CustomersPage extends StatefulWidget {
  const CustomersPage(this.db, {super.key});
  final SupabaseClient db;
  @override State<CustomersPage> createState() => _CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage> {
  List<Map<String, dynamic>> rows = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { final r = await widget.db.from('customers').select('id,name,phone,address').order('name'); if (mounted) setState(() => rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList()); } catch (_) {} }
  Future<void> addCustomer() async { final n = TextEditingController(); final p = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('زبون جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'الاسم')), TextField(controller: p, decoration: const InputDecoration(labelText: 'الهاتف'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))])); if (ok == true && n.text.trim().isNotEmpty) { try { await widget.db.from('customers').insert({'user_id': widget.db.auth.currentUser!.id, 'name': n.text.trim(), 'phone': p.text.trim()}); await load(); } catch (_) {} } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الزبناء'), actions: [IconButton(onPressed: addCustomer, icon: const Icon(Icons.add))]), body: ListView(children: rows.map((r) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${r['name']}'), subtitle: Text('${r['phone'] ?? ''}'))).toList()));
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage(this.db, {super.key});
  final SupabaseClient db;
  @override State<ExpensesPage> createState() => _ExpensesPageState();
}
class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> rows = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { final r = await widget.db.from('expenses').select('amount,note,expense_date').order('expense_date', ascending: false); if (mounted) setState(() => rows = (r as List).map((e) => Map<String, dynamic>.from(e)).toList()); } catch (_) {} }
  Future<void> addExpense() async { final amount = TextEditingController(); final note = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('مصروف جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')), TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))])); if (ok == true) { try { await widget.db.from('expenses').insert({'user_id': widget.db.auth.currentUser!.id, 'amount': double.tryParse(amount.text) ?? 0, 'note': note.text.trim(), 'expense_date': DateTime.now().toIso8601String().substring(0, 10)}); await load(); } catch (_) {} } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('المصاريف'), actions: [IconButton(onPressed: addExpense, icon: const Icon(Icons.add))]), body: ListView(children: rows.map((r) => ListTile(title: Text('${r['amount']} DH'), subtitle: Text('${r['note'] ?? ''} • ${r['expense_date']}'))).toList()));
}

class ReportsPage extends StatelessWidget {
  const ReportsPage(this.db, {super.key});
  final SupabaseClient db;
  Future<List<Map<String, dynamic>>> load() async { final r = await db.from('sales').select('total,profit,created_at').order('created_at', ascending: false).limit(200); return (r as List).map((e) => Map<String, dynamic>.from(e)).toList(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('التقارير')), body: FutureBuilder<List<Map<String, dynamic>>>(future: load(), builder: (_, s) { final rows = s.data ?? []; final total = rows.fold<double>(0, (a, r) => a + ((r['total'] as num?)?.toDouble() ?? 0)); final profit = rows.fold<double>(0, (a, r) => a + ((r['profit'] as num?)?.toDouble() ?? 0)); return ListView(padding: const EdgeInsets.all(16), children: [Card(child: ListTile(title: const Text('إجمالي المبيعات'), trailing: Text('${total.toStringAsFixed(2)} DH'))), Card(child: ListTile(title: const Text('الربح'), trailing: Text('${profit.toStringAsFixed(2)} DH'))), Text('عدد الفواتير: ${rows.length}')]); }));
}
