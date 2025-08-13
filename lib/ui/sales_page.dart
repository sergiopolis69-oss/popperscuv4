
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  String? _customerId;
  String _paymentMethod = 'Efectivo';
  num _discount = 0;
  num _shipping = 0;

  final List<Map<String, dynamic>> _items = []; // each: id, productId, price, quantity, lineDiscount, subtotal

  double get _subtotal {
    double sum = 0;
    for (final it in _items) {
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0.0;
      final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
      sum += (price * qty - lineDisc).clamp(0.0, double.infinity);
    }
    return sum;
  }

  double get _total => (_subtotal - (_discount as num).toDouble()).clamp(0.0, double.infinity) + (_shipping as num).toDouble();

  double get _profit {
    // si quieres costo, tendrías que tener cost_at_sale; aquí asumimos que ya viene en cada item si lo usas
    double costSum = 0;
    for (final it in _items) {
      final cost = (it['cost_at_sale'] as num?)?.toDouble() ?? (it['cost'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0.0;
      costSum += cost * qty;
    }
    return (_subtotal - costSum).clamp(0.0, double.infinity);
  }

  Future<void> _saveSale() async {
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }

    // Normaliza items
    final itemsToSave = _items.map((it) {
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0.0;
      final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (price * qty - lineDisc).clamp(0.0, double.infinity) as double;
      return {
        'id': it['id'],
        'product_id': it['productId'] ?? it['product_id'],
        'price': price,
        'quantity': qty.toInt(),
        'lineDiscount': lineDisc,
        'subtotal': subtotal,
        'cost_at_sale': (it['cost_at_sale'] as num?)?.toDouble() ?? (it['cost'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    await SaleRepository().createSale(
      customerId: _customerId,
      items: itemsToSave,
      total: _total.toDouble(),
      discount: (_discount as num).toDouble(),
      profit: _profit.toDouble(),
      shipping: (_shipping as num).toDouble(),
      paymentMethod: _paymentMethod,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
    setState(() {
      _items.clear();
      _discount = 0;
      _shipping = 0;
      _paymentMethod = 'Efectivo';
      _customerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS Ventas')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Campos simplificados para ejemplo; integra aquí tus typeaheads
          Text('Cliente (ID opcional):'),
          TextField(
            decoration: const InputDecoration(hintText: 'customerId'),
            onChanged: (v) => setState(() => _customerId = v.isEmpty ? null : v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Descuento'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _discount = num.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Envío'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _shipping = num.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 'Efectivo'),
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saveSale,
                child: const Text('Guardar venta'),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('Carrito'),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            final it = e.value;
            final name = (it['name'] ?? 'Producto') as String;
            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
            final price = (it['price'] as num?)?.toDouble() ?? 0.0;
            return ListTile(
              title: Text(name),
              subtitle: Text('x$qty  ·  $price'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => setState(() { if (_items[i]['quantity'] > 1) _items[i]['quantity']--; }), icon: const Icon(Icons.remove)),
                  IconButton(onPressed: () => setState(() { _items[i]['quantity']++; }), icon: const Icon(Icons.add)),
                  IconButton(onPressed: () => setState(() { _items.removeAt(i); }), icon: const Icon(Icons.delete_outline)),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 24),
          Text('Subtotal: ${_subtotal.toStringAsFixed(2)}'),
          Text('Descuento: ${(_discount as num).toDouble().toStringAsFixed(2)}'),
          Text('Envío: ${(_shipping as num).toDouble().toStringAsFixed(2)}'),
          Text('Total: ${_total.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
