import 'package:flutter/material.dart';

import 'sales_page.dart';
import 'products_page.dart';
import 'customers_page.dart';
import 'sales_history_page.dart';
import 'reports_page.dart' as rp;         // módulo CSV
import 'profit_overview_page.dart' as po; // módulo de utilidad (porcentajes)
import 'top_customers_page.dart' as tc;   // evita choque con otros nombres

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_HomeEntry>[
      _HomeEntry(
        'POS / Ventas',
        Icons.point_of_sale_rounded,
        (ctx) => const SalesPage(),
      ),
      _HomeEntry(
        'Inventario',
        Icons.inventory_2_rounded,
        (ctx) => const ProductsPage(),
      ),
      _HomeEntry(
        'Clientes',
        Icons.people_alt_rounded,
        (ctx) => const CustomersPage(),
      ),
      _HomeEntry(
        'Historial de ventas',
        Icons.receipt_long_rounded,
        (ctx) => const SalesHistoryPage(),
      ),
      _HomeEntry(
        'Top clientes',
        Icons.emoji_events_rounded,
        (ctx) => const tc.TopCustomersPage(),
      ),
      _HomeEntry(
        'Utilidad',
        Icons.trending_up_rounded,
        (ctx) => const po.ProfitOverviewPage(),
      ),
      _HomeEntry(
        'Reportes CSV',
        Icons.table_view_rounded,
        (ctx) => const rp.ReportsPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Popperscu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Logo (asegúrate que exista assets/logo.png en pubspec.yaml)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bienvenido 👋',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.25,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final it = entries[i];
                  return _HomeCard(entry: it);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.entry});

  final _HomeEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: entry.builder), // 👈 sin (_) suelto
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.icon, size: 36),
              const SizedBox(height: 12),
              Text(
                entry.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEntry {
  const _HomeEntry(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final WidgetBuilder builder; // (BuildContext) => Widget
}
