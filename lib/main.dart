import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD');
final db = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MaisonAlTeebApp());
}

class MaisonAlTeebApp extends StatelessWidget {
  const MaisonAlTeebApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MAISON AL TEEB POS',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (_, __) => db.auth.currentSession == null ? const LoginPage() : const RoleGate(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return _msg('دخل Email و Password');
    setState(() => loading = true);
    try { await db.auth.signInWithPassword(email: email.text.trim(), password: password.text); }
    catch (e) { _msg('خطأ فالدخول: $e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  void _msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  @override Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430), child: Column(children: [
        Icon(Icons.spa, size: 72), SizedBox(height: 10),
        Text('MAISON AL TEEB', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text('POS • Morocco'), SizedBox(height: 28),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
        SizedBox(height: 12), TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
        SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : submit, child: Text(loading ? '...' : 'دخول'))),
      ]),
    )),
  );
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});
  @override State<RoleGate> createState() => _RoleGateState();
}
class _RoleGateState extends State<RoleGate> {
  String? role; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      role = (await db.rpc('current_user_role'))?.toString();
      if (role == null || role!.isEmpty) {
        final id = db.auth.currentUser?.id;
        if (id != null) role = (await db.from('profiles').select('role').eq('id', id).maybeSingle())?['role']?.toString();
      }
      if (!['admin', 'manager', 'cashier'].contains(role)) throw Exception('User role is not authorized');
    } catch (e) { await db.auth.signOut(); }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) => loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : ShiftGate(role: role!);
}

class ShiftGate extends StatefulWidget {
  final String role;
  const ShiftGate({super.key, required this.role});
  @override State<ShiftGate> createState() => _ShiftGateState();
}
class _ShiftGateState extends State<ShiftGate> {
  Map<String, dynamic>? shift; bool loading = true;
  final opening = TextEditingController(text: '0');
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { opening.dispose(); super.dispose(); }
  Future<void> _load() async {
    try { shift = await db.from('cash_register_shifts').select().eq('user_id', db.auth.currentUser!.id).eq('status', 'open').order('opened_at', ascending: false).limit(1).maybeSingle(); } catch (_) {}
    if (mounted) setState(() => loading = false);
  }
  Future<void> _open() async {
    final amount = double.tryParse(opening.text.replaceAll(',', '.'));
    if (amount == null || amount < 0) return;
    try {
      shift = await db.from('cash_register_shifts').insert({'user_id': db.auth.currentUser!.id, 'opened_by': db.auth.currentUser!.id, 'opening_cash': amount}).select().single();
      if (mounted) setState(() {});
    } catch (e) { _msg('تعذر فتح الصندوق: $e'); }
  }
  void _msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (shift == null) return Scaffold(body: Center(child: Card(margin: const EdgeInsets.all(24), child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.point_of_sale, size: 64), SizedBox(height: 12), Text('فتح صندوق البداية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('دخل المبلغ الموجود في الصندوق قبل بداية الخدمة.'), SizedBox(height: 18),
        TextField(controller: opening, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Opening cash (MAD)')),
        SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: _open, child: Text('فتح الصندوق'))),
      ]),
    ))));
    return HomePage(role: widget.role, shiftId: shift!['id'].toString());
  }
}

class CartLine { CartLine(this.product, this.qty); final Map<String, dynamic> product; int qty; }

