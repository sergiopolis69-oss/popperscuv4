import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale_item.dart';
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
  final _items = <SaleItem>[];
  String? _customerId;
  double _discount = 0;
  String _paymentMethod = 'Cash';

  late Future<List<Product>> _productsFuture;
  late Future<List<Customer>> _customersFuture;
  List<Product> _cachedProducts = const [];

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _productsFuture = ProductRepository().all().then((v){ _cachedProducts = v; return v; });
    _customersFuture = CustomerRepository().all();
  }

  double get _subtotal => _items.fold(0.0, (p, e) => p + e.subtotal);
  double get _costTotal => _items.fold(0.0, (p, e) => p + (e.costAtSale * e.quantity));
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  double get _profit => _total - _costTotal;

  String _nameFor(List<Product> list, String id) {
    final f = list.where((e) => e.id == id);
    return f.isEmpty ? id : f.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS / Ventas'),
        leading: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png'))),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TypeAheadField<Product>(
                suggestionsCallback: (pattern) async {
                  final all = _cachedProducts.isNotEmpty ? _cachedProducts : await ProductRepository().all();
                  _cachedProducts = all;
                  final q = pattern.toLowerCase();
                  return all.where((p){
                    final n = p.name.toLowerCase();
                    final s = (p.sku ?? '').toLowerCase();
                    return n.contains(q) || s.contains(q);
                  }).toList();
                },
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto por nombre o SKU',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  );
                },
                itemBuilder: (context, Product p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text('SKU: ${p.sku ?? '-'} — Stock: ${p.stock}  |  Venta: ${p.price.toStringAsFixed(2)}'),
                ),
                onSelected: (Product p) => _addItemDialog(p),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<List<Customer>>(
                      future: _customersFuture,
                      builder: (c, snap) {
                        final list = snap.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _customerId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Cliente: (no asignado)')),
                            ...list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                          ],
                          onChanged: (v) => setState(() => _customerId = v),
                          decoration: const InputDecoration(labelText: 'Cliente'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: 'Agregar cliente rápido', onPressed: _quickAddCustomer),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '0',
                      decoration: const InputDecoration(labelText: 'Descuento total (monto)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Efectivo')),
                        DropdownMenuItem(value: 'Card', child: Text('Tarjeta')),
                        DropdownMenuItem(value: 'Transfer', child: Text('Transferencia')),
                        DropdownMenuItem(value: 'Other', child: Text('Otro')),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                      decoration: const InputDecoration(labelText: 'Forma de pago'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    const Text('Carrito', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (int i = 0; i < _items.length; i++)
                      ListTile(
                        title: Text('x${_items[i].quantity} — ${_nameFor(_cachedProducts, _items[i].productId)}'),
                        subtitle: Text('Precio: ${_items[i].price.toStringAsFixed(2)}  | Costo: ${_items[i].costAtSale.toStringAsFixed(2)}  | Desc. línea: ${_items[i].lineDiscount.toStringAsFixed(2)}  | Subtotal: ${_items[i].subtotal.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editItemDialog(i)),
                            IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _items.removeAt(i))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Subtotal: ${_subtotal.toStringAsFixed(2)}'),
                  Text('Descuento total: ${_discount.toStringAsFixed(2)}'),
                  Text('Costo total: ${_costTotal.toStringAsFixed(2)}'),
                  Text('Total: ${_total.toStringAsFixed(2)}'),
                  Text('Utilidad: ${_profit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar venta'),
                  onPressed: _items.isEmpty ? null : _saveSale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuevo cliente rápido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () async {
            final repo = CustomerRepository();
            final nc = await repo.create(Customer(id: const Uuid().v4(), name: name.text.trim(), phone: phone.text.trim().isEmpty ? null : phone.text.trim()));
            setState(() { _customersFuture = CustomerRepository().all(); _customerId = nc.id; });
            if (mounted) Navigator.pop(c);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _addItemDialog(Product p) async {
    final qty = TextEditingController(text: '1');
    final disc = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Agregar: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad')),
            TextField(controller: disc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Descuento por línea (monto)')),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: (){
            final q = int.tryParse(qty.text) ?? 1;
            final d = double.tryParse(disc.text) ?? 0;
            setState((){
              _items.add(SaleItem(
                id: _uuid.v4(),
                saleId: 'temp',
                productId: p.id,
                quantity: q,
                price: p.price,
                costAtSale: p.cost,
                lineDiscount: d,
              ));
            });
            Navigator.pop(c);
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  Future<void> _editItemDialog(int index) async {
    final it = _items[index];
    final qty = TextEditingController(text: it.quantity.toString());
    final price = TextEditingController(text: it.price.toString());
    final cost  = TextEditingController(text: it.costAtSale.toString());
    final disc  = TextEditingController(text: it.lineDiscount.toString());
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Editar línea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad')),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio venta')),
            TextField(controller: cost,  keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo')),
            TextField(controller: disc,  keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Descuento por línea (monto)')),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: (){
            final q = int.tryParse(qty.text) ?? it.quantity;
            final p = double.tryParse(price.text) ?? it.price;
            final cst = double.tryParse(cost.text) ?? it.costAtSale;
            final d = double.tryParse(disc.text) ?? it.lineDiscount;
            setState((){
              _items[index] = SaleItem(
                id: it.id,
                saleId: it.saleId,
                productId: it.productId,
                quantity: q,
                price: p,
                costAtSale: cst,
                lineDiscount: d,
              );
            });
            Navigator.pop(c);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _saveSale() async {
    final repo = SaleRepository();
    await repo.createSale(customerId: _customerId, items: _items.toList(), discount: _discount, paymentMethod: _paymentMethod);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta guardada')));
      setState((){ _items.clear(); _customerId = null; _discount = 0; _paymentMethod = 'Cash'; });
    }
  }
}
