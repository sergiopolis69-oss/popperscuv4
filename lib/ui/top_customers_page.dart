import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';

enum Period { week, month, year }

class TopCustomersPage extends StatefulWidget {
  const TopCustomersPage({super.key});
  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  Period _period = Period.month;
  DateTime _anchor = DateTime.now();
  bool _loadingBtn = false;

  @override
  Widget build(BuildContext context) {
    final (from, to) = _rangeFor(_period, _anchor);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top clientes'),
        leading: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png'))),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DropdownButton<Period>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(value: Period.week, child: Text('Semana')),
                    DropdownMenuItem(value: Period.month, child: Text('Mes')),
                    DropdownMenuItem(value: Period.year, child: Text('Año')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? Period.month),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _anchor,
                      firstDate: DateTime(_anchor.year - 3),
                      lastDate: DateTime(_anchor.year + 3),
                    );
                    if (picked != null) setState(() => _anchor = picked);
                  },
                  child: Text('Fecha: ${DateFormat('yyyy-MM-dd').format(_anchor)}'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadingBtn ? null : () async {
                    setState(()=> _loadingBtn = true);
                    setState((){});
                    await Future.delayed(const Duration(milliseconds: 400));
                    setState(()=> _loadingBtn = false);
                  },
                  child: _loadingBtn ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Actualizar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: SaleRepository().topCustomers(from, to),
              builder: (c, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) return const Center(child: Text('Sin datos'));
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final r = rows[i];
                    final name = (r['customer_name'] ?? '(sin cliente)').toString();
                    final orders = (r['orders'] ?? 0).toString();
                    final spent = (r['spent'] ?? 0).toString();
                    final profit = (r['profit'] ?? 0).toString();
                    return ListTile(
                      title: Text(name),
                      subtitle: Text('Compras: $orders  | Total: $spent  | Utilidad: $profit'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => _FilteredHistory(customerId: r['customer_id'] as String?, from: from, to: to),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _rangeFor(Period p, DateTime anchor) {
    if (p == Period.week) {
      final start = DateTime(anchor.year, anchor.month, anchor.day).subtract(Duration(days: anchor.weekday - 1));
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start, end);
    } else if (p == Period.month) {
      final start = DateTime(anchor.year, anchor.month, 1);
      final end = DateTime(anchor.year, anchor.month + 1, 0, 23, 59, 59);
      return (start, end);
    } else {
      final start = DateTime(anchor.year, 1, 1);
      final end = DateTime(anchor.year, 12, 31, 23, 59, 59);
      return (start, end);
    }
  }
}

class _FilteredHistory extends StatelessWidget {
  final String? customerId;
  final DateTime from;
  final DateTime to;
  const _FilteredHistory({required this.customerId, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras del cliente')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SaleRepository().history(customerId: customerId, from: from, to: to),
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('Sin resultados'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (c, i) {
              final r = rows[i];
              final total = (r['total'] ?? 0).toString();
              final pay = (r['payment_method'] ?? '').toString();
              final profit = (r['profit'] ?? 0).toString();
              final createdAt = (r['created_at'] ?? '').toString();
              final name = (r['customer_name'] ?? '(sin cliente)').toString();
              return ListTile(
                title: Text('Total: $total  | Pago: $pay  | Utilidad: $profit'),
                subtitle: Text('$name — $createdAt'),
              );
            },
          );
        },
      ),
    );
  }
}
