import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:popperscuv/repositories/sale_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtDT = DateFormat('yyyy-MM-dd HH:mm');

  final _customerCtrl = TextEditingController();
  String? _customerId; // teléfono o id

  DateTime _from = _startOfDay(DateTime.now());
  DateTime _to = _endOfDay(DateTime.now());

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 0, 0, 0);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  void dispose() {
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load() {
    return SaleRepository().history(
      customerId: (_customerId == null || _customerId!.isEmpty) ? null : _customerId,
      from: _from,
      to: _to,
    );
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _from = _startOfDay(picked));
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _to = _endOfDay(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ventas'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cliente (ID o teléfono)',
                          prefixIcon: Icon(Icons.person_search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          setState(() => _customerId = v.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Aplicar',
                      child: FilledButton(
                        onPressed: () => setState(
                            () => _customerId = _customerCtrl.text.trim()),
                        child: const Icon(Icons.check),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Limpiar',
                      child: IconButton(
                        onPressed: () {
                          _customerCtrl.clear();
                          setState(() => _customerId = null);
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFrom,
                        icon: const Icon(Icons.date_range),
                        label: Text('Desde: ${_fmtDate.format(_from)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTo,
                        icon: const Icon(Icons.date_range),
                        label: Text('Hasta: ${_fmtDate.format(_to)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de resultados
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];

                // Totales
                double total = 0, discount = 0, profit = 0;
                for (final r in rows) {
                  total += (r['total'] as num?)?.toDouble() ?? 0.0;
                  discount += (r['discount'] as num?)?.toDouble() ?? 0.0;
                  profit += (r['profit'] as num?)?.toDouble() ?? 0.0;
                }

                return Column(
                  children: [
                    if (rows.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Órdenes: ${rows.length}'),
                            Text('Total: \$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Desc: \$${discount.toStringAsFixed(2)}'),
                            Text('Utilidad: \$${profit.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final r = rows[i];
                                final createdAt =
                                    (r['created_at'] ?? r['createdAt'])
                                        ?.toString();
                                final dt = DateTime.tryParse(createdAt ?? '');
                                final total =
                                    (r['total'] as num?)?.toDouble() ?? 0.0;
                                final discount =
                                    (r['discount'] as num?)?.toDouble() ?? 0.0;
                                final profit =
                                    (r['profit'] as num?)?.toDouble() ?? 0.0;
                                final customer =
                                    (r['customer_id'] ?? r['customerId'])
                                        ?.toString();

                                return ListTile(
                                  title: Text(
                                    dt != null
                                        ? _fmtDT.format(dt)
                                        : (createdAt ?? ''),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (customer != null &&
                                          customer.isNotEmpty)
                                        'Cliente: $customer',
                                      'Desc: \$${discount.toStringAsFixed(2)}',
                                      'Utilidad: \$${profit.toStringAsFixed(2)}',
                                    ].join('  ·  '),
                                  ),
                                  trailing: Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
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