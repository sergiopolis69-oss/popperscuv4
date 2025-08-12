
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../repositories/sale_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';

class _CartLine {
  String productId;
  String name;
  String? sku;
  int quantity;
  double price;
  double costAtSale;
  double lineDiscount;
  _CartLine({
    required this.productId,
    required this.name,
    this.sku,
    required this.quantity,
    required this.price,
    required this.costAtSale,
    this.lineDiscount = 0,
  });
  double get subtotal => ((price * quantity) - lineDiscount).clamp(0, double.infinity);
}

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});
  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _uuid = const Uuid();
  String? _customerId;
  String _customerLabel = '';
  final _shippingCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');

  final List<_CartLine> _items = [];

  @override
  void dispose() {
    _shippingCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productRepo = ProductRepository();
    final customerRepo = CustomerRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('POS Ventas')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 🔎 Buscador de CLIENTE
            FutureBuilder<List<dynamic>>(
              future: customerRepo.all(),
              builder: (context, snapshot) {
                final customers = snapshot.data ?? <dynamic>[];
                return RawAutocomplete<dynamic>(
                  optionsBuilder: (TextEditingValue te) {
                    final q = te.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable.empty();
                    return customers.where((c) =>
                      (c.name?.toString().toLowerCase().contains(q) ?? false) ||
                      (c.phone?.toString().toLowerCase().contains(q) ?? false));
                  },
                  displayStringForOption: (opt) => opt.name as String,
                  onSelected: (opt) {
                    setState(() {
                      _customerId = opt.id as String;
                      _customerLabel = opt.name as String;
                    });
                  },
                  fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
                    ctrl.text = _customerLabel;
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Cliente (buscar por nombre/teléfono)',
                        prefixIcon: Icon(Icons.person_search),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, opts) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: opts.length,
                            itemBuilder: (c, i) {
                              final o = opts.elementAt(i);
                              return ListTile(
                                title: Text(o.name as String),
                                subtitle: Text(o.phone?.toString() ?? ''),
                                onTap: () => onSelected(o),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),

            // 🔎 Buscador de PRODUCTOS
            FutureBuilder<List<dynamic>>(
              future: productRepo.all(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? <dynamic>[];
                return RawAutocomplete<dynamic>(
                  optionsBuilder: (TextEditingValue te) {
                    final q = te.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable.empty();
                    return products.where((p) =>
                      (p.name?.toString().toLowerCase().contains(q) ?? false) ||
                      (p.sku?.toString().toLowerCase().contains(q) ?? false));
                  },
                  displayStringForOption: (opt) => opt.name as String,
                  onSelected: (opt) {
                    setState(() {
                      _items.add(_CartLine(
                        productId: opt.id as String,
                        name: opt.name as String,
                        sku: opt.sku as String?,
                        quantity: 1,
                        price: (opt.price as num).toDouble(),
                        costAtSale: (opt.cost as num).toDouble(),
                      ));
                    });
                  },
                  fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Agregar producto (nombre o SKU)',
                        prefixIcon: Icon(Icons.search),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, opts) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: opts.length,
                            itemBuilder: (c, i) {
                              final o = opts.elementAt(i);
                              return ListTile(
                                title: Text(o.name as String),
                                subtitle: Text('SKU: ${o.sku ?? '-'}  |  \$${(o.price as num).toDouble().toStringAsFixed(2)}'),
                                onTap: () => onSelected(o),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),

            // Lista de items
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (c, i) {
                  final it = _items[i];
                  return ListTile(
                    title: Text('${it.name}  x${it.quantity}  \$${it.price.toStringAsFixed(2)}'),
                    subtitle: Text('Desc: ${it.lineDiscount.toStringAsFixed(2)} | Subtotal: ${it.subtotal.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove), onPressed: () {
                          setState(() { if (it.quantity > 1) it.quantity--; });
                        }),
                        IconButton(icon: const Icon(Icons.add), onPressed: () {
                          setState(() { it.quantity++; });
                        }),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () {
                          setState(() { _items.removeAt(i); });
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Totales + campos
            Builder(
              builder: (context) {
                final discount = double.tryParse(_discountCtrl.text) ?? 0;
                final shipping = double.tryParse(_shippingCtrl.text) ?? 0;
                double subtotal = 0;
                for (final it in _items) {
                  subtotal += (it.price * it.quantity) - it.lineDiscount;
                }
                if (subtotal < 0) subtotal = 0;
                final total = (subtotal - discount + shipping);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: _discountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Descuento'),
                          onChanged: (_) => setState(() {}),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: _shippingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Costo de envío (no afecta utilidad)'),
                          onChanged: (_) => setState(() {}),
                        )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Total: \$${total < 0 ? 0 : total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar venta'),
                        onPressed: _items.isEmpty ? null : () async {
                          final repo = SaleRepository();
                          await repo.createSale(
                            customerId: _customerId,
                            paymentMethod: 'cash',
                            discount: double.tryParse(_discountCtrl.text) ?? 0,
                            shippingCost: double.tryParse(_shippingCtrl.text) ?? 0,
                            items: _items.map((e) => {
                              'productId': e.productId,
                              'quantity': e.quantity,
                              'price': e.price,
                              'costAtSale': e.costAtSale,
                              'lineDiscount': e.lineDiscount,
                            }).toList(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
                            setState(() {
                              _items.clear();
                              _discountCtrl.text = '0';
                              _shippingCtrl.text = '0';
                              _customerId = null;
                              _customerLabel = '';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
