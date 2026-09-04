import 'package:flutter/material.dart';

class MaisonDashboardPage extends StatelessWidget {
  const MaisonDashboardPage({
    super.key,
    this.todaySales = 0,
    this.todayProfit = 0,
    this.todayOrders = 0,
    this.lowStockProducts = 0,
  });

  final double todaySales;
  final double todayProfit;
  final int todayOrders;
  final int lowStockProducts;

  String _dh(double value) => '${value.toStringAsFixed(2)} DH';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAISON AL TEEB'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tableau de bord',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vue d’ensemble de votre boutique',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  title: 'Ventes aujourd’hui',
                  value: _dh(todaySales),
                  icon: Icons.point_of_sale_outlined,
                ),
                _KpiCard(
                  title: 'Bénéfice',
                  value: _dh(todayProfit),
                  icon: Icons.trending_up,
                ),
                _KpiCard(
                  title: 'Commandes',
                  value: '$todayOrders',
                  icon: Icons.receipt_long_outlined,
                ),
                _KpiCard(
                  title: 'Stock faible',
                  value: '$lowStockProducts',
                  icon: Icons.inventory_2_outlined,
                  alert: lowStockProducts > 0,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accès rapide',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _QuickAction(
                      icon: Icons.point_of_sale,
                      title: 'Nouvelle vente',
                      onTap: () {},
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      title: 'Produits & stock',
                      onTap: () {},
                    ),
                    _QuickAction(
                      icon: Icons.barcode_reader,
                      title: 'Scanner un produit',
                      onTap: () {},
                    ),
                    _QuickAction(
                      icon: Icons.analytics_outlined,
                      title: 'Rapports',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.alert = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: alert
                      ? Colors.red.withValues(alpha: .10)
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: alert
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
