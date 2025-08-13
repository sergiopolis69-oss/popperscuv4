
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_repository.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');

  String? _selectedCategory;
  Map<String, Object?>? _edit;

  Future<void> _loadForEdit(Map<String, Object?> row) async {
    _edit = row;
    _nameCtrl.text = (row['name'] ?? '') as String;
    _skuCtrl.text = (row['sku'] ?? '') as String;
    _costCtrl.text = ((row['cost'] as num?)?.toString() ?? '0');
    _priceCtrl.text = ((row['price'] as num?)?.toString() ?? '0');
    _stockCtrl.text = ((row['stock'] as num?)?.toString() ?? '0');
    _selectedCategory = (row['category'] as String?);
    setState(() {});
  }

  Future<void> _save() async {
    final repo = ProductRepository();
    await repo.upsertProductNamed(
      id: _edit?['id'] as String?,
      name: _nameCtrl.text.trim(),
      sku: (() {
        final s = _skuCtrl.text.trim();
        return s.isEmpty ? null : s;
      })(),
      category: (() {
        final c = _selectedCategory?.trim() ?? '';
        return c.isEmpty ? null : c;
      })(),
      cost: double.tryParse(_costCtrl.text) ?? 0.0,
      price: double.tryParse(_priceCtrl.text) ?? 0.0,
      stock: int.tryParse(_stockCtrl.text) ?? 0,
    );
    if (!mounted) return;
    Navigator.pop(context);
    setState(() {});
  }

  Future<void> _delete(String id) async {
    await ProductRepository().deleteById(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: FutureBuilder<List<Map<String, Object?>>>>(
        future: ProductRepository().all(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = rows[i];
              return ListTile(
                title: Text((p['name'] ?? '') as String),
                subtitle: Text('SKU: ${(p['sku'] ?? '-') as String}  |  Stock: ${(p['stock'] ?? 0)}  |  Compra: ${(p['cost'] ?? 0)}  |  Venta: ${(p['price'] ?? 0)}'),
                onTap: () async {
                  await _loadForEdit(p);
                  // open editor
                  if (!mounted) return;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _EditorSheet(
                      nameCtrl: _nameCtrl,
                      skuCtrl: _skuCtrl,
                      costCtrl: _costCtrl,
                      priceCtrl: _priceCtrl,
                      stockCtrl: _stockCtrl,
                      selectedCategory: _selectedCategory,
                      onCategoryChanged: (v) => setState(() => _selectedCategory = v),
                      onSave: _save,
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete((p['id'] ?? '') as String),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _edit = null;
          _nameCtrl.clear();
          _skuCtrl.clear();
          _costCtrl.text = '0';
          _priceCtrl.text = '0';
          _stockCtrl.text = '0';
          _selectedCategory = null;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EditorSheet(
              nameCtrl: _nameCtrl,
              skuCtrl: _skuCtrl,
              costCtrl: _costCtrl,
              priceCtrl: _priceCtrl,
              stockCtrl: _stockCtrl,
              selectedCategory: _selectedCategory,
              onCategoryChanged: (v) => setState(() => _selectedCategory = v),
              onSave: _save,
            ),
          );
        },
        label: const Text('Agregar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _EditorSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController costCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onSave;

  const _EditorSheet({
    required this.nameCtrl,
    required this.skuCtrl,
    required this.costCtrl,
    required this.priceCtrl,
    required this.stockCtrl,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
            TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Costo'), keyboardType: TextInputType.number),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
            TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: ProductRepository().categoriesDistinct(),
              builder: (context, snap) {
                final list = snap.data ?? const <String>[];
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedCategory != null && (selectedCategory?.isNotEmpty ?? false) && list.contains(selectedCategory) ? selectedCategory : null,
                        items: list.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: onCategoryChanged,
                        decoration: const InputDecoration(labelText: 'Categoría (existente)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: selectedCategory ?? '',
                        onChanged: onCategoryChanged,
                        decoration: const InputDecoration(labelText: 'Nueva categoría'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: onSave, child: const Text('Guardar')),
            ),
          ],
        ),
      ),
    );
  }
}
