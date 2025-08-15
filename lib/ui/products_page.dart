import 'package:flutter/material.dart';
import 'package:popperscuv/repositories/product_repository.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchCtrl = TextEditingController();
  String _searchText = '';
  String _selectedCategory = ''; // '' = Todas
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchCtrl.addListener(() {
      setState(() => _searchText = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await ProductRepository().categoriesDistinct();
      setState(() {
        _categories = list;
      });
    } catch (_) {
      // opcional: mostrar error
    }
  }

  Future<List<Map<String, Object?>>> _load() {
    return ProductRepository().listFiltered(
      q: _searchText.isEmpty ? null : _searchText,
      category: _selectedCategory.isEmpty ? null : _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar (nombre o SKU)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todas'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedCategory = v ?? '';
                      }),
                      hint: const Text('Categoría'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];

                if (rows.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final name = (r['name'] ?? '').toString();
                    final sku = (r['sku'] ?? '').toString();
                    final category = (r['category'] ?? '').toString();
                    final price = (r['price'] as num?)?.toDouble() ?? 0.0;
                    final cost = (r['cost'] as num?)?.toDouble() ?? 0.0;
                    final stock = (r['stock'] is int)
                        ? (r['stock'] as int)
                        : int.tryParse(r['stock']?.toString() ?? '') ?? 0;

                    return ListTile(
                      title: Text(
                        name.isEmpty ? '(Sin nombre)' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (sku.isNotEmpty) 'SKU: $sku',
                          if (category.isNotEmpty) 'Cat: $category',
                          'Costo: \$${cost.toStringAsFixed(2)}',
                          'Precio: \$${price.toStringAsFixed(2)}',
                        ].join('  ·  '),
                      ),
                      trailing: Text(
                        'Stock: $stock',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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