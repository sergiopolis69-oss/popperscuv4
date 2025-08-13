import 'package:flutter/material.dart';

// Usa imports relativos para evitar conflictos con el nombre del paquete.
import 'sales_page.dart';
import 'products_page.dart';
import 'customers_page.dart';
import 'sales_history_page.dart';
import 'top_customers_page.dart';
import 'profit_overview_page.dart';
import 'reports_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_NavItem>[
      _NavItem('POS ventas', Icons.point_of_sale, () => const SalesPage()),
      _NavItem('Inventario', Icons.inventory_2_outlined, () => const ProductsPage()),
      _NavItem('Clientes', Icons.people_alt_outlined, () => const CustomersPage()),
      _NavItem('Historial ventas', Icons.receipt_long_outlined, () => const SalesHistoryPage()),
      _NavItem('Mejores clientes', Icons.emoji_events_outlined, () => const TopCustomersPage()),
      _NavItem('Utilidad', Icons.trending_up_outlined, () => const ProfitOverviewPage()),
      _NavItem('CSV / Reportes', Icons.file_download_outlined, () => const ReportsPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('PoppersCUV')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.2,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) {
          final it = tiles[i];
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(
                _, MaterialPageRoute(builder: (_) => it.builder()),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(it.icon, size: 48),
                    const SizedBox(height: 12),
                    Text(it.title, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final Widget Function() builder;
  _NavItem(this.title, this.icon, this.builder);
}
