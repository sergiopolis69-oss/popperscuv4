
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';

class TopCustomersPage extends StatefulWidget {
  const TopCustomersPage({super.key});

  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  String _period = 'Mes';
  DateTime _anchor = DateTime.now();

  DateTimeRange _rangeFor(String period, DateTime anchor) {
    switch (period) {
      case 'Día':
        final start = DateTime(anchor.year, anchor.month, anchor.day);
        final end = DateTime(anchor.year, anchor.month, anchor.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case 'Semana':
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999),
        );
      case 'Año':
        return DateTimeRange(
          start: DateTime(anchor.year, 1, 1),
          end: DateTime(anchor.year, 12, 31, 23, 59, 59, 999),
        );
      case 'Mes':
      default:
        final start = DateTime(anchor.year, anchor.month, 1);
        final last = DateTime(anchor.year, anchor.month + 1, 0);
        return DateTimeRange(
          start: start,
          end: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
        );
    }
  }

  Future<List<Map<String, Object?>>> _fetch() async {
    final r = _rangeFor(_period, _anchor);
    try {
      return await SaleRepository().topCustomers(r.start, r.end);
    } catch (_) {
      try {
        return await (SaleRepository() as dynamic).topCustomers(from: r.start, to: r.end);
      } catch (_) {
        return <Map<String, Object?>>[];
      }
    }
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final range = _rangeFor(_period, _anchor);
    return Scaffold(
      appBar: AppBar(title: const Text('Top clientes')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(value: 'Día', child: Text('Día')),
                    DropdownMenuItem(value: 'Semana', child: Text('Semana')),
                    DropdownMenuItem(value: 'Mes', child: Text('Mes')),
                    DropdownMenuItem(value: 'Año', child: Text('Año')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? 'Mes'),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickAnchor,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text(fmt.format(_anchor)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('Rango: ' + fmt.format(range.start) + ' a ' + fmt.format(range.end)),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>> (
                future: _fetch(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snap.data ?? const <Map<String, Object?>>[];
                  if (rows.isEmpty) return const Center(child: Text('Sin datos'));

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final m = rows[i];
                      final name = (m['name'] ?? m['customer_name'] ?? m['customerId'] ?? '-') as String;
                      final total = (m['total'] as num?)?.toDouble() ?? 0.0;
                      final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
                      final orders = (m['orders'] as num?)?.toInt() ?? (m['count'] as num?)?.toInt() ?? 0;
                      final pct = total == 0 ? 0 : (profit / total * 100);
                      return ListTile(
                        title: Text(name),
                        subtitle: Text('Órdenes: ' + orders.toString() + ' · Utilidad: \\$' + profit.toStringAsFixed(2) + ' · ' + pct.toStringAsFixed(1) + '%'),
                        trailing: Text('\\$' + total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () async {
                          final r = _rangeFor(_period, _anchor);
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => _CustomerHistorySheet(customerId: (m['customer_id'] ?? m['customerId'] ?? '') as String, name: name, from: r.start, to: r.end),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHistorySheet extends StatelessWidget {
  final String customerId;
  final String name;
  final DateTime from;
  final DateTime to;

  const _CustomerHistorySheet({required this.customerId, required this.name, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compras de ' + name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, Object?>>> (
            future: SaleRepository().history(customerId: customerId, from: from, to: to),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final rows = snap.data ?? const <Map<String, Object?>>[];
              if (rows.isEmpty) return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sin compras en el periodo'),
              );

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final m = rows[i];
                    final total = (m['total'] as num?)?.toDouble() ?? 0.0;
                    final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
                    final createdAtStr = (m['created_at'] ?? m['createdAt'] ?? '') as String;
                    DateTime? createdAt;
                    try { createdAt = DateTime.tryParse(createdAtStr); } catch (_) {}
                    final when = createdAt == null ? '-' : fmt.format(createdAt);
                    return ListTile(
                      title: Text('\\$' + total.toStringAsFixed(2)),
                      subtitle: Text(when),
                      trailing: Text('Utilidad \\$' + profit.toStringAsFixed(2)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
