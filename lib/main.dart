import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MAISON AL TEEB POS',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snap) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return const LoginPage();
      return const AdminGuard();
    },
  );
}

class AdminGuard extends StatefulWidget {
  const AdminGuard({super.key});
  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool loading = true;
  bool allowed = false;
  @override
  void initState() { super.initState(); check(); }
  Future<void> check() async {
    try {
      final id = Supabase.instance.client.auth.currentUser?.id;
      if (id != null) {
        final row = await Supabase.instance.client.from('profiles').select('role').eq('id', id).maybeSingle();
        allowed = row?['role'] == 'admin';
      }
      if (!allowed) await Supabase.instance.client.auth.signOut();
    } catch (_) {
      await Supabase.instance.client.auth.signOut();
    }
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!allowed) return const LoginPage();
    return const HomePage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(text: 'ferkasni@gmail.com');
  final password = TextEditingController();
  bool loading = false;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    final e = email.text.trim();
    if (e.isEmpty || password.text.isEmpty) { message('دخل Email و Password'); return; }
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: e, password: password.text);
    } catch (err) {
      message('خطأ في الدخول: $err');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(children: [
      const Icon(Icons.point_of_sale, size: 76), const SizedBox(height: 12),
      const Text('MAISON AL TEEB POS', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Admin Login'), const SizedBox(height: 28),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Admin', prefixIcon: Icon(Icons.email))),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
      const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? '...' : 'دخول'))),
    ])))),
  );
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
  void initState() { super.initState(); loadProducts(); }

  Future<void> loadProducts() async {
    setState(() => loading = true);
    try {
      final rows = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').order('name');
      products = (rows as List).map((r) => Product.fromMap(Map<String,dynamic>.from(r))).toList();
    } catch (e) { _snack('تعذر تحميل المنتجات: $e'); }
    if (mounted) setState(() => loading = false);
  }

  void _snack(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  List<Product> get filtered => products.where((p) => p.name.toLowerCase().contains(search.toLowerCase()) || (p.barcode ?? '').contains(search)).toList();
  double get total => cart.fold(0, (s, x) => s + x.product.sellPrice * x.qty);

  void add(Product p) {
    final i = cart.indexWhere((x) => x.product.id == p.id);
    setState(() { if (i >= 0) cart[i].qty++; else cart.add(CartItem(p)); });
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code == null || code.isEmpty) return;
    try {
      final row = await db.from('products').select('id,name,barcode,sell_price,buy_price,stock,min_stock,category').eq('barcode', code).maybeSingle();
      if (row == null) { _snack('المنتج غير موجود: $code'); return; }
      add(Product.fromMap(Map<String,dynamic>.from(row)));
    } catch (e) { _snack('خطأ فالسكان: $e'); }
  }

  Future<void> checkout() async {
    if (cart.isEmpty) { _snack('السلة خاوية'); return; }
    final method = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('نقداً'), leading: const Icon(Icons.payments), onTap: () => Navigator.pop(c, 'cash')),
      ListTile(title: const Text('بطاقة'), leading: const Icon(Icons.credit_card), onTap: () => Navigator.pop(c, 'card')),
      ListTile(title: const Text('تحويل'), leading: const Icon(Icons.account_balance), onTap: () => Navigator.pop(c, 'transfer')),
    ])));
    if (method == null) return;
    try {
      final items = cart.map((x) => {'product_id': x.product.id, 'qty': x.qty, 'unit_price': x.product.sellPrice}).toList();
      await db.rpc('pos_checkout', params: {'p_subtotal': total, 'p_discount': 0, 'p_total': total, 'p_payment_method': method, 'p_items': items});
      setState(() => cart.clear());
      await loadProducts();
      _snack('تم تسجيل البيع بنجاح');
    } catch (e) { _snack('تعذر إتمام البيع: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final body = tab == 0 ? _saleView() : _dashboardView();
    return Scaffold(
      appBar: AppBar(title: const Text('MAISON AL TEEB POS'), actions: [IconButton(onPressed: loadProducts, icon: const Icon(Icons.refresh)), IconButton(onPressed: () async => await db.auth.signOut(), icon: const Icon(Icons.logout))]),
      body: body,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'البيع'), NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard')]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')) : null,
    );
  }

  Widget _saleView() => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'قلب على منتج أو barcode', border: OutlineInputBorder()))),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty ? const Center(child: Text('ما كاين حتى منتج')) : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) { final p = filtered[i]; return ListTile(title: Text(p.name), subtitle: Text('${p.sellPrice.toStringAsFixed(2)} MAD • Stock ${p.stock}'), trailing: IconButton(onPressed: () => add(p), icon: const Icon(Icons.add_circle)); })),
    if (cart.isNotEmpty) Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${cart.length} منتجات'), Text('${total.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: checkout, icon: const Icon(Icons.check), label: const Text('تأكيد البيع')))]))),
  ]);

  Widget _dashboardView() => FutureBuilder<List<Map<String,dynamic>>>(future: db.from('sales').select('id,total,payment_method,created_at').order('created_at', ascending: false).limit(20), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snap.data!;
    final sum = rows.fold<double>(0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
    return RefreshIndicator(onRefresh: () async => setState(() {}), child: ListView(padding: const EdgeInsets.all(16), children: [Card(child: ListTile(title: const Text('آخر المبيعات'), subtitle: Text('${rows.length} عمليات'), trailing: Text('${sum.toStringAsFixed(2)} MAD', style: const TextStyle(fontWeight: FontWeight.bold)))), const SizedBox(height: 12), ...rows.map((r) => ListTile(leading: const Icon(Icons.receipt_long), title: Text('${((r['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} MAD'), subtitle: Text('${r['payment_method'] ?? ''} • ${r['created_at'] ?? ''}')))]));
  });
}

class Product {
  final dynamic id; final String name; final String? barcode; final double sellPrice; final double buyPrice; final int stock; final int minStock; final String? category;
  Product({required this.id, required this.name, this.barcode, required this.sellPrice, required this.buyPrice, required this.stock, required this.minStock, this.category});
  factory Product.fromMap(Map<String,dynamic> m) => Product(id: m['id'], name: '${m['name'] ?? ''}', barcode: m['barcode']?.toString(), sellPrice: (m['sell_price'] as num?)?.toDouble() ?? 0, buyPrice: (m['buy_price'] as num?)?.toDouble() ?? 0, stock: (m['stock'] as num?)?.toInt() ?? 0, minStock: (m['min_stock'] as num?)?.toInt() ?? 0, category: m['category']?.toString());
}

class CartItem { final Product product; int qty = 1; CartItem(this.product); }

class ScannerPage extends StatefulWidget { const ScannerPage({super.key}); @override State<ScannerPage> createState() => _ScannerPageState(); }
class _ScannerPageState extends State<ScannerPage> {
  bool done = false;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Scan Barcode')), body: MobileScanner(onDetect: (capture) { if (done) return; final code = capture.barcodes.firstOrNull?.rawValue; if (code != null && code.isNotEmpty) { done = true; Navigator.pop(context, code); } }));
}
