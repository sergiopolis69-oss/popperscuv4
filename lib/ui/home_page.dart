import 'package:flutter/material.dart';
import 'package:popperscuv/ui/products_page.dart';
import 'package:popperscuv/ui/customers_page.dart';
import 'package:popperscuv/ui/sales_page.dart';
import 'package:popperscuv/ui/sales_history_page.dart';
import 'package:popperscuv/ui/top_customers_page.dart';
import 'package:popperscuv/ui/reports_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HomeItem>[
      _HomeItem('Inventario', Icons.inventory_2, () => const ProductsPage()),
      _HomeItem('Clientes', Icons.people_alt, () => const CustomersPage()),
      _HomeItem('POS / Ventas', Icons.point_of_sale, () => const SalesPage()),
      _HomeItem('Historial', Icons.receipt_long, () => const SalesHistoryPage()),
      _HomeItem('Top clientes', Icons.leaderboard, () => const TopCustomersPage()),
      _HomeItem('CSV / Reportes', Icons.table_view, () => const ReportsPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poppers POS'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Logo (asegúrate de tener assets/logo.png en pubspec)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront, size: 72),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                for (final it in items)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => it.builder()),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(it.icon, size: 36),
                            const SizedBox(height: 8),
                            Text(it.label),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  _HomeItem(this.label, this.icon, this.builder);
}
