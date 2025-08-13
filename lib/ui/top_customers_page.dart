import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';

class TopCustomersPage extends StatefulWidget {
  const TopCustomersPage({super.key});

  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  DateTime _anchor = DateTime.now();
  String _period = 'Mes'; // Día, Semana, Mes, Año
  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtDT = DateFormat('yyyy-MM-dd HH:mm');

  (DateTime, DateTime) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case 'Día':
        return (a, a.add(const Duration(days: 1)));
      case 'Semana':
        final w0 = a.subtract(Duration(days: a.weekday - 1));
        final w1 = w0.add(const Duration(days: 7));
        return (w0, w1);
      case 'Año':
        final y0 = DateTime(a.year, 1, 1);
        final y1 = DateTime(a.year + 1, 1, 1);
        return (y0, y1);
      case 'Mes':
      default:
        final m0 = DateTime(a.year, a.month, 1);
        final m1 = DateTime(a.year, a.month + 1, 1);
        return (m0, m1);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _anchor = d);
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _range();
    return Scaffold(
      appBar: AppBar(title: const Text('Mejores clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text('Fecha: ${_fmtDate.format(_anchor)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _period,
                    onChanged: (v) => setState(() => _period = v ?? 'Mes'),
                    items: const [
                      DropdownMenuItem(value: 'Día', child: Text('Día')),
                      DropdownMenuItem(value: 'Semana', child: Text('Semana')),
                      DropdownMenuItem(value: 'Mes', child: Text('Mes')),
                      DropdownMenuItem(value: 'Año', child: Text('Año')),
                    ],
                    decoration: const InputDecoration(labelText: 'Periodo'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: SaleRepository().topCustomers(from, to),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final customerId = (r['customer_id'] as String?) ?? '';
                    final name = (r['name'] as String?) ?? customerId;
                    final orders = (r['orders'] as num?)?.toInt() ?? 0;
                    final total = (r['total'] as num?)?.toDouble() ?? 0.0;
                    final profit = (r['profit'] as num?)?.toDouble() ?? 0.0;
                    final pct = total == 0 ? 0.0 : (profit / total * 100.0);
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        'Órdenes: ${orders.toString()} · Utilidad: \$${profit.toStringAsFixed(2)} · ${pct.toStringAsFixed(1)}%',
                      ),
                      trailing: Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _CustomerHistorySheet(
                            customerId: customerId,
                            from: from,
                            to: to,
                            fmtDT: _fmtDT,
                          ),
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
    );
  }
}

class _CustomerHistorySheet extends StatelessWidget {
  final String customerId;
  final DateTime from;
  final DateTime to;
  final DateFormat fmtDT;
  const _CustomerHistorySheet({
    required this.customerId,
    required this.from,
    required this.to,
    required this.fmtDT,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: SaleRepository()
              .history(customerId: customerId, from: from, to: to),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snapshot.data!;
            double total = 0.0;
            double profit = 0.0;
            for (final r in rows) {
              total += (r['total'] as num?)?.toDouble() ?? 0.0;
              profit += (r['profit'] as num?)?.toDouble() ?? 0.0;
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('\$${total.toStringAsFixed(2)}'),
                  subtitle: Text('${rows.length} ventas'),
                  trailing: Text('Utilidad \$${profit.toStringAsFixed(2)}'),
                ),
                const Divider(height: 1),
                ...rows.map((r) {
                  final whenStr = (r['created_at'] as String?) ?? '';
                  DateTime? when;
                  try {
                    when = DateTime.parse(whenStr);
                  } catch (_) {}
                  final t = (r['total'] as num?)?.toDouble() ?? 0.0;
                  final p = (r['profit'] as num?)?.toDouble() ?? 0.0;
                  return ListTile(
                    title: Text('\$${t.toStringAsFixed(2)}'),
                    subtitle: Text(when != null ? fmtDT.format(when) : whenStr),
                    trailing: Text('Utilidad \$${p.toStringAsFixed(2)}'),
                  );
                }).toList(),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}
