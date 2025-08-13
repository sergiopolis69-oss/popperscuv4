// lib/ui/top_customers_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/sale_repository.dart';

class TopCustomersPage extends StatefulWidget {
  const TopCustomersPage({super.key});

  @override
  State<TopCustomersPage> createState() => _TopCustomersPageState();
}

class _TopCustomersPageState extends State<TopCustomersPage> {
  // Rango por defecto: mes actual
  late DateTimeRange _range;
  final _money = NumberFormat.currency(symbol: r'$');
  final _fmtDate = DateFormat('yyyy-MM-dd');
  final _fmtDT = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
    _range = DateTimeRange(start: start, end: end);
  }

  DateTime get _from => DateTime(_range.start.year, _range.start.month, _range.start.day);
  DateTime get _to   => DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59, 999);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'De ${_fmtDate.format(_from)} a ${_fmtDate.format(_to)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Rango'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: SaleRepository().topCustomers(_from, _to),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('Sin datos en el rango seleccionado'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = rows[i];
                    final name   = (m['name'] as String?) ?? 'Mostrador';
                    final orders = (m['orders'] as num?)?.toInt() ?? 0;
                    final total  = (m['total'] as num?)?.toDouble() ?? 0.0;
                    final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
                    final pct    = total > 0 ? (profit / total) * 100 : 0.0;

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('Órdenes: $orders · Utilidad ${_money.format(profit)} · ${pct.toStringAsFixed(1)}%'),
                      trailing: Text(
                        _money.format(total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _showCustomerHistory(
                        customerId: (m['customerId'] as String?) ?? '',
                        customerName: name,
                      ),
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

  void _showCustomerHistory({required String customerId, required String customerName}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial: $customerName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<Map<String, Object?>>>(
                    future: SaleRepository().history(customerId: customerId.isEmpty ? null : customerId, from: _from, to: _to),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }
                      final rows = snap.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(child: Text('Sin ventas en el periodo'));
                      }
                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = rows[i];
                          final createdAt = (m['createdAt'] as String?) ?? '';
                          DateTime? dt;
                          try { dt = DateTime.parse(createdAt); } catch (_) {}
                          final total  = (m['total'] as num?)?.toDouble() ?? 0.0;
                          final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;
                          final discount = (m['discount'] as num?)?.toDouble() ?? 0.0;
                          final items = (m['items'] as num?)?.toInt() ?? 0;
                          final method = (m['paymentMethod'] as String?) ?? '';

                          return ListTile(
                            dense: true,
                            title: Text(dt != null ? _fmtDT.format(dt) : createdAt),
                            subtitle: Text('Items: $items · Desc: ${_money.format(discount)} · ${method.isEmpty ? '' : method}'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_money.format(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Utilidad ${_money.format(profit)}'),
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
      },
    );
  }
}
