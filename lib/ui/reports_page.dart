
import 'package:flutter/material.dart';
import '../utils/csv_io.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes / CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final p = await CsvIO.exportTable('products');
                    setState(() => status = 'Exportado: $p');
                  },
                  child: const Text('Exportar products.csv'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final p = await CsvIO.exportTable('customers');
                    setState(() => status = 'Exportado: $p');
                  },
                  child: const Text('Exportar customers.csv'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final p = await CsvIO.exportTable('sales');
                    setState(() => status = 'Exportado: $p');
                  },
                  child: const Text('Exportar sales.csv'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final n = await CsvIO.importInventoryAddsFromCsv();
                    setState(() => status = 'Inventario actualizado (sumas): $n filas');
                  },
                  child: const Text('Importar inventario (sumar)'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final n = await CsvIO.importProductsUpsertFromCsv();
                    setState(() => status = 'Productos actualizados (upsert): $n filas');
                  },
                  child: const Text('Upsert productos (CSV)'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final n = await CsvIO.importProductsFromCsv();
                    setState(() => status = 'Productos nuevos insertados: $n');
                  },
                  child: const Text('Insertar productos nuevos (CSV)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(status),
          ],
        ),
      ),
    );
  }
}
