// lib/ui/home_page.dart
import 'package:flutter/material.dart';

// Páginas de tu app (ajusta los nombres si tu proyecto usa otros)
import 'products_page.dart';
import 'customers_page.dart' as cust;
import 'sales_page.dart';
import 'sales_history_page.dart';
import 'top_customers_page.dart' as tc;
import 'profit_overview_page.dart' as po;
import 'reports_page.dart' as rep;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HomeItem>[
      _HomeItem(
        title: 'POS / Ventas',
        icon: Icons.point_of_sale,
        builder: (_) => const SalesPage(),
      ),
      _HomeItem(
        title: 'Inventario',
        icon: Icons.inventory_2,
        builder: (_) => const ProductsPage(),
      ),
      _HomeItem(
        title: 'Clientes',
        icon: Icons.people_alt,
        builder: (_) => const cust.CustomersPage(),
      ),
      _HomeItem(
        title: 'Historial',
        icon: Icons.receipt_long,
        builder: (_) => const SalesHistoryPage(),
      ),
      _HomeItem(
        title: 'Top clientes',
        icon: Icons.military_tech,
        builder: (_) => const tc.TopCustomersPage(),
      ),
      _HomeItem(
        title: 'Utilidad',
        icon: Icons.insights,
        builder: (_) => const po.ProfitOverviewPage(),
      ),
      _HomeItem(
        title: 'CSV (import/export)',
        icon: Icons.file_upload,
        builder: (_) => const rep.ReportsPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Popperscu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              // Logo superior
              Center(
                child: Image.asset(
                  'assets/logo.png', // Asegúrate que exista en pubspec.yaml
                  height: 96,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.store_mall_directory, size: 72),
                ),
              ),
              const SizedBox(height: 16),
              // Botones en grilla
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 120,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _HomeCard(
                    icon: it.icon,
                    title: it.title,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: it.builder),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeItem {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
  const _HomeItem({required this.title, required this.icon, required this.builder});
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _HomeCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Material(
      color: color.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
