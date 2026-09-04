import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://nwoseppmuztlmcvfhvge.supabase.co');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_q1fst_HduxFTvM-5RbqSxQ_koebJzpD');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('pos_sales');
  SupabaseClient? client;
  try {
    await Supabase.initialize(url: _url, publishableKey: _key);
    client = Supabase.instance.client;
  } catch (_) {}
  runApp(MaisonAlTeebApp(client: client));
}

class Product {
  Product({required this.id, required this.name, required this.price, required this.stock, this.category = '', this.image = ''});
  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String image;
  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: '${m['id'] ?? ''}', name: '${m['name'] ?? 'Produit'}',
    price: (m['sell_price'] as num?)?.toDouble() ?? 0,
    stock: (m['stock'] as num?)?.toInt() ?? 0,
    category: '${m['category'] ?? ''}', image: '${m['image_url'] ?? ''}',
  );
}

class CartLine { CartLine(this.product, this.quantity); final Product product; int quantity; double get total => product.price * quantity; }

class MaisonAlTeebApp extends StatelessWidget {
  const MaisonAlTeebApp({super.key, this.client});
  final SupabaseClient? client;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'MAISON AL TEEB POS',
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B0B0B),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4AF37), brightness: Brightness.dark),
      cardTheme: const CardThemeData(color: Color(0xFF151515), elevation: 0)),
    home: POSHome(client: client),
  );
}

