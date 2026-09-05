import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MaisonAlTeebApp());
}

final db = Supabase.instance.client;

class MaisonAlTeebApp extends StatelessWidget {
  const MaisonAlTeebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAISON AL TEEB POS',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (db.auth.currentSession == null) return const LoginPage();
        return const RoleGate();
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
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      _message('دخل Email و Password');
      return;
    }
    setState(() => loading = true);
    try {
      await db.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (e) {
      _message('خطأ فالدخول: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
                const Icon(Icons.spa, size: 72),
                const SizedBox(height: 12),
                const Text('MAISON AL TEEB POS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const Text('POS • Morocco'),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: Text(loading ? '...' : 'دخول'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  String? role;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  Future<void> loadRole() async {
    try {
      role = (await db.rpc('current_user_role'))?.toString();
      if (role == null || role!.isEmpty) {
        final id = db.auth.currentUser?.id;
        if (id != null) {
          final row = await db.from('profiles').select('role').eq('id', id).maybeSingle();
          role = row?['role']?.toString();
        }
      }
      if (!['admin', 'manager', 'cashier'].contains(role)) {
        throw Exception('User role is not authorized');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role error: $e')));
      }
      await db.auth.signOut();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return ShiftGate(role: role ?? 'cashier');
  }
}

class ShiftGate extends StatefulWidget {
  final String role;

  const ShiftGate({super.key, required this.role});

  @override
  State<ShiftGate> createState() => _ShiftGateState();
}

class _ShiftGateState extends State<ShiftGate> {
  Map<String, dynamic>? shift;
  bool loading = true;
  final opening = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    loadShift();
  }

  @override
  void dispose() {
    opening.dispose();
    super.dispose();
  }

  Future<void> loadShift() async {
    try {
      shift = await db
          .from('cash_register_shifts')
          .select()
          .eq('user_id', db.auth.currentUser!.id)
          .eq('status', 'open')
          .maybeSingle();
    } catch (e) {
      message('تعذر تحميل الصندوق: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> openShift() async {
    final amount = double.tryParse(opening.text.replaceAll(',', '.'));
    if (amount == null || amount < 0) {
      message('دخل مبلغ صحيح');
      return;
    }
    try {
      shift = await db
          .from('cash_register_shifts')
          .insert({
            'user_id': db.auth.currentUser!.id,
            'opened_by': db.auth.currentUser!.id,
            'opening_cash': amount,
          })
          .select()
          .single();
      if (mounted) setState(() {});
    } catch (e) {
      message('تعذر فتح الصندوق: $e');
    }
  }

  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (shift != null) return HomePage(role: widget.role, shiftId: shift!['id'].toString());

    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.point_of_sale, size: 64),
                  const SizedBox(height: 12),
                  const Text('فتح صندوق البداية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('دخل المبلغ الموجود في الصندوق قبل بداية الخدمة.'),
                  const SizedBox(height: 18),
                  TextField(
                    controller: opening,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Opening cash (MAD)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: openShift, child: const Text('فتح الصندوق'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CartLine {
  CartLine(this.product, this.qty);
  final Map<String, dynamic> product;
  int qty;
}

class HomePage extends StatefulWidget {
  final String role;
  final String shiftId;

  const HomePage({super.key, required this.role, required this.shiftId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cart = <CartLine>[];
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String search = '';
  int tab = 0;

  double get total {
    return cart.fold<double>(0, (sum, line) {
      final price = (line.product['sell_price'] as num?)?.toDouble() ?? 0;
      return sum + price * line.qty;
    });
  }

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    if (mounted) setState(() => loading = true);
    try {
      final rows = await db
          .from('products')
          .select('id,name,name_ar,name_fr,barcode,sku,sell_price,buy_price,stock,min_stock,category,image_url')
          .order('name');
      products = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      message('تعذر تحميل المنتجات: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  List<Map<String, dynamic>> get filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) {
      final text = '${p['name'] ?? ''} ${p['name_ar'] ?? ''} ${p['name_fr'] ?? ''} ${p['barcode'] ?? ''} ${p['sku'] ?? ''}'.toLowerCase();
      return text.contains(q);
    }).toList();
  }

  void addProduct(Map<String, dynamic> product) {
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    if (stock <= 0) {
      message('المنتج سالا من الستوك');
      return;
    }
    final index = cart.indexWhere((x) => x.product['id'] == product['id']);
    setState(() {
      if (index >= 0) {
        if (cart[index].qty < stock) cart[index].qty++;
      } else {
        cart.add(CartLine(product, 1));
      }
    });
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    try {
      final product = await db
          .from('products')
          .select('id,name,name_ar,name_fr,barcode,sku,sell_price,buy_price,stock,min_stock,category,image_url')
          .eq('barcode', code)
          .maybeSingle();
      if (product == null) {
        message('Barcode غير موجود');
      } else {
        addProduct(Map<String, dynamic>.from(product));
      }
    } catch (e) {
      message('خطأ فالبحث: $e');
    }
  }

  Future<void> checkout() async {
    if (cart.isEmpty) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PaymentDialog(total: total),
    );
    if (result == null) return;

    try {
      final method = result['method'] as String;
      final received = (result['received'] as num).toDouble();
      final amount = total;
      await db.rpc(
        'pos_checkout',
        params: {
          'p_subtotal': amount,
          'p_discount': 0,
          'p_total': amount,
          'p_payment_method': method,
          'p_items': cart.map((x) => {'product_id': x.product['id'], 'qty': x.qty}).toList(),
          'p_customer_id': null,
          'p_shift_id': widget.shiftId,
          'p_amount_received': received,
        },
      );
      setState(() => cart.clear());
      await loadProducts();
      message('تم البيع بنجاح • ${amount.toStringAsFixed(2)} MAD');
    } catch (e) {
      message('تعذر إتمام البيع: $e');
    }
  }

  Future<void> closeShift() async {
    final controller = TextEditingController();
    final actual = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إغلاق الصندوق'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cash الموجود فعلياً (MAD)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (actual == null) return;

    try {
      final shiftRow = await db.from('cash_register_shifts').select('opening_cash').eq('id', widget.shiftId).single();
      final sales = await db.from('sales').select('total').eq('shift_id', widget.shiftId).eq('payment_method', 'cash');
      final cashSales = sales.fold<double>(0, (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0));
      final expected = (shiftRow['opening_cash'] as num).toDouble() + cashSales;
      await db.from('cash_register_shifts').update({
        'status': 'closed',
        'closed_at': DateTime.now().toUtc().toIso8601String(),
        'closed_by': db.auth.currentUser!.id,
        'expected_cash': expected,
        'actual_cash': actual,
        'difference': actual - expected,
      }).eq('id', widget.shiftId);
      await db.auth.signOut();
    } catch (e) {
      message('تعذر إغلاق الصندوق: $e');
    }
  }

  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAISON AL TEEB POS'),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(widget.role.toUpperCase()))),
          IconButton(onPressed: loadProducts, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: closeShift, icon: const Icon(Icons.lock_clock)),
          IconButton(onPressed: () => db.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: tab == 0 ? buildSales() : buildDashboard(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'البيع'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        ],
      ),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')) : null,
    );
  }

  Widget buildSales() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم / SKU / barcode', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisExtent: 150, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final stock = (product['stock'] as num?)?.toInt() ?? 0;
                    final price = (product['sell_price'] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: InkWell(
                        onTap: () => addProduct(product),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((product['name_ar'] ?? product['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const Spacer(),
                              Text('${price.toStringAsFixed(2)} MAD', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                              Text('Stock: $stock'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (cart.isNotEmpty) buildCart(),
      ],
    );
  }

  Widget buildCart() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final line in cart)
              Row(
                children: [
                  Expanded(child: Text((line.product['name_ar'] ?? line.product['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() { if (line.qty > 1) line.qty--; else cart.remove(line); }), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${line.qty}'),
                  IconButton(onPressed: () => addProduct(line.product), icon: const Icon(Icons.add_circle_outline)),
                  Text('${(((line.product['sell_price'] as num?)?.toDouble() ?? 0) * line.qty).toStringAsFixed(2)} MAD'),
                ],
              ),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)), Text('${total.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: checkout, icon: const Icon(Icons.payment), label: const Text('الدفع وتأكيد البيع'))),
          ],
        ),
      ),
    );
  }

  Widget buildDashboard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.from('sales').select('id,total,profit,payment_method,created_at,receipt_number').eq('shift_id', widget.shiftId).order('created_at', ascending: false).limit(50),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Dashboard error: ${snapshot.error}'));
        final rows = snapshot.data ?? [];
        final revenue = rows.fold<double>(0, (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0));
        final profit = rows.fold<double>(0, (sum, row) => sum + ((row['profit'] as num?)?.toDouble() ?? 0));
        final lowStock = products.where((p) => ((p['stock'] as num?)?.toInt() ?? 0) <= ((p['min_stock'] as num?)?.toInt() ?? 0)).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Kpi(title: 'المبيعات', value: '${revenue.toStringAsFixed(2)} MAD', icon: Icons.payments),
            _Kpi(title: 'الربح', value: '${profit.toStringAsFixed(2)} MAD', icon: Icons.trending_up),
            _Kpi(title: 'Low stock', value: '$lowStock', icon: Icons.warning),
            const SizedBox(height: 12),
            const Text('آخر العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (final row in rows)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('${((row['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} MAD'),
                subtitle: Text('Receipt #${row['receipt_number'] ?? '-'} • ${row['payment_method'] ?? ''}'),
              ),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _Kpi({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 34),
        title: Text(title),
        subtitle: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class PaymentDialog extends StatefulWidget {
  final double total;

  const PaymentDialog({super.key, required this.total});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String method = 'cash';
  late final TextEditingController received;

  @override
  void initState() {
    super.initState();
    received = TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    received.dispose();
    super.dispose();
  }

  void confirm() {
    final amount = double.tryParse(received.text.replaceAll(',', '.')) ?? 0;
    if (method == 'cash' && amount < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ المستلم ناقص')));
      return;
    }
    Navigator.pop(context, {'method': method, 'received': method == 'cash' ? amount : widget.total});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد الأداء'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total: ${widget.total.toStringAsFixed(2)} MAD'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'طريقة الأداء', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
            ],
            onChanged: (value) => setState(() => method = value ?? 'cash'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: received,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount received (MAD)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: confirm, child: const Text('تأكيد البيع')),
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (done || capture.barcodes.isEmpty) return;
          final code = capture.barcodes.first.rawValue;
          if (code == null || code.isEmpty) return;
          done = true;
          Navigator.pop(context, code);
        },
      ),
    );
  }
}
