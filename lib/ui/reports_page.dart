import 'package:flutter/material.dart';
import '../utils/csv_io.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar CSV')),
      body: ListView(
        children: [
          const ListTile(title: Text('Exportar')),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Exportar productos.csv'),
            onTap: () async {
              final p = await CsvIO.exportTable('products');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: $p')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Exportar customers.csv'),
            onTap: () async {
              final p = await CsvIO.exportTable('customers');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: $p')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Exportar sales.csv'),
            onTap: () async {
              final p = await CsvIO.exportTable('sales');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: $p')));
            },
          ),
          const Divider(),
          const ListTile(title: Text('Importar')),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar productos (upsert por SKU)'),
            subtitle: const Text('Columnas: sku, name?, price?, cost?, stock? o qty?, category?'),
            onTap: () async {
              final m = await CsvIO.importProductsUpsertFromCsv();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Prod → ins:${m['inserted']} act:${m['updated']} om:${m['skipped']} err:${m['errors']}')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Ajustes inventario (sumar qty por SKU)'),
            subtitle: const Text('Columnas: sku, qty'),
            onTap: () async {
              final m = await CsvIO.importInventoryAddsFromCsv();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Inv → cambios:${m['changed']} falt:${m['missing']} err:${m['errors']}')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Importar clientes (upsert por ID o phone)'),
            subtitle: const Text('Columnas: id?, name?, phone? — si id vacío usa phone como ID'),
            onTap: () async {
              final m = await CsvIO.importCustomersFromCsv();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Clientes → ins:${m['inserted']} act:${m['updated']} om:${m['skipped']} err:${m['errors']}')),
              );
            },
          ),
        ],
      ),
    );
  }
}