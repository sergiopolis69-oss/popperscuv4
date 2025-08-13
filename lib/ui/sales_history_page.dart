
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtDT = DateFormat('yyyy-MM-dd HH:mm');

  String? _customerId;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _to = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickFrom,
                        child: Text('De: ${_fmtDate.format(_from)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTo,
                        child: Text('A: ${_fmtDate.format(_to)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Cliente (ID opcional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _customerId = v.trim().isEmpty ? null : v.trim()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Actualizar'),
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>>(
              future: SaleRepository().history(customerId: _customerId, from: _from, to: _to),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                double total = 0.0;
                double profit = 0.0;
                for (final r in rows) {
                  total += (r['total'] as num?)?.toDouble() ?? 0.0;
                  profit += (r['profit'] as num?)?.toDouble() ?? 0.0;
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final whenStr = (r['created_at'] as String?) ?? '';
                          DateTime? when;
                          try { when = DateTime.parse(whenStr); } catch (_) {}
                          final title = (r['customer_name'] as String?) ?? (r['customer_id'] as String? ?? 'Venta');
                          final t = (r['total'] as num?)?.toDouble() ?? 0.0;
                          final p = (r['profit'] as num?)?.toDouble() ?? 0.0;
                          return ListTile(
                            title: Text(title),
                            subtitle: Text(when != null ? _fmtDT.format(when) : whenStr),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('\$${t.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Utilidad \$${p.toStringAsFixed(2)}'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ventas: ${rows.length}'),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Utilidad \$${profit.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
