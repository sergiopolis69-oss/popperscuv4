import 'package:flutter/material.dart';
import 'package:popperscuv/repositories/sale_repository.dart';
import 'package:popperscuv/repositories/customer_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _repo = SaleRepository();

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  Map<String, Object?>? _customer; // {'id':..., 'name':...}

  String get _fromLabel => _fmtDate(_from);
  String get _toLabel => _fmtDate(_to);
  String get _customerLabel => _customer == null ? 'Todos' : (_customer!['name']?.toString().isNotEmpty ?? false)
      ? _customer!['name']!.toString()
      : _customer!['id']!.toString();

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _from = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _to = DateTime(d.year, d.month, d.day, 23, 59, 59, 999));
  }

  Future<void> _pickCustomer() async {
    final picked = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _CustomerPickerDialog(),
    );
    if (picked != null) {
      setState(() => _customer = picked);
    }
  }

  Future<List<Map<String, Object?>>> _loadHistory() {
    return _repo.history(
      customerId: _customer?['id']?.toString(),
      from: _from,
      to: _to,
    );
  }

  Future<Map<String, Object?>> _loadSummary() {
    return _repo.summary(_from, _to);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.date_range),
                    label: Text('Desde: $_fromLabel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.event),
                    label: Text('Hasta: $_toLabel'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCustomer,
                    icon: const Icon(Icons.person_search),
                    label: Text('Cliente: $_customerLabel'),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar filtro',
                  onPressed: _customer == null ? null : () => setState(() => _customer = null),
                  icon: const Icon(Icons.clear),
                )
              ],
            ),
          ),
          // Resumen
          FutureBuilder<Map<String, Object?>>(
            future: _loadSummary(),
            builder: (context, snap) {
              final m = (snap.data ?? const <String, Object?>{});
              final orders = (m['orders'] as num?)?.toInt() ?? 0;
              final total = (m['total'] as num?)?.toDouble() ?? 0.0;
              final discount = (m['discount'] as num?)?.toDouble() ?? 0.0;
              final shipping = (m['shipping'] as num?)?.toDouble() ?? 0.0;
              final profit = (m['profit'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(child: Text('Órdenes: $orders')),
                        Expanded(child: Text('Total: \$${total.toStringAsFixed(2)}')),
                        Expanded(child: Text('Desc: \$${discount.toStringAsFixed(2)}')),
                        Expanded(child: Text('Envío: \$${shipping.toStringAsFixed(2)}')),
                        Expanded(child: Text('Utilidad: \$${profit.toStringAsFixed(2)}')),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          // Lista
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _loadHistory(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <Map<String, Object?>>[];
                if (list.isEmpty) {
                  return const Center(child: Text('Sin registros'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = list[i];
                    final createdAt = it['created_at']?.toString() ?? '';
                    final d = _tryParseIso(createdAt);
                    final dt = d == null ? createdAt : _fmtDateTime(d);
                    final cname = (it['customer_name'] ?? '').toString();
                    final cid = (it['customer_id'] ?? '').toString();
                    final total = (it['total'] as num?)?.toDouble() ?? 0.0;
                    final profit = (it['profit'] as num?)?.toDouble() ?? 0.0;

                    return ListTile(
                      title: Text(dt),
                      subtitle: Text(cname.isNotEmpty ? cname : (cid.isNotEmpty ? 'Cliente: $cid' : 'Sin cliente')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Utilidad \$${profit.toStringAsFixed(2)}'),
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
    );
  }
}

// --- Picker de cliente con buscador ---
class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog();

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _repo = CustomerRepository();
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load() {
    final q = _q.text.trim();
    return _repo.listFiltered(q: q.isEmpty ? null : q);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar cliente'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _q,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre / id / teléfono',
                suffixIcon: IconButton(
                  onPressed: () {
                    _q.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _load(),
                builder: (context, snap) {
                  final list = snap.data ?? const <Map<String, Object?>>[];
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (list.isEmpty) {
                    return const Center(child: Text('Sin resultados'));
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = list[i];
                      final name = (it['name'] ?? '').toString();
                      final id = (it['id'] ?? '').toString();
                      final phone = (it['phone'] ?? '').toString();
                      return ListTile(
                        title: Text(name.isEmpty ? '(Sin nombre)' : name),
                        subtitle: Text([
                          if (id.isNotEmpty) 'ID: $id',
                          if (phone.isNotEmpty) 'Tel: $phone',
                        ].join('  •  ')),
                        onTap: () => Navigator.pop(context, it),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// --- helpers de fecha (sin intl) ---
String _fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _fmtDateTime(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
String _two(int n) => (n < 10 ? '0$n' : '$n');

DateTime? _tryParseIso(String s) {
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}