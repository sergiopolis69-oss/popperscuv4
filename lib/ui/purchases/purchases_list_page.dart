import 'package:flutter/material.dart';
import '../../repositories/purchase_repository.dart';
import '../../models/payment_method.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';

class PurchasesListPage extends StatefulWidget {
  final PurchaseRepository repo;
  const PurchasesListPage({super.key, required this.repo});

  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async { rows = await widget.repo.listWithSupplier(); setState((){}); }

  String _pmLabel(String raw) => PaymentMethodX.fromString(raw).label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = rows[i];
          final dt = DateTime.parse(r['created_at'] as String);
          final canceled = (r['is_canceled'] as int? ?? 0) == 1;
          return ListTile(
            title: Text(r['supplier_name'] as String, style: canceled ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
            subtitle: Text('${_pmLabel(r['payment_method'] as String)} · ${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'),
            trailing: Text('\$${(r['subtotal'] as num).toStringAsFixed(2)}'),
            onTap: () async {
              final id = r['id'] as int;
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PurchaseDetailPage(purchaseId: id, repo: widget.repo),
              ));
              _load();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PurchaseFormPage(repo: widget.repo),
          ));
          if (ok == true) _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PurchaseFormPage extends StatefulWidget {
  final PurchaseRepository repo;
  const PurchaseFormPage({super.key, required this.repo});

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  int? supplierId = 1; // demo
  PaymentMethod pm = PaymentMethod.cash;
  final List<_PurchaseItemRow> rows = [];
  final notesCtrl = TextEditingController();

  void _addRow() => setState(() => rows.add(_PurchaseItemRow()));
  void _removeRow(int i) => setState(() => rows.removeAt(i));

  Future<void> _save() async {
    if (supplierId == null || rows.isEmpty) return;
    final items = rows.map((r) => r.toItem()).toList();
    final p = Purchase(
      supplierId: supplierId!,
      createdAt: DateTime.now(),
      paymentMethod: pm,
      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
      items: items,
    );
    await widget.repo.create(p);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva compra')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<int>(
            value: supplierId,
            items: const [ DropdownMenuItem(value: 1, child: Text('Proveedor demo')) ],
            onChanged: (v) => setState(() => supplierId = v),
            decoration: const InputDecoration(labelText: 'Proveedor'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PaymentMethod>(
            value: pm,
            items: PaymentMethod.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
            onChanged: (v) => setState(() => pm = v!),
            decoration: const InputDecoration(labelText: 'Forma de pago'),
          ),
          const SizedBox(height: 8),
          TextFormField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notas')),
          const SizedBox(height: 12),
          const Text('Ítems', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...rows.asMap().entries.map((e) => e.value.build(context, onRemove: () => _removeRow(e.key))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add), label: const Text('Agregar ítem')),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _PurchaseItemRow {
  final productIdCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final costCtrl = TextEditingController();

  PurchaseItem toItem() => PurchaseItem(
    productId: int.parse(productIdCtrl.text),
    quantity: double.parse(qtyCtrl.text),
    unitCost: double.parse(costCtrl.text),
  );

  Widget build(BuildContext context, {required VoidCallback onRemove}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(controller: productIdCtrl, decoration: const InputDecoration(labelText: 'Producto ID')),
          Row(children: [
            Expanded(child: TextFormField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Costo unitario'), keyboardType: TextInputType.number)),
          ]),
          Align(alignment: Alignment.centerRight, child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)))
        ]),
      ),
    );
  }
}

class PurchaseDetailPage extends StatefulWidget {
  final int purchaseId; final PurchaseRepository repo;
  const PurchaseDetailPage({super.key, required this.purchaseId, required this.repo});
  @override State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  Map<String, dynamic>? data;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { data = await widget.repo.getWithItems(widget.purchaseId); setState((){}); }

  Future<void> _cancelItem(int itemId) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cancelar ítem'),
      content: const Text('Esto restará la existencia de ese producto. ¿Continuar?'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('No')), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Sí'))],
    ));
    if (ok==true) { await widget.repo.cancelItem(itemId); await _load(); }
  }

  Future<void> _cancelPurchase() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cancelar compra'),
      content: const Text('Se restará la existencia de todos los ítems no cancelados y la compra quedará cancelada.'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('No')), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Sí, cancelar'))],
    ));
    if (ok==true) { await widget.repo.cancelPurchase(widget.purchaseId); if (mounted) Navigator.pop(context,true); }
  }

  @override
  Widget build(BuildContext context) {
    if (data==null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final h = data!['header'] as Map<String,dynamic>;
    final items = (data!['items'] as List).cast<Map<String,dynamic>>();
    final dt = DateTime.parse(h['created_at'] as String);
    final pm = PaymentMethodX.fromString(h['payment_method'] as String).label;
    final canceled = (h['is_canceled'] as int? ?? 0) == 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de compra'), actions: [
        if (!canceled) IconButton(onPressed: _cancelPurchase, icon: const Icon(Icons.cancel_schedule_send)),
      ]),
      body: ListView(children: [
        ListTile(
          title: Text('Proveedor #${h['supplier_id']}'),
          subtitle: Text('Fecha: ${dt.day}/${dt.month}/${dt.year}  ·  Pago: $pm'),
          trailing: Text('\$${(h['subtotal'] as num).toStringAsFixed(2)}'),
        ),
        if (canceled) const Padding(padding: EdgeInsets.all(12), child: Text('COMPRA CANCELADA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        const Divider(),
        ...items.map((it){
          final isCanceled = (it['is_canceled'] as int? ?? 0) == 1;
          return ListTile(
            title: Text((it['product_name'] as String?) ?? 'Producto ${it['product_id']}', style: isCanceled ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
            subtitle: Text('Cant: ${(it['quantity'] as num)}  ·  Costo: \\${(it['unit_cost'] as num).toStringAsFixed(2)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children:[
              Text('\\${(it['line_total'] as num).toStringAsFixed(2)}'),
              if (!isCanceled && !canceled) IconButton(onPressed: ()=>_cancelItem(it['id'] as int), icon: const Icon(Icons.undo)),
            ]),
          );
        }),
      ]),
    );
  }
}
