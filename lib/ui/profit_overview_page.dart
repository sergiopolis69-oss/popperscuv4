
import 'package:flutter/material.dart';
import '../repositories/sale_repository.dart';

class ProfitOverviewPage extends StatefulWidget {
  const ProfitOverviewPage({super.key});
  @override
  State<ProfitOverviewPage> createState() => _ProfitOverviewPageState();
}

class _ProfitOverviewPageState extends State<ProfitOverviewPage> {
  String _period = 'Día';

  Future<Map<String, num>> _load() async {
    final now = DateTime.now();
    late DateTime from, to;
    switch (_period) {
      case 'Día':
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Semana':
        final monday = now.subtract(Duration(days: (now.weekday - 1)));
        final sunday = monday.add(const Duration(days: 6));
        from = DateTime(monday.year, monday.month, monday.day);
        to = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
        break;
      case 'Mes':
        from = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        to = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        break;
      case 'Año':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      default:
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    final summary = await SaleRepository().summary(from, to);
    // Esperamos: total, discount, profit, shipping (si tu repo lo devuelve)
    final total = (summary['total'] as num?) ?? 0;
    final profit = (summary['profit'] as num?) ?? 0;
    final discount = (summary['discount'] as num?) ?? 0;
    final shipping = (summary['shipping'] as num?) ?? 0;
    final pct = (total == 0) ? 0 : ((profit / total) * 100);

    return {
      'total': total,
      'profit': profit,
      'discount': discount,
      'shipping': shipping,
      'pct': pct,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilidad')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Periodo:  '),
                DropdownButton<String>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(value: 'Día', child: Text('Día')),
                    DropdownMenuItem(value: 'Semana', child: Text('Semana')),
                    DropdownMenuItem(value: 'Mes', child: Text('Mes')),
                    DropdownMenuItem(value: 'Año', child: Text('Año')),
                  ],
                  onChanged: (v) => setState(() => _period = v ?? 'Día'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() {}),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<Map<String, num>>(
                future: _load(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data ?? const {'total':0,'profit':0,'discount':0,'shipping':0,'pct':0};
                  return ListView(
                    children: [
                      _tile('Ventas', data['total']!.toDouble()),
                      _tile('Utilidad', data['profit']!.toDouble()),
                      _tile('% Utilidad', data['pct']!.toDouble(), isPercent: true),
                      _tile('Descuento', data['discount']!.toDouble()),
                      _tile('Envío cobrado', data['shipping']!.toDouble()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, double value, {bool isPercent = false}) {
    final text = isPercent ? value.toStringAsFixed(2) + '%' : '\$' + value.toStringAsFixed(2);
    return ListTile(
      title: Text(label),
      trailing: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
