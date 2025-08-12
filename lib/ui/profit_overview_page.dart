import 'package:flutter/material.dart';
import '../repositories/sale_repository.dart';

class ProfitOverviewPage extends StatefulWidget {
  const ProfitOverviewPage({super.key});
  @override
  State<ProfitOverviewPage> createState() => _ProfitOverviewPageState();
}

class _ProfitOverviewPageState extends State<ProfitOverviewPage> {
  bool _loading = false;
  Map<String, Map<String, double>> _data = {};

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(()=> _loading = true);
    final repo = SaleRepository();
    final now = DateTime.now();

    DateTime d0 = DateTime(now.year, now.month, now.day);
    DateTime d1 = d0.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    DateTime w0 = d0.subtract(Duration(days: d0.weekday - 1));
    DateTime w1 = w0.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    DateTime m0 = DateTime(now.year, now.month, 1);
    DateTime m1 = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    DateTime y0 = DateTime(now.year, 1, 1);
    DateTime y1 = DateTime(now.year, 12, 31, 23, 59, 59);

    final day = await repo.summary(d0, d1);
    final week = await repo.summary(w0, w1);
    final month = await repo.summary(m0, m1);
    final year = await repo.summary(y0, y1);

    if (!mounted) return;
    setState((){
      _data = {'Hoy': day, 'Semana': week, 'Mes': month, 'Año': year};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilidad % (periodos)'),
        leading: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png'))),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: _loading ? const SizedBox(width: 20,height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          )
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: _data.entries.map((e) {
              final rev = e.value['revenue'] ?? 0;
              final prof = e.value['profit'] ?? 0;
              final pct = rev <= 0 ? 0 : (prof / rev * 100);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text('Ventas: ${rev.toStringAsFixed(2)}'),
                      Text('Utilidad: ${prof.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      Text('Utilidad %: ${pct.toStringAsFixed(2)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
    );
  }
}
