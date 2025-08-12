
import 'package:flutter/material.dart';
import '../repositories/sale_repository.dart';

class ProfitOverviewPage extends StatefulWidget {
  const ProfitOverviewPage({super.key});

  @override
  State<ProfitOverviewPage> createState() => _ProfitOverviewPageState();
}

enum Period { day, week, month, year }

class _ProfitOverviewPageState extends State<ProfitOverviewPage> {
  final repo = SaleRepository();
  Period _period = Period.day;
  bool _loading = true;
  Map<String, double> _data = const {
    'total': 0,
    'profit': 0,
    'discount': 0,
    'shipping': 0,
  };
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final r = _rangeFor(_period, now);
    _from = r.$1;
    _to = r.$2;
    _load();
  }

  (DateTime, DateTime) _rangeFor(Period p, DateTime now) {
    switch (p) {
      case Period.day:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case Period.week:
        // Lunes como inicio de semana
        final weekday = now.weekday; // 1=lunes ... 7=domingo
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
        final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999);
        return (start, end);
      case Period.month:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return (start, end);
      case Period.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return (start, end);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await repo.summary(_from, _to);
    setState(() {
      _data = m;
      _loading = false;
    });
  }

  String _money(double v) => '\$' + v.toStringAsFixed(2);
  String _pct(double v) => v.toStringAsFixed(1) + '%';

  @override
  Widget build(BuildContext context) {
    final total = _data['total'] ?? 0;
    final profit = _data['profit'] ?? 0;
    final discount = _data['discount'] ?? 0;
    final shipping = _data['shipping'] ?? 0;
    final profitPct = total <= 0 ? 0 : (profit / total * 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Utilidad (totales y porcentajes)')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Period>(
                    value: _period,
                    decoration: const InputDecoration(labelText: 'Periodo'),
                    items: const [
                      DropdownMenuItem(value: Period.day, child: Text('Día')),
                      DropdownMenuItem(value: Period.week, child: Text('Semana')),
                      DropdownMenuItem(value: Period.month, child: Text('Mes')),
                      DropdownMenuItem(value: Period.year, child: Text('Año')),
                    ],
                    onChanged: (p) {
                      if (p == null) return;
                      final r = _rangeFor(p, DateTime.now());
                      setState(() {
                        _period = p;
                        _from = r.$1;
                        _to = r.$2;
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Rango: ${_from.toIso8601String().substring(0, 10)}  →  ${_to.toIso8601String().substring(0, 10)}'),

            const SizedBox(height: 12),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _summaryGrid(context, total, profit, profitPct, discount, shipping),
                    const SizedBox(height: 12),
                    _breakdownCard(context, total, profit, profitPct, discount, shipping),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryGrid(BuildContext context, double total, double profit, double profitPct, double discount, double shipping) {
    final theme = Theme.of(context);
    final styleTitle = theme.textTheme.labelMedium;
    final styleVal = theme.textTheme.titleLarge;

    Widget card(String title, String value, [IconData? icon]) => Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(icon),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: styleTitle),
                const SizedBox(height: 4),
                Text(value, style: styleVal),
              ],
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth > 520;
        final children = [
          Expanded(child: card('Ventas', _money(total), Icons.attach_money)),
          const SizedBox(width: 8, height: 8),
          Expanded(child: card('Utilidad', _money(profit), Icons.trending_up)),
        ];
        final row2 = [
          Expanded(child: card('Utilidad %', _pct(profitPct), Icons.percent)),
          const SizedBox(width: 8, height: 8),
          Expanded(child: card('Descuento', _money(discount), Icons.sell_outlined)),
        ];
        final row3 = [
          Expanded(child: card('Envío cobrado', _money(shipping), Icons.local_shipping_outlined)),
        ];

        if (isWide) {
          return Column(
            children: [
              Row(children: children),
              Row(children: row2),
              Row(children: row3),
            ],
          );
        } else {
          return Column(
            children: [
              ...children,
              ...row2,
              ...row3,
            ],
          );
        }
      },
    );
  }

  Widget _breakdownCard(BuildContext context, double total, double profit, double profitPct, double discount, double shipping) {
    final theme = Theme.of(context);
    TextStyle label = theme.textTheme.bodyMedium!;
    TextStyle val = theme.textTheme.titleMedium!;

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: label)),
          Text(v, style: val),
        ],
      ),
    );

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalle', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            row('Ventas (total del periodo)', _money(total)),
            row('Utilidad (margen bruto)', _money(profit)),
            row('Utilidad % sobre ventas', _pct(profitPct)),
            row('Descuentos aplicados', _money(discount)),
            row('Costo de envío cobrado', _money(shipping)),
            const Divider(),
            row('Ventas netas (ventas - descuentos)', _money(total - shipping)), // ojo: total ya incluye envío
            row('Utilidad neta (sin envío)', _money(profit)), // utilidad ya no considera envío
          ],
        ),
      ),
    );
  }
}
