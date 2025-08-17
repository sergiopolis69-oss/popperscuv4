import 'package:flutter/material.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';
import '../utils/misc.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _productRepo = ProductRepository();
  final _customerRepo = CustomerRepository();
  final _saleRepo = SaleRepository();

  final _searchProductCtl = TextEditingController();
  final _discountCtl = TextEditingController(text: '0');
  final _shippingCtl = TextEditingController(text: '0');

  Map<String, Object?>? _customer; // {'id':..., 'name':..., 'phone':...}
  final List<Map<String, Object?>> _items = []; // cart

  String _payment = 'Efectivo';

  @override
  void dispose() {
    _searchProductCtl.dispose();
    _discountCtl.dispose();
    _shippingCtl.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _NewCustomerDialog(),
    );
    if (data != null) {
      await _customerRepo.upsertCustomer({
        'id'   : data['phone'], // usar teléfono como identificador
        'name' : data['name'],
        'phone': data['phone'],
      });
      final c = await _customerRepo.byId(data['phone']!);
      setState(() => _customer = c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente guardado')));
    }
  }

  Future<void> _searchAndAddProduct(String q) async {
    final list = await _productRepo.listFiltered(q: q);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró producto')));
      return;
    }
    Map<String, Object?>? selected;
    if (list.length == 1) {
      selected = list.first;
    } else {
      selected = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Selecciona un producto'),
          children: list.map((p) {
            final name = (p['name']?.toString().isNotEmpty ?? false) ? p['name'].toString() : p['sku']?.toString() ?? '—';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text('$name  •  SKU: ${p['sku']}'),
            );
          }).toList(),
        ),
      );
    }
    if (selected == null) return;

    // Agregar al carrito (si existe, suma qty)
    final pid = selected['id']!.toString();
    final idx = _items.indexWhere((e) => e['productId'] == pid);
    if (idx >= 0) {
      setState(() => _items[idx]['quantity'] = (toInt(_items[idx]['quantity']) + 1));
    } else {
      setState(() {
        _items.add({
          'id'         : genId(),
          'productId'  : pid,
          'sku'        : selected!['sku'],
          'name'       : selected['name'],
          'price'      : toDouble(selected['price']),
          'cost'       : toDouble(selected['cost']),
          'quantity'   : 1,
          'lineDiscount': 0.0,
        });
      });
    }
  }

  double get _subtotal {
    return _items.fold<double>(0, (acc, it) {
      final price = toDouble(it['price']);
      final qty   = toInt(it['quantity'], fallback: 1);
      final ld    = toDouble(it['lineDiscount']);
      return acc + (price * qty - ld);
    });
  }

  double get _discount => toDouble(_discountCtl.text);
  double get _shipping => toDouble(_shippingCtl.text);
  double get _total => _subtotal - _discount + _shipping;

  Future<void> _saveSale() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }
    await _saleRepo.create({
      'customerId'   : _customer?['id'],
      'discount'     : _discount,
      'shippingCost' : _shipping,
      'total'        : _total,
      'paymentMethod': _payment,
    }, _items);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
    setState(() {
      _items.clear();
      _discountCtl.text = '0';
      _shippingCtl.text = '0';
      _searchProductCtl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS / Ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Cliente + agregar
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Map<String, Object?>>>>(
                    future: CustomerRepository().all(),
                    builder: (context, snap) {
                      final customers = snap.data ?? const [];
                      final label = _customer == null
                          ? 'Cliente (opcional)'
                          : (_customer!['name']?.toString().isNotEmpty ?? false)
                              ? _customer!['name']!.toString()
                              : (_customer!['phone']?.toString() ?? _customer!['id']?.toString() ?? 'Cliente');
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        value: _customer?['id']?.toString(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Sin cliente —')),
                          ...customers.map((c) {
                            final txt = (c['name']?.toString().isNotEmpty ?? false) ? c['name'].toString() : (c['phone']?.toString() ?? c['id']?.toString() ?? '');
                            return DropdownMenuItem(value: c['id'].toString(), child: Text(txt));
                          }),
                        ].whereType<DropdownMenuItem<String>>().toList(),
                        onChanged: (v) async {
                          if (v == null) { setState(() => _customer = null); return; }
                          final c = await _customerRepo.byId(v);
                          setState(() => _customer = c);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Agregar cliente'),
                  onPressed: _addCustomer,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Buscar producto
            TextField(
              controller: _searchProductCtl,
              decoration: InputDecoration(
                labelText: 'Buscar producto (nombre o SKU) y Enter',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => _searchAndAddProduct(_searchProductCtl.text.trim()),
                ),
              ),
              onSubmitted: (v) => _searchAndAddProduct(v.trim()),
            ),
            const SizedBox(height: 8),

            // Lista del carrito
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final name = (it['name']?.toString().isNotEmpty ?? false) ? it['name'].toString() : it['sku']?.toString() ?? '—';
                    final price = toDouble(it['price']);
                    final qty   = toInt(it['quantity'], fallback: 1);
                    final ld    = toDouble(it['lineDiscount']);
                    final line  = (price * qty - ld);
                    return ListTile(
                      title: Text(name),
                      subtitle: Text('SKU: ${it['sku'] ?? '-'}  •  \$${price.toStringAsFixed(2)}  •  Subtotal: \$${line.toStringAsFixed(2)}'),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '–1',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() { if (toInt(it['quantity'], fallback: 1) > 1) it['quantity'] = toInt(it['quantity']) - 1; }),
                          ),
                          Text(qty.toString()),
                          IconButton(
                            tooltip: '+1',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() { it['quantity'] = toInt(it['quantity']) + 1; }),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() { _items.removeAt(i); }),
                          ),
                        ],
                      ),
                      onTap: () async {
                        // Editar descuento de línea rápido
                        final ctl = TextEditingController(text: ld.toStringAsFixed(2));
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Descuento de línea'),
                            content: TextField(
                              controller: ctl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(prefixText: '\$'),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          setState(() => it['lineDiscount'] = toDouble(ctl.text));
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // Totales
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discountCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Descuento', prefixText: '\$'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _shippingCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Envío', prefixText: '\$'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _payment,
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                  ],
                  onChanged: (v) => setState(() => _payment = v ?? 'Efectivo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Subtotal: \$${_subtotal.toStringAsFixed(2)}   '),
                Text('Total: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar venta'),
                onPressed: _saveSale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();
  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo cliente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono / ID')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop<Map<String, String>>(context, {
            'name': _name.text.trim(),
            'phone': _phone.text.trim(),
          }),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}