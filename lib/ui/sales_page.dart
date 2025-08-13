import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// Repos (ajusta si tus rutas cambian)
import 'package:popperscuv/repositories/product_repository.dart';
import 'package:popperscuv/repositories/customer_repository.dart';
import 'package:popperscuv/repositories/sale_repository.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _uuid = const Uuid();

  // Datos en memoria
  List<Map<String, Object?>> _products = [];
  List<Map<String, Object?>> _customers = [];
  final List<Map<String, Object?>> _items = [];

  // Buscadores (ARREGLADO: controller + focus para RawAutocomplete)
  final _productSearchController = TextEditingController();
  final _productSearchFocusNode = FocusNode();

  final _customerSearchController = TextEditingController();
  final _customerSearchFocusNode = FocusNode();

  // Venta
  String? _customerId;
  String _paymentMethod = 'Efectivo';
  double _discount = 0.0;
  double _shippingCost = 0.0;

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

  // Totales
  double get _subtotal {
    double s = 0.0;
    for (final it in _items) {
      s += (it['subtotal'] as num).toDouble();
    }
    return s;
  }

  double get _total {
    final t = (_subtotal - _discount + _shippingCost);
    return t < 0 ? 0 : t;
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _productSearchFocusNode.dispose();
    _customerSearchController.dispose();
    _customerSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      // Products
      final pr = ProductRepository() as dynamic;
      List rows;
      try {
        rows = await pr.all(); // si existe all()
      } catch (_) {
        try {
          rows = await pr.list(); // fallback
        } catch (_) {
          rows = await pr.allMaps(); // otro nombre posible
        }
      }
      // Asegura Map<String,Object?>
      _products = rows.map<Map<String, Object?>>((e) => Map<String, Object?>.from(e as Map)).toList();

      // Customers
      final cr = CustomerRepository() as dynamic;
      List crows;
      try {
        crows = await cr.all();
      } catch (_) {
        try {
          crows = await cr.list();
        } catch (_) {
          crows = await cr.allMaps();
        }
      }
      _customers = crows.map<Map<String, Object?>>((e) => Map<String, Object?>.from(e as Map)).toList();

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar catálogos: $e')),
      );
    }
  }

  void _addItemFromOption(Map<String, Object?> o) {
    final productId = (o['id'] ?? _uuid.v4()).toString();
    final name = (o['name'] ?? 'S/N').toString();
    final sku = (o['sku'] ?? '').toString();
    final price = (o['price'] as num? ?? 0).toDouble();
    final cost = (o['cost'] as num? ?? 0).toDouble();

    // Si ya está en carrito, suma cantidad
    final idx = _items.indexWhere((e) => e['productId'] == productId);
    if (idx >= 0) {
      setState(() {
        final it = _items[idx];
        final q = (it['quantity'] as int) + 1;
        it['quantity'] = q;
        it['subtotal'] = (price * q) - (it['lineDiscount'] as num).toDouble();
      });
      return;
    }

    final line = <String, Object?>{
      'id': _uuid.v4(),
      'productId': productId,
      'name': name,
      'sku': sku,
      'quantity': 1,
      'price': price,
      'costAtSale': cost,
      'lineDiscount': 0.0,
      'subtotal': (price * 1) - 0.0,
    };

    setState(() => _items.add(line));
  }

  Future<void> _saveSale() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    final sale = <String, Object?>{
      'id': _uuid.v4(),
      'customerId': _customerId,
      'total': _total.toDouble(),
      'discount': _discount.toDouble(),
      'paymentMethod': _paymentMethod,
      'shippingCost': _shippingCost.toDouble(), // si tu DB lo soporta
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      final repoDyn = SaleRepository() as dynamic;

      // Llamada dinámica para evitar errores de nombre de método (create / createSale / save)
      Future<void> _tryCall(Future<void> Function() f) async {
        try {
          await f();
        } catch (_) {
          rethrow;
        }
      }

      try {
        await _tryCall(() async => await repoDyn.create(sale, _items));
      } catch (_) {
        try {
          await _tryCall(() async => await repoDyn.createSale(sale, _items));
        } catch (_) {
          await _tryCall(() async => await repoDyn.save(sale, _items));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta guardada')),
      );
      setState(() {
        _items.clear();
        _discount = 0.0;
        _shippingCost = 0.0;
        _customerId = null;
        _customerSearchController.clear();
        _productSearchController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar venta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      appBar: AppBar(title: const Text('POS / Ventas')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + pad.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1) Buscador de productos arriba del todo ---
              RawAutocomplete<Map<String, Object?>>(
                textEditingController: _productSearchController,
                focusNode: _productSearchFocusNode,
                displayStringForOption: (o) =>
                    "${o['name'] ?? ''} (${(o['sku'] ?? '-')})",
                optionsBuilder: (TextEditingValue te) {
                  final q = te.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable.empty();
                  return _products.where((p) {
                    final n = (p['name'] ?? '').toString().toLowerCase();
                    final s = (p['sku'] ?? '').toString().toLowerCase();
                    return n.contains(q) || s.contains(q);
                  });
                },
                fieldViewBuilder: (context, textCtrl, focusNode, onSubmit) {
                  return TextField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto por nombre o SKU',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final list = options.toList();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final o = list[i];
                            final name = (o['name'] ?? '').toString();
                            final sku = (o['sku'] ?? '-').toString();
                            final price = (o['price'] as num? ?? 0).toDouble();
                            return ListTile(
                              title: Text(name),
                              subtitle: Text('SKU: $sku  •  ${_fmt.format(price)}'),
                              onTap: () {
                                onSelected(o);
                                _productSearchController.clear();
                                _addItemFromOption(o);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // --- 2) Buscador de clientes (typeahead similar) ---
              RawAutocomplete<Map<String, Object?>>(
                textEditingController: _customerSearchController,
                focusNode: _customerSearchFocusNode,
                displayStringForOption: (o) => (o['name'] ?? '').toString(),
                optionsBuilder: (TextEditingValue te) {
                  final q = te.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable.empty();
                  return _customers.where((c) {
                    final n = (c['name'] ?? '').toString().toLowerCase();
                    final p = (c['phone'] ?? '').toString().toLowerCase();
                    return n.contains(q) || p.contains(q);
                  });
                },
                fieldViewBuilder: (context, textCtrl, focusNode, onSubmit) {
                  return TextField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Cliente (buscar por nombre o teléfono)',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  );
                },
                onSelected: (o) {
                  _customerId = (o['id'] ?? '').toString();
                  _customerSearchController.text =
                      (o['name'] ?? '').toString();
                  setState(() {});
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final list = options.toList();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final o = list[i];
                            return ListTile(
                              title: Text((o['name'] ?? '').toString()),
                              subtitle: Text((o['phone'] ?? '').toString()),
                              onTap: () => onSelected(o),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // --- 3) Carrito ---
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: _items.isEmpty
                      ? const Center(child: Text('Sin productos'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            final name = (it['name'] ?? '').toString();
                            final sku = (it['sku'] ?? '').toString();
                            final q = (it['quantity'] as int);
                            final price = (it['price'] as num).toDouble();
                            final sub = (it['subtotal'] as num).toDouble();
                            return ListTile(
                              title: Text(name),
                              subtitle: Text('SKU: $sku • ${_fmt.format(price)}'),
                              trailing: SizedBox(
                                width: 170,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        if (q <= 1) return;
                                        setState(() {
                                          it['quantity'] = q - 1;
                                          it['subtotal'] = (price * (q - 1)) -
                                              (it['lineDiscount'] as num)
                                                  .toDouble();
                                        });
                                      },
                                    ),
                                    Text(q.toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        setState(() {
                                          it['quantity'] = q + 1;
                                          it['subtotal'] = (price * (q + 1)) -
                                              (it['lineDiscount'] as num)
                                                  .toDouble();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        setState(() => _items.removeAt(i));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              leading: Text(_fmt.format(sub)),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // --- 4) Descuento, envío, método de pago + Totales ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Descuento',
                        prefixText: r'$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                        setState(() => _discount = n);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Costo de envío',
                        prefixText: r'$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                        setState(() => _shippingCost = n);
                      },
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
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                        DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                      ],
                      onChanged: (v) => setState(() {
                        _paymentMethod = v ?? 'Efectivo';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: ${_fmt.format(_subtotal)}'),
                      Text('Envío: ${_fmt.format(_shippingCost)}'),
                      Text('Desc.: -${_fmt.format(_discount)}'),
                      Text(
                        'Total: ${_fmt.format(_total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 10),

              // Botón guardar (un poco más arriba)
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _saveSale,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar venta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
