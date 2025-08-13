import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _uuid = const Uuid();

  // Controles
  final _customerCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _shippingCtrl = TextEditingController(text: '0');

  // Datos precargados para typeahead
  List<Map<String, Object?>> _allProducts = [];
  List<Map<String, Object?>> _allCustomers = [];

  // Selección
  Map<String, Object?>? _selectedCustomer;

  // Carrito
  final List<Map<String, Object?>> _items = [];

  String _paymentMethod = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _warmUp();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _productCtrl.dispose();
    _discountCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
  }

  Future<void> _warmUp() async {
    try {
      final prods = await ProductRepository().all(); // List<Map<String,Object?>>
      final custs = await CustomerRepository().all(); // List<Map<String,Object?>>
      if (!mounted) return;
      setState(() {
        _allProducts = prods;
        _allCustomers = custs;
      });
    } catch (_) {
      // Ignorar por ahora; la UI seguirá vacía hasta que haya datos
    }
  }

  // Helpers de productos
  String _nameOf(Map<String, Object?> m) => (m['name'] as String?)?.trim() ?? '';
  String? _skuOf(Map<String, Object?> m) => (m['sku'] as String?)?.trim().isEmpty == true ? null : (m['sku'] as String?);
  double _priceOf(Map<String, Object?> m) => (m['price'] as num?)?.toDouble() ?? 0.0;
  double _costOf(Map<String, Object?> m) => (m['cost'] as num?)?.toDouble() ?? 0.0;
  String _idOf(Map<String, Object?> m) => (m['id'] as String?) ?? '';

  // Helpers de clientes
  String _custName(Map<String, Object?> m) => (m['name'] as String?)?.trim().isEmpty == true ? (m['id'] as String? ?? '') : (m['name'] as String);
  String _custId(Map<String, Object?> m) => (m['id'] as String?) ?? '';

  void _addProductToCart(Map<String, Object?> p) {
    final id = _idOf(p);
    final idx = _items.indexWhere((it) => it['productId'] == id);
    if (idx >= 0) {
      // Sumar cantidad si ya está
      final it = _items[idx];
      final q = (it['quantity'] as int) + 1;
      it['quantity'] = q;
      final price = (it['price'] as num).toDouble();
      final disc = (it['lineDiscount'] as num).toDouble();
      it['subtotal'] = (price * q - disc).clamp(0, double.infinity);
      setState(() {});
    } else {
      _items.add({
        'id': _uuid.v4(),
        'productId': id,
        'name': _nameOf(p),
        'price': _priceOf(p),
        'costAtSale': _costOf(p),
        'quantity': 1,
        'lineDiscount': 0.0,
        'subtotal': _priceOf(p) * 1 - 0.0,
      });
      setState(() {});
    }
  }

  double get _subtotal {
    double s = 0.0;
    for (final it in _items) {
      s += (it['subtotal'] as num?)?.toDouble() ?? 0.0;
    }
    return s;
  }

  double get _discount => double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get _shipping => double.tryParse(_shippingCtrl.text.replaceAll(',', '.')) ?? 0.0;

  double get _total {
    final t = _subtotal - _discount + _shipping;
    return t < 0 ? 0.0 : t;
  }

  double get _profit {
    // Utilidad = sum(precio*q - descLinea - cost*q)  - descuentoGlobal
    // (el envío NO afecta utilidad)
    double p = 0.0;
    for (final it in _items) {
      final q = (it['quantity'] as int?) ?? 0;
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final cost = (it['costAtSale'] as num?)?.toDouble() ?? 0.0;
      final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
      p += (price * q - lineDisc) - (cost * q);
    }
    p -= _discount;
    if (p.isNaN) return 0.0;
    return p < 0 ? 0.0 : p;
  }

  Future<void> _saveSale() async {
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto')));
      return;
    }
    try {
      final sale = {
        'id': _uuid.v4(),
        'customerId': _selectedCustomer == null ? null : _custId(_selectedCustomer!),
        'total': _total,
        'discount': _discount,
        'shipping': _shipping,
        'paymentMethod': _paymentMethod,
        'profit': _profit,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await SaleRepository().create(sale, _items); // Debes tener este método en tu repo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
      setState(() {
        _items.clear();
        _discountCtrl.text = '0';
        _shippingCtrl.text = '0';
        _productCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _showNewCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok == true) {
      final m = {
        'id': _uuid.v4(),
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      try {
        await CustomerRepository().upsertCustomer(m);
        // Actualiza cache y selección
        _allCustomers = await CustomerRepository().all();
        final found = _allCustomers.firstWhere(
          (c) => (c['id'] as String?) == m['id'],
          orElse: () => m,
        );
        setState(() {
          _selectedCustomer = found;
          _customerCtrl.text = _custName(found);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar cliente: $e')));
      }
    }
  }

  Iterable<Map<String, Object?>> _filterProducts(String q) {
    final qq = q.toLowerCase().trim();
    if (qq.isEmpty) return const <Map<String, Object?>>[];
    return _allProducts.where((p) {
      final name = _nameOf(p).toLowerCase();
      final sku = (_skuOf(p) ?? '').toLowerCase();
      return name.contains(qq) || sku.contains(qq);
    }).take(20);
  }

  Iterable<Map<String, Object?>> _filterCustomers(String q) {
    final qq = q.toLowerCase().trim();
    if (qq.isEmpty) return const <Map<String, Object?>>[];
    return _allCustomers.where((c) {
      final name = _custName(c).toLowerCase();
      final phone = (c['phone'] as String?)?.toLowerCase() ?? '';
      return name.contains(qq) || phone.contains(qq);
    }).take(20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('POS ventas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // === Cliente: typeahead + atajo para nuevo cliente ===
              Row(
                children: [
                  Expanded(
                    child: RawAutocomplete<Map<String, Object?>>(
                      textEditingController: _customerCtrl,
                      displayStringForOption: (o) => _custName(o),
                      optionsBuilder: (text) => _filterCustomers(text.text),
                      onSelected: (o) {
                        setState(() => _selectedCustomer = o);
                      },
                      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                        return TextField(
                          controller: ctrl,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            labelText: 'Cliente (buscar por nombre/teléfono)',
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                      },
                      optionsViewBuilder: (ctx, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 600),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (_, i) {
                                  final o = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    title: Text(_custName(o)),
                                    subtitle: Text((o['phone'] as String?) ?? ''),
                                    onTap: () => onSelected(o),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Nuevo cliente',
                    onPressed: _showNewCustomerDialog,
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // === Buscador de productos (typeahead) AL INICIO ===
              RawAutocomplete<Map<String, Object?>>(
                textEditingController: _productCtrl,
                displayStringForOption: (o) {
                  final sku = _skuOf(o);
                  final name = _nameOf(o);
                  return sku == null || sku.isEmpty ? name : '$name · SKU: $sku';
                },
                optionsBuilder: (text) => _filterProducts(text.text),
                onSelected: (o) {
                  _addProductToCart(o);
                  _productCtrl.clear();
                },
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto (nombre o SKU)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) {
                      final opts = _filterProducts(ctrl.text).toList();
                      if (opts.isNotEmpty) {
                        _addProductToCart(opts.first);
                        ctrl.clear();
                      }
                    },
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260, maxWidth: 700),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, i) {
                            final o = options.elementAt(i);
                            final sku = _skuOf(o) ?? '-';
                            final price = _priceOf(o).toStringAsFixed(2);
                            return ListTile(
                              dense: true,
                              title: Text(_nameOf(o)),
                              subtitle: Text('SKU: $sku   ·   \$${price}'),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () => onSelected(o),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // === Carrito ===
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Carrito'),
                      subtitle: Text('Toca + / - para ajustar cantidades'),
                    ),
                    const Divider(height: 1),
                    ..._items.asMap().entries.map((e) {
                      final i = e.key; final it = e.value;
                      final name = (it['name'] as String?) ?? '';
                      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                      final q = (it['quantity'] as int?) ?? 0;
                      final lineDisc = (it['lineDiscount'] as num?)?.toDouble() ?? 0.0;
                      final subtotal = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
                      return Column(
                        children: [
                          ListTile(
                            title: Text(name),
                            subtitle: Text('\$${price.toStringAsFixed(2)}  ·  Desc: \$${lineDisc.toStringAsFixed(2)}  ·  Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    final newQ = q > 1 ? q - 1 : 1;
                                    it['quantity'] = newQ;
                                    it['subtotal'] = (price * newQ - lineDisc).clamp(0, double.infinity);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$q'),
                                IconButton(
                                  onPressed: () {
                                    final newQ = q + 1;
                                    it['quantity'] = newQ;
                                    it['subtotal'] = (price * newQ - lineDisc).clamp(0, double.infinity);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() { _items.removeAt(i); });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Agrega productos usando el buscador de arriba.'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // === Totales ===
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Subtotal', style: Theme.of(context).textTheme.bodyLarge)),
                          Text('\$${_subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Descuento',
                                prefixText: '\$',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _shippingCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Envío (no afecta utilidad)',
                                prefixText: '\$',
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
                              decoration: const InputDecoration(labelText: 'Forma de pago'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Utilidad: \$${_profit.toStringAsFixed(2)}'),
                                  const SizedBox(height: 4),
                                  Text('Total: \$${_total.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),

      // Botón subir ~20px (queda sobre el contenido)
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        child: FilledButton.icon(
          onPressed: _saveSale,
          icon: const Icon(Icons.save),
          label: const Text('Guardar venta'),
        ),
      ),
    );
  }
}
