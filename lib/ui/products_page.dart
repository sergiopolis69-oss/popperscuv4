import 'package:flutter/material.dart';
import 'package:popperscuv/repositories/product_repository.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductRepository();
  final _qCtrl = TextEditingController();

  String? _selectedCategory; // null = todas
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await _repo.categoriesDistinct();
    setState(() {
      _categories = list;
    });
  }

  Future<List<Map<String, Object?>>> _loadProducts() {
    return _repo.listFiltered(
      category: _selectedCategory,
      q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
    );
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _openProductDialog({Map<String, Object?>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final skuCtrl = TextEditingController(text: existing?['sku']?.toString() ?? '');
    final catCtrl = TextEditingController(text: existing?['category']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? '').toString());
    final costCtrl = TextEditingController(text: (existing?['cost'] ?? '').toString());
    final stockCtrl = TextEditingController(text: (existing?['stock'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Categoría')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Costo'), keyboardType: TextInputType.number),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved == true) {
      final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final stock = int.tryParse(stockCtrl.text) ?? 0;

      await _repo.upsertProduct({
        'id': existing?['id']?.toString(),
        'name': nameCtrl.text.trim().isEmpty ? skuCtrl.text.trim() : nameCtrl.text.trim(),
        'sku': skuCtrl.text.trim(),
        'category': catCtrl.text.trim(),
        'price': price,
        'cost': cost,
        'stock': stock,
      });

      if (mounted) {
        // Refrescamos categorías por si agregaron una nueva
        _loadCategories();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto guardado')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCats = ['(Todas)', ..._categories];

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                // Categoría
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCategory == null ? '(Todas)' : _selectedCategory,
                    items: allCats
                        .map((c) => DropdownMenuItem<String>(
                              value: c == '(Todas)' ? '(Todas)' : c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedCategory = (v == null || v == '(Todas)') ? null : v;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Buscador
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _qCtrl,
                    onSubmitted: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre o SKU',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Buscar',
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.search),
                          ),
                          IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _qCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _loadProducts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <Map<String, Object?>>[];
                if (list.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = list[i];
                    final name = (it['name'] ?? '').toString();
                    final sku = (it['sku'] ?? '').toString();
                    final category = (it['category'] ?? '').toString();
                    final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                    final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
                    final stock = (it['stock'] as num?)?.toInt() ?? 0;

                    return ListTile(
                      title: Text(name.isEmpty ? '(Sin nombre)' : name),
                      subtitle: Text([
                        if (sku.isNotEmpty) 'SKU: $sku',
                        if (category.isNotEmpty) 'Cat: $category',
                        'Costo: \$${cost.toStringAsFixed(2)}',
                      ].join('  •  ')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Stock: $stock'),
                        ],
                      ),
                      onLongPress: () => _openProductDialog(existing: it),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}