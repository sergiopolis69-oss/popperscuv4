
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';
import '../services/db.dart';

final productRepoProvider = Provider<ProductRepository>((ref) => ProductRepository());
final customerRepoProvider = Provider<CustomerRepository>((ref) => CustomerRepository());
final saleRepoProvider = Provider<SaleRepository>((ref) => SaleRepository());

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});
  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _uuid = const Uuid();

  String? _customerId;
  String _customerName = '';

  final _customerCtrl = TextEditingController();
  final _productCtrl = TextEditingController();

  final _shippingCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');

  String _paymentMethod = 'Efectivo';

  final List<Map<String, dynamic>> _items = [];

  double _parseDouble(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _productCtrl.dispose();
    _shippingCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _allCustomers() async {
    final repo = ref.read(customerRepoProvider);
    try { return await repo.all(); } catch (_) { return <Map<String, Object?>>[]; }
  }

  Future<List<Map<String, Object?>>> _allProducts() async {
    final repo = ref.read(productRepoProvider);
    try { return await repo.all(); } catch (_) { return <Map<String, Object?>>[]; }
  }

  void _addProduct(Map<String, Object?> p) {
    final id = (p['id'] ?? '') as String;
    final name = (p['name'] ?? '') as String;
    final sku = (p['sku'] ?? '') as String?;
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final cost = (p['cost'] as num?)?.toDouble() ?? 0.0;
    final existingIndex = _items.indexWhere((it) => it['productId'] == id);
    setState(() {
      if (existingIndex >= 0) {
        _items[existingIndex]['quantity'] = (_items[existingIndex]['quantity'] as int) + 1;
      } else {
        _items.add({
          'id': _uuid.v4(),
          'productId': id,
          'name': name,
          'sku': sku,
          'price': price,
          'cost': cost,
          'quantity': 1,
          'lineDiscount': 0.0,
        });
      }
    });
  }

  double get _subtotal {
    double s = 0;
    for (final it in _items) {
      final q = (it['quantity'] as int);
      final price = (it['price'] as num).toDouble();
      final ld = (it['lineDiscount'] as num).toDouble();
      s += (price * q - ld).clamp(0, double.infinity);
    }
    return s;
  }

  double get _profit {
    double p = 0;
    for (final it in _items) {
      final q = (it['quantity'] as int);
      final price = (it['price'] as num).toDouble();
      final cost = (it['cost'] as num).toDouble();
      final ld = (it['lineDiscount'] as num).toDouble();
      final line = ((price - cost) * q) - ld;
      p += line;
    }
    return p.clamp(0, double.infinity);
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }
    final shipping = _parseDouble(_shippingCtrl);
    final discount = _parseDouble(_discountCtrl).clamp(0, double.infinity);
    final total = (_subtotal - discount + shipping).clamp(0, double.infinity);
    final profit = _profit; // no incluye envío

    final repo = ref.read(saleRepoProvider);

    try {
      await repo.createSale(
        customerId: _customerId,
        items: _items.map((it) => {
          'id': it['id'],
          'product_id': it['productId'],
          'quantity': it['quantity'],
          'price': it['price'],
          'cost_at_sale': it['cost'],
          'line_discount': it['lineDiscount'],
          'subtotal': (it['price'] as num * it['quantity'] as int) - (it['lineDiscount'] as num),
        }).toList(),
        total: total,
        discount: discount,
        profit: profit,
        shipping: shipping,
        paymentMethod: _paymentMethod,
      );
    } catch (_) {
      final db = await AppDatabase().database;
      final saleId = _uuid.v4();
      await db.transaction((txn) async {
        await txn.insert('sales', {
          'id': saleId,
          'customer_id': _customerId,
          'total': total,
          'discount': discount,
          'profit': profit,
          'payment_method': _paymentMethod,
          'shipping': shipping,
          'created_at': DateTime.now().toIso8601String(),
        });
        for (final it in _items) {
          await txn.insert('sale_items', {
            'id': it['id'],
            'sale_id': saleId,
            'product_id': it['productId'],
            'quantity': it['quantity'],
            'price': it['price'],
            'cost_at_sale': it['cost'],
            'line_discount': it['lineDiscount'],
            'subtotal': (it['price'] as num * it['quantity'] as int) - (it['lineDiscount'] as num),
          });
          await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [it['quantity'], it['productId']]);
          await txn.insert('inventory_movements', {
            'id': _uuid.v4(),
            'product_id': it['productId'],
            'delta': -(it['quantity'] as int),
            'reason': 'sale',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
    setState(() {
      _items.clear();
      _discountCtrl.text = '0';
      _shippingCtrl.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormatCurrency.mxn;
    return Scaffold(
      appBar: AppBar(title: const Text('POS / Ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RawAutocomplete<Map<String, Object?>>(
              textEditingController: _productCtrl,
              optionsBuilder: (TextEditingValue tev) async {
                final q = tev.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<Map<String, Object?>>.empty();
                final all = await _allProducts();
                return all.where((p) {
                  final name = (p['name'] ?? '').toString().toLowerCase();
                  final sku = (p['sku'] ?? '').toString().toLowerCase();
                  return name.contains(q) || sku.contains(q);
                });
              },
              displayStringForOption: (m) => (m['name'] ?? '').toString(),
              onSelected: (m) { _productCtrl.clear(); _addProduct(m); },
              fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto (nombre o SKU)',
                    prefixIcon: Icon(Icons.search),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 240,
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final o = options.elementAt(i);
                          final name = (o['name'] ?? '-') as String;
                          final sku = (o['sku'] ?? '') as String?;
                          final price = (o['price'] as num?)?.toDouble() ?? 0;
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('SKU: ${sku ?? '-'}  |  ${currency(price)}'),
                            onTap: () => onSelected(o),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            RawAutocomplete<Map<String, Object?>>(
              textEditingController: _customerCtrl,
              optionsBuilder: (TextEditingValue tev) async {
                final q = tev.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<Map<String, Object?>>.empty();
                final all = await _allCustomers();
                return all.where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  final phone = (c['phone'] ?? '').toString().toLowerCase();
                  return name.contains(q) || phone.contains(q);
                });
              },
              displayStringForOption: (m) => (m['name'] ?? '').toString(),
              onSelected: (m) {
                setState(() {
                  _customerId = (m['id'] ?? '') as String;
                  _customerName = (m['name'] ?? '') as String;
                });
              },
              fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    labelText: _customerName.isEmpty ? 'Buscar cliente (nombre o teléfono)' : 'Cliente: $_customerName',
                    prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      tooltip: 'Nuevo cliente rápido',
                      onPressed: _quickAddCustomer,
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final o = options.elementAt(i);
                          final name = (o['name'] ?? '-') as String;
                          final phone = (o['phone'] ?? '') as String?;
                          return ListTile(
                            title: Text(name),
                            subtitle: Text(phone ?? ''),
                            onTap: () => onSelected(o),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shippingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo de envío (no afecta utilidad)',
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Descuento global',
                      prefixIcon: Icon(Icons.discount),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: _items.isEmpty
                    ? const Center(child: Text('Carrito vacío'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          final name = (it['name'] ?? '-') as String;
                          final sku = (it['sku'] ?? '') as String?;
                          final price = (it['price'] as num).toDouble();
                          final cost = (it['cost'] as num).toDouble();
                          final q = (it['quantity'] as int);
                          final ld = (it['lineDiscount'] as num).toDouble();
                          final lineSubtotal = (price * q - ld).clamp(0, double.infinity);
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('SKU: ${sku ?? '-'}  ·  ${currency(price)}  ·  Costo ${currency(cost)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => setState(() {
                                        if (it['quantity'] > 1) it['quantity'] = q - 1;
                                      }),
                                    ),
                                    Text(q.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => setState(() {
                                        it['quantity'] = q + 1;
                                      }),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => setState(() {
                                        _items.removeAt(i);
                                      }),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 140,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: 'Desc. línea',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => setState(() {
                                      it['lineDiscount'] = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                                    }),
                                  ),
                                ),
                                Text('= ${currency(lineSubtotal)}'),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _totals(currency),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.save_alt),
          label: const Text('Guardar venta'),
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _totals(String Function(num) currency) {
    final shipping = _parseDouble(_shippingCtrl);
    final discount = _parseDouble(_discountCtrl);
    final total = (_subtotal - discount + shipping).clamp(0, double.infinity);
    final pct = _subtotal == 0 ? 0 : (_profit / _subtotal * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subtotal: ' + currency(_subtotal)),
        Text('Descuento: -' + currency(discount)),
        Text('Envío: +' + currency(shipping)),
        const Divider(),
        Text('Total: ' + currency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text('Utilidad: ' + currency(_profit) + '  (' + pct.toStringAsFixed(1) + '%)'),
      ],
    );
  }

  Future<void> _quickAddCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(customerRepoProvider);
    final id = _uuid.v4();
    try {
      await repo.upsertCustomer({
        'id': id,
        'name': nameCtrl.text.trim(),
        'phone': nameCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': null,
      });
    } catch (_) {
      final db = await AppDatabase().database;
      await db.insert('customers', {
        'id': id,
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': null,
      });
    }
    if (!mounted) return;
    setState(() {
      _customerId = id;
      _customerName = nameCtrl.text.trim();
      _customerCtrl.text = _customerName;
    });
  }
}

typedef CurrencyFn = String Function(num);
class NumberFormatCurrency {
  static String Function(num) get mxn => (num v) {
    return '\$' + v.toStringAsFixed(2);
  };
}
