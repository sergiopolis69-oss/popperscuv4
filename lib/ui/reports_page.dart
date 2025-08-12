import 'package:flutter/material.dart';
import '../utils/csv_io.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? status;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes / CSV'),
        leading: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png'))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exportar a Descargas'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableToDownloads('products'); setState(()=> status='Exportado a: $p'); }, child: const Text('products.csv')),
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableToDownloads('customers'); setState(()=> status='Exportado a: $p'); }, child: const Text('customers.csv')),
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableToDownloads('sales'); setState(()=> status='Exportado a: $p'); }, child: const Text('sales.csv')),
            ]),
            const Divider(height: 32),
            const Text('Exportar local (app docs)'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableLocal('products'); setState(()=> status='Guardado local: $p'); }, child: const Text('products.csv')),
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableLocal('customers'); setState(()=> status='Guardado local: $p'); }, child: const Text('customers.csv')),
              ElevatedButton(onPressed: () async { final p = await CsvIO.exportTableLocal('sales'); setState(()=> status='Guardado local: $p'); }, child: const Text('sales.csv')),
            ]),
            const SizedBox(height: 16),
            if (status != null) Text(status!),
          ],
        ),
      ),
    );
  }
}