class HomePage extends StatefulWidget {
  final String role, shiftId;
  const HomePage({super.key, required this.role, required this.shiftId});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> products = []; final cart = <CartLine>[]; bool loading = true; String search = ''; int tab = 0;
  double get total => cart.fold(0, (s, x) => s + ((x.product['sell_price'] as num).toDouble() * x.qty));
  @override void initState() { super.initState(); loadProducts(); }
  Future<void> loadProducts() async {
    setState(() => loading = true);
    try { final rows = await db.from('products').select('id,name,name_ar,name_fr,barcode,sku,sell_price,buy_price,stock,min_stock,category,image_url').order('name'); products = List<Map<String, dynamic>>.from(rows); }
    catch (e) { _msg('تعذر تحميل المنتجات: $e'); }
    if (mounted) setState(() => loading = false);
  }
  List<Map<String, dynamic>> get filtered => products.where((p) {
    final q = search.trim().toLowerCase(); if (q.isEmpty) return true;
    return '${p['name'] ?? ''} ${p['name_ar'] ?? ''} ${p['name_fr'] ?? ''} ${p['barcode'] ?? ''} ${p['sku'] ?? ''}'.toLowerCase().contains(q);
  }).toList();
  void addProduct(Map<String, dynamic> p) {
    final stock = (p['stock'] as num?)?.toInt() ?? 0; if (stock <= 0) return _msg('المنتج سالا من الستوك');
    final i = cart.indexWhere((x) => x.product['id'] == p['id']);
    setState(() { if (i >= 0) { if (cart[i].qty < stock) cart[i].qty++; } else { cart.add(CartLine(p, 1)); } });
  }
  void _msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage())); if (code == null) return;
    try { final p = await db.from('products').select('id,name,name_ar,name_fr,barcode,sku,sell_price,buy_price,stock,min_stock,category,image_url').eq('barcode', code).maybeSingle(); if (p == null) _msg('Barcode غير موجود'); else addProduct(Map<String, dynamic>.from(p)); }
    catch (e) { _msg('خطأ فالبحث: $e'); }
  }
  Future<void> checkout() async {
    if (cart.isEmpty) return;
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PaymentDialog(total: total)); if (result == null) return;
    try {
      final method = result['method'] as String; final received = (result['received'] as num).toDouble(); final amount = total;
      await db.rpc('pos_checkout', params: {'p_subtotal': amount, 'p_discount': 0, 'p_total': amount, 'p_payment_method': method, 'p_items': cart.map((x) => {'product_id': x.product['id'], 'qty': x.qty}).toList(), 'p_customer_id': null, 'p_shift_id': widget.shiftId, 'p_amount_received': received});
      setState(() => cart.clear()); await loadProducts();
      if (mounted) showDialog(context: context, builder: (_) => AlertDialog(title: const Text('تم البيع بنجاح'), content: Text('المجموع: ${amount.toStringAsFixed(2)} MAD\nالمستلم: ${received.toStringAsFixed(2)} MAD\nالباقي: ${method == 'cash' ? (received - amount).toStringAsFixed(2) : '0.00'} MAD'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))]));
    } catch (e) { _msg('تعذر إتمام البيع: $e'); }
  }
  Future<void> closeShift() async {
    final c = TextEditingController(); final actual = await showDialog<double>(context: context, builder: (_) => AlertDialog(title: const Text('إغلاق الصندوق'), content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cash الموجود فعلياً (MAD)')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('إغلاق'))])); c.dispose(); if (actual == null) return;
    try {
      final s = await db.from('cash_register_shifts').select('opening_cash,opened_at').eq('id', widget.shiftId).single();
      final opened = DateTime.parse(s['opened_at'].toString()).toUtc().toIso8601String();
      final rows = await db.from('sales').select('total,payment_method').eq('shift_id', widget.shiftId).eq('payment_method', 'cash').gte('created_at', opened);
      final cashSales = rows.fold<double>(0, (sum, r) => sum + ((r['total'] as num?)?.toDouble() ?? 0));
      final expected = (s['opening_cash'] as num).toDouble() + cashSales;
      await db.from('cash_register_shifts').update({'status': 'closed', 'closed_at': DateTime.now().toUtc().toIso8601String(), 'closed_by': db.auth.currentUser!.id, 'expected_cash': expected, 'actual_cash': actual, 'difference': actual - expected}).eq('id', widget.shiftId);
      await db.auth.signOut();
    } catch (e) { _msg('تعذر إغلاق الصندوق: $e'); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MAISON AL TEEB POS'), actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: Text(widget.role.toUpperCase()))), IconButton(onPressed: loadProducts, icon: const Icon(Icons.refresh)), IconButton(onPressed: closeShift, icon: const Icon(Icons.lock_clock)), IconButton(onPressed: () => db.auth.signOut(), icon: const Icon(Icons.logout))]),
    body: tab == 0 ? _sales() : _dashboard(),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'البيع'), NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard')]),
    floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')) : null,
  );
  Widget _sales() => Column(children: [Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم / SKU / barcode'))), Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisExtent: 150, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: filtered.length, itemBuilder: (_, i) { final p = filtered[i]; final stock = (p['stock'] as num?)?.toInt() ?? 0; final price = (p['sell_price'] as num?)?.toDouble() ?? 0; return Card(child: InkWell(onTap: () => addProduct(p), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((p['name_ar'] ?? p['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), Text('${price.toStringAsFixed(2)} MAD', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text('Stock: $stock'),])))); })), if (cart.isNotEmpty) _cartPanel()]);
  Widget _cartPanel() => Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [...cart.map((x) { final price = (x.product['sell_price'] as num).toDouble(); return Row(children: [Expanded(child: Text((x.product['name_ar'] ?? x.product['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() { if (x.qty > 1) x.qty--; else cart.remove(x); }), icon: const Icon(Icons.remove_circle_outline)), Text('${x.qty}'), IconButton(onPressed: () => addProduct(x.product), icon: const Icon(Icons.add_circle_outline)), const SizedBox(width: 8), Text('${(price * x.qty).toStringAsFixed(2)} MAD')]); }), const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)), Text('${total.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: checkout, icon: const Icon(Icons.payment), label: const Text('الدفع وتأكيد البيع'))])));
  Widget _dashboard() => FutureBuilder<List<Map<String, dynamic>>>(future: db.from('sales').select('id,total,profit,payment_method,created_at,receipt_number').order('created_at', ascending: false).limit(50), builder: (_, snap) { if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator()); if (snap.hasError) return Center(child: Text('Dashboard error: ${snap.error}')); final rows = snap.data ?? []; final revenue = rows.fold<double>(0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0)); final profit = rows.fold<double>(0, (s, r) => s + ((r['profit'] as num?)?.toDouble() ?? 0)); final low = products.where((p) => ((p['stock'] as num?)?.toInt() ?? 0) <= ((p['min_stock'] as num?)?.toInt() ?? 0)).length; return ListView(padding: const EdgeInsets.all(16), children: [_Kpi('المبيعات الأخيرة', '${revenue.toStringAsFixed(2)} MAD', Icons.payments), _Kpi('الربح', '${profit.toStringAsFixed(2)} MAD', Icons.trending_up), _Kpi('Low stock', '$low', Icons.warning), const SizedBox(height: 12), const Text('آخر العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ...rows.map((r) => ListTile(leading: const Icon(Icons.receipt_long), title: Text('${((r['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} MAD'), subtitle: Text('Receipt #${r['receipt_number'] ?? '-'} • ${r['payment_method'] ?? ''} • ${r['created_at'] ?? ''}'))]); });
}

class _Kpi extends StatelessWidget { final String title, value; final IconData icon; const _Kpi(this.title, this.value, this.icon); @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, size: 32), title: Text(title), trailing: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))); }

class PaymentDialog extends StatefulWidget { final double total; const PaymentDialog({super.key, required this.total}); @override State<PaymentDialog> createState() => _PaymentDialogState(); }
class _PaymentDialogState extends State<PaymentDialog> { String method = 'cash'; late final TextEditingController received; @override void initState() { super.initState(); received = TextEditingController(text: widget.total.toStringAsFixed(2)); } @override void dispose() { received.dispose(); super.dispose(); } @override Widget build(BuildContext context) { final amount = double.tryParse(received.text.replaceAll(',', '.')) ?? 0; final change = amount - widget.total; return AlertDialog(title: const Text('الدفع'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Total: ${widget.total.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12), DropdownButtonFormField<String>(value: method, items: const [DropdownMenuItem(value: 'cash', child: Text('نقداً')), DropdownMenuItem(value: 'card', child: Text('بطاقة')), DropdownMenuItem(value: 'transfer', child: Text('تحويل'))], onChanged: (v) => setState(() => method = v ?? 'cash'), decoration: const InputDecoration(labelText: 'طريقة الأداء')), const SizedBox(height: 12), if (method == 'cash') TextField(controller: received, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ المستلم (MAD)')), if (method == 'cash') Padding(padding: const EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerRight, child: Text('الباقي: ${change.toStringAsFixed(2)} MAD', style: const TextStyle(fontWeight: FontWeight.bold))))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: method == 'cash' && amount < widget.total ? null : () => Navigator.pop(context, {'method': method, 'received': method == 'cash' ? amount : widget.total}), child: const Text('تأكيد'))]); } }

class ScannerPage extends StatefulWidget { const ScannerPage({super.key}); @override State<ScannerPage> createState() => _ScannerPageState(); }
class _ScannerPageState extends State<ScannerPage> { final controller = MobileScannerController(); bool done = false; @override void dispose() { controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Scan barcode')), body: MobileScanner(controller: controller, onDetect: (capture) { if (done) return; final code = capture.barcodes.firstOrNull?.rawValue; if (code != null && code.isNotEmpty) { done = true; Navigator.pop(context, code); } })); }