class POSHome extends StatefulWidget { const POSHome({super.key, this.client}); final SupabaseClient? client; @override State<POSHome> createState()=>_POSHomeState(); }
class _POSHomeState extends State<POSHome> {
  int tab=0; List<Product> products=[]; List<CartLine> cart=[]; bool loading=true; String error='';
  Box get salesBox => Hive.box('pos_sales');
  @override void initState(){super.initState(); loadProducts();}
  Future<void> loadProducts() async {
    setState(()=>loading=true); error='';
    try {
      if(widget.client!=null){
        final rows=await widget.client!.from('products').select('id,name,sell_price,stock,category,image_url').order('name');
        products=(rows as List).map((e)=>Product.fromMap(Map<String,dynamic>.from(e))).toList();
      }
    } catch(e){ error='تعذر تحميل المنتجات من Supabase'; }
    if(products.isEmpty){
      products=[Product(id:'demo1',name:'عطر Maison Al Teeb',price:159,stock:20,category:'عطور'),Product(id:'demo2',name:'زيت أركان طبيعي',price:89,stock:15,category:'زيوت'),Product(id:'demo3',name:'Shampoo Argan',price:69,stock:12,category:'عناية')];
    }
    if(mounted)setState(()=>loading=false);
  }
  void add(Product p){ if(p.stock<=0)return; final i=cart.indexWhere((x)=>x.product.id==p.id); setState(()=>i<0?cart.add(CartLine(p,1)):cart[i].quantity++); }
  double get total=>cart.fold(0,(s,x)=>s+x.total);
  Future<void> checkout() async {
    if(cart.isEmpty)return;
    final sale={'date':DateTime.now().toIso8601String(),'total':total,'items':cart.map((x)=>{'name':x.product.name,'qty':x.quantity,'price':x.product.price}).toList()};
    await salesBox.add(sale);
    // Persist to Supabase when an authenticated user exists. Offline/local checkout remains usable.
    if(widget.client?.auth.currentUser!=null){
      try{
        final u=widget.client!.auth.currentUser!.id;
        final saleRow=await widget.client!.from('sales').insert({'user_id':u,'subtotal':total,'discount':0,'total':total,'profit':0,'payment_method':'cash'}).select('id').single();
        for(final x in cart){await widget.client!.from('sale_items').insert({'sale_id':saleRow['id'],'product_id':x.product.id,'quantity':x.quantity,'unit_buy_price':0,'unit_sell_price':x.product.price,'line_total':x.total,'line_profit':x.total});}
      }catch(_){ }
    }
    if(mounted){setState(()=>cart.clear()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل البيع بنجاح')));}
  }
  @override Widget build(BuildContext context){
    final pages=[dashboard(),salePage(),productsPage(),historyPage()];
    return Scaffold(appBar:AppBar(title:const Text('MAISON AL TEEB',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:loadProducts,icon:const Icon(Icons.sync))]),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.point_of_sale_outlined),selectedIcon:Icon(Icons.point_of_sale),label:'بيع'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'المنتجات'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'المبيعات')]));
  }
  Widget dashboard(){final today=salesBox.values.where((x)=>DateTime.tryParse('${x['date']}')?.day==DateTime.now().day).toList(); final sum=today.fold<double>(0,(s,x)=>(s+(x['total'] as num).toDouble())); return RefreshIndicator(onRefresh:loadProducts,child:ListView(padding:const EdgeInsets.all(16),children:[const Text('Tableau de bord',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:6),if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.orange)),const SizedBox(height:18),Wrap(spacing:12,runSpacing:12,children:[kpi('مبيعات اليوم','${sum.toStringAsFixed(2)} DH',Icons.payments),kpi('عدد المنتجات','${products.length}',Icons.inventory_2),kpi('السلة الحالية','${cart.length}',Icons.shopping_cart),kpi('المبيعات','${salesBox.length}',Icons.receipt_long)]),const SizedBox(height:25),Card(child:Column(children:[ListTile(leading:const Icon(Icons.point_of_sale),title:const Text('بيع جديد'),subtitle:const Text('اختار المنتجات وسجل البيع'),trailing:const Icon(Icons.chevron_right),onTap:()=>setState(()=>tab=1)),ListTile(leading:const Icon(Icons.inventory_2),title:const Text('المنتجات والمخزون'),trailing:const Icon(Icons.chevron_right),onTap:()=>setState(()=>tab=2)),ListTile(leading:const Icon(Icons.receipt_long),title:const Text('تاريخ المبيعات'),trailing:const Icon(Icons.chevron_right),onTap:()=>setState(()=>tab=3))]))]));}
  Widget kpi(String t,String v,IconData i)=>SizedBox(width:MediaQuery.of(context).size.width/2-22,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i,color:Theme.of(context).colorScheme.primary),const SizedBox(height:10),Text(t),Text(v,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))]))));
  Widget salePage(){return Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'بحث عن منتج...',filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),onChanged:(q)=>setState((){}))),Expanded(child:loading?const Center(child:CircularProgressIndicator()):ListView.builder(itemCount:products.length,itemBuilder:(c,i){final p=products[i];return ListTile(leading:CircleAvatar(child:Text('${p.price.toInt()}')),title:Text(p.name),subtitle:Text('${p.category} • Stock: ${p.stock}'),trailing:FilledButton(onPressed:p.stock>0?()=>add(p):null,child:const Text('إضافة')),);})) ,if(cart.isNotEmpty)Card(margin:const EdgeInsets.all(10),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[...cart.map((x)=>Row(children:[Expanded(child:Text('${x.product.name} × ${x.quantity}')),Text('${x.total.toStringAsFixed(2)} DH'),IconButton(onPressed:()=>setState(()=>x.quantity>1?x.quantity--:cart.remove(x)),icon:const Icon(Icons.remove_circle_outline))])),const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('TOTAL',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('${total.toStringAsFixed(2)} DH',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))]),const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:checkout,icon:const Icon(Icons.check),label:const Text('تأكيد البيع'))])))]);}
  Widget productsPage(){return RefreshIndicator(onRefresh:loadProducts,child:ListView(padding:const EdgeInsets.all(12),children:[const Text('المنتجات والمخزون',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:12),...products.map((p)=>Card(child:ListTile(title:Text(p.name),subtitle:Text('${p.category} • ${p.price.toStringAsFixed(2)} DH'),trailing:Chip(label:Text('${p.stock}'))))) ]));}
  Widget historyPage(){final rows=salesBox.values.toList().reversed.toList();return ListView(padding:const EdgeInsets.all(12),children:[const Text('المبيعات',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:12),if(rows.isEmpty)const Center(child:Padding(padding:EdgeInsets.all(40),child:Text('لا توجد مبيعات بعد'))),...rows.map((r)=>Card(child:ListTile(leading:const Icon(Icons.receipt),title:Text('${(r['total'] as num).toStringAsFixed(2)} DH'),subtitle:Text('${r['date']}'),trailing:Text('${(r['items'] as List).length} منتجات'))))]);}
}
