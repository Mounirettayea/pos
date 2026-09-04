import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      ListTile(title: Text('MAISON AL TEEB'), subtitle: Text('POS Settings')),
      ListTile(title: Text('Printer'), subtitle: Text('Bluetooth thermal printer')),
    ]),
  );
}
