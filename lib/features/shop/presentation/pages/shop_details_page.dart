import 'package:flutter/material.dart';

class ShopDetailsPage extends StatelessWidget {
  const ShopDetailsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shop Details')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MAISON AL TEEB', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text('Configure shop information and receipt details.'),
      ]),
    ),
  );
}
