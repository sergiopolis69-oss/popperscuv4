import 'package:flutter/material.dart';
import '../repositories/sale_repository.dart';
import '../utils/misc.dart';

class TopCustomersPage extends StatefulWidget {
  const TopCustomersPage({super.key});
  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  final _repo = SaleRepository();
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) setState(() { _from = range.start; _to = range.end; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top clientes'),
        actions: [
          IconButton(onPressed: _pickRange, icon: const Icon(Icons.date_range)),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _repo.topCustomers(_from, _to),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) return const Center(child: Text('Sin datos'));
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = data[i];
              final name   = toStr(r['customer_name']).isNotEmpty ? toStr(r['customer_name']) : 'Mostrador';
              final total  = (r['total'] as num?)?.toDouble() ?? 0;
              final profit = (r['profit'] as num?)?.toDouble() ?? 0;
              final orders = (r['orders'] as num?)?.toInt() ?? 0;
              final pct    = (r['pct'] as num?)?.toDouble() ?? 0;

              return ListTile(
                title: Text(name),
                subtitle: Text('Órdenes: $orders · Utilidad: \$${profit.toStringAsFixed(2)} · ${pct.toStringAsFixed(1)}%'),
                trailing: Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }
}