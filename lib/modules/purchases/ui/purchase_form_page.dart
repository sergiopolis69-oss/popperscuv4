import 'package:flutter/material.dart';
import '../../purchases/data/purchase_models.dart';
import '../../purchases/logic/purchase_service.dart';

class PurchaseFormPage extends StatefulWidget {
  final PurchaseService service;
  const PurchaseFormPage({super.key, required this.service});

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  int? supplierId;
  PaymentMethod paymentMethod = PaymentMethod.cash;
  final _lines = <_Line>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva compra')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (supplierId == null || _lines.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Proveedor y al menos un artículo')),
            );
            return;
          }
          await widget.service.create(
            supplierId: supplierId!,
            paymentMethod: paymentMethod,
            date: DateTime.now(),
            lines: _lines.map((e) => (productId: e.productId!, qty: e.qty, unitCost: e.cost)).toList(),
          );
          if (mounted) Navigator.pop(context, true);
        },
        child: const Icon(Icons.check),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<PaymentMethod>(
            value: paymentMethod,
            items: PaymentMethod.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => paymentMethod = v ?? paymentMethod),
            decoration: const InputDecoration(label: Text('Forma de pago')),
          ),
          const SizedBox(height: 12),
          ..._lines.map((l) => ListTile(
                title: Text('Prod #${l.productId ?? '-'} • ${l.qty} x \$${l.cost}'),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _lines.remove(l))),
              )),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar renglón'),
            onPressed: () => setState(() => _lines.add(_Line())),
          ),
        ],
      ),
    );
  }
}

class _Line {
  int? productId;
  double qty = 1;
  double cost = 0;
}
