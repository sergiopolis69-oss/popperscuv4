import 'package:flutter/material.dart';
import '../repositories/product_repository.dart';
import '../utils/csv_io.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductRepository();
  String _query = '';
  String _category = 'Todas';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load() {
    return _repo.listFiltered(q: _query, category: _category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Importar (upsert)',
            onPressed: () async {
              final res = await CsvIO.importProductsUpsertFromCsv();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('CSV upsert → ins:${res['inserted']} act:${res['updated']} omit:${res['skipped']} err:${res['errors']}')),
              );
              setState(() {});
            },
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Importar ajustes (qty)',
            onPressed: () async {
              final res = await CsvIO.importInventoryAddsFromCsv();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ajustes → cambios:${res['changed']} faltantes:${res['missing']} err:${res['errors']}')),
              );
              setState(() {});
            },
            icon: const Icon(Icons.playlist_add),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: () async {
              final path = await CsvIO.exportTable('products');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exportado: $path')),
              );
            },
            icon: const Icon(Icons.download),
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
                    controller: _searchCtl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por nombre o SKU',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: (_query.isEmpty)
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FutureBuilder<List<String>>(
                  future: _repo.categoriesDistinct(),
                  builder: (context, snap) {
                    final cats = ['Todas', ...(snap.data ?? const [])];
                    return DropdownButton<String>(
                      value: cats.contains(_category) ? _category : 'Todas',
                      items: cats
                          .map<DropdownMenuItem<String>>(
                            (c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? 'Todas'),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _load(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data ?? const [];
                if (data.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = data[i];
                    final name = (p['name']?.toString().isNotEmpty ?? false)
                        ? p['name'].toString()
                        : p['sku']?.toString() ?? '—';
                    final stock = (p['stock'] as num?)?.toInt() ?? 0;
                    final price = (p['price'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text('SKU: ${p['sku'] ?? '-'}  •  Stock: $stock  •  \$${price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar producto'),
                              content: Text('¿Eliminar "$name"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await ProductRepository().deleteById(p['id'].toString());
                            if (mounted) setState(() {});
                          }
                        },
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