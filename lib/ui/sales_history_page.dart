
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String? _customerId;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtDT = DateFormat('yyyy-MM-dd HH:mm');

  Future<List<Map<String, Object?>>> _loadCustomers() => CustomerRepository().all();

  Future<List<Map<String, Object?>>> _loadHistory() async {
    try {
      return await SaleRepository().history(customerId: _customerId, from: _from, to: _to);
    } catch (_) {
      // Si tu repo usa otra firma, adapta aquí.
      return <Map<String, Object?>>[];
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Map<String, Object?>>> (
                    future: _loadCustomers(),
                    builder: (context, snap) {
                      final items = snap.data ?? const <Map<String, Object?>>[];
                      final dropdownItems = <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(value: null, child: Text('Todos los clientes')),
                        ...items.map((c) {
                          final id = (c['id'] ?? '') as String;
                          final name = ((c['name'] ?? '') as String);
                          return DropdownMenuItem(value: id, child: Text(name.isEmpty ? id : name));
                        }),
                      ];
                      return DropdownButtonFormField<String?>(
                        value: _customerId,
                        items: dropdownItems,
                        onChanged: (v) => setState(() => _customerId = v),
                        decoration: const InputDecoration(labelText: 'Cliente'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickFrom,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Desde'),
                      child: Text(_fmtDate.format(_from)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickTo,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Hasta'),
                      child: Text(_fmtDate.format(_to)),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>> (
                future: _loadHistory(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snap.data ?? const <Map<String, Object?>>[];
                  if (rows.isEmpty) return const Center(child: Text('Sin ventas'));

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final m = rows[i];
                      final id = (m['id'] ?? '') as String;
                      final total = (m['total'] as num?)?.toDouble() ?? 0.0;
                      final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
                      final discount = (m['discount'] as num?)?.toDouble() ?? 0.0;
                      final pay = (m['payment_method'] ?? m['paymentMethod'] ?? '-') as String;
                      final customerName = (m['customer_name'] ?? m['name'] ?? m['customerId'] ?? '-') as String;
                      final createdAtStr = (m['created_at'] ?? m['createdAt'] ?? '') as String;
                      DateTime? createdAt;
                      try { createdAt = DateTime.tryParse(createdAtStr); } catch (_) {}
                      final when = createdAt == null ? '-' : _fmtDT.format(createdAt);

                      return ListTile(
                        title: Text('Venta $id'),
                        subtitle: Text('$when · Cliente: $customerName · Pago: $pay · Desc: \$${discount.toStringAsFixed(2)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$' + total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Utilidad \$' + profit.toStringAsFixed(2)),
                          ],
                        ),
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
