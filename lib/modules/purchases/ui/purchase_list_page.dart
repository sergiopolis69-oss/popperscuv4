
import 'package:flutter/material.dart';
import '../data/purchase_dao.dart';
import '../data/purchase_models.dart';
import '../data/purchase_repository.dart';
import 'purchase_form_page.dart';
import '../../purchases/logic/purchase_service.dart';

class PurchaseListPage extends StatefulWidget {
  final PurchaseRepository repo;
  const PurchaseListPage({super.key, required this.repo});
  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  late final PurchaseDao _dao = PurchaseDao(widget.repo.db);
  late Future<List<Map<String, Object?>>> _future = _dao.fetchPurchasesSummary();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => PurchaseFormPage(service: PurchaseService(widget.repo))),
          );
          if (ok == true) setState(() => _future = _dao.fetchPurchasesSummary());
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data! as List<Map<String, Object?>>;
          if (rows.isEmpty) return const Center(child: Text('Sin compras'));
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final pm = PaymentMethod.values[(r['payment_method'] as int)];
              return ExpansionTile(
                title: Text('${r['supplier_name']} • \$${(r['total'] as num).toStringAsFixed(2)}'),
                subtitle: Text('${DateTime.parse(r['date'] as String)} • ${pm.name} • ${r['item_count']} artículos'),
                children: [
                  FutureBuilder(
                    future: _dao.fetchPurchaseItems(r['id'] as int),
                    builder: (context, itemsSnap) {
                      if (!itemsSnap.hasData) return const Padding(
                        padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                      final items = itemsSnap.data! as List<Map<String, Object?>>;
                      return Column(
                        children: items.map((it) => ListTile(
                          dense: true,
                          title: Text('${it['product_name']}'),
                          trailing: Text('${it['qty']} x \$${it['unit_cost']}'),
                        )).toList(),
                      );
                    },
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}
