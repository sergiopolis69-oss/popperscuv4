import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../providers/providers.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        data: (items) {
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text('SKU: ${p.sku ?? '-'}  |  Stock: ${p.stock}  |  Compra: ${p.cost.toStringAsFixed(2)}  |  Venta: ${p.price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(edit: p)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                      await ref.read(productRepoProvider).delete(p.id);
                      ref.invalidate(productsProvider);
                    }),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _openForm({Product? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final skuCtrl = TextEditingController(text: edit?.sku ?? '');
    final costCtrl = TextEditingController(text: edit?.cost.toString());
    final priceCtrl = TextEditingController(text: edit?.price.toString());
    final stockCtrl = TextEditingController(text: edit?.stock.toString());

    final categories = await ref.read(productRepoProvider).categories();
    String? selectedCategory = edit?.category;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(edit == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Precio compra'), keyboardType: TextInputType.number),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Precio venta'), keyboardType: TextInputType.number),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String?>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('(sin categoría)')),
                  ...categories.map((e)=> DropdownMenuItem<String?>(value: e, child: Text(e))).toList(),
                  const DropdownMenuItem(value: '__new__', child: Text('+ Nueva categoría...')),
                ],
                onChanged: (v) async {
                  if (v == '__new__') {
                    final ctrl = TextEditingController();
                    final ok = await showDialog<String?>(
                      context: context,
                      builder: (ctx)=> AlertDialog(
                        title: const Text('Nueva categoría'),
                        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre de categoría')),
                        actions: [
                          TextButton(onPressed: ()=> Navigator.pop(ctx, null), child: const Text('Cancelar')),
                          ElevatedButton(onPressed: ()=> Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Agregar')),
                        ],
                      ),
                    );
                    if (ok != null && ok.isNotEmpty) {
                      selectedCategory = ok;
                      (c as Element).markNeedsBuild();
                    }
                  } else {
                    selectedCategory = v;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () async {
            final repo = ref.read(productRepoProvider);
            if (edit == null) {
              final p = Product(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                cost: double.tryParse(costCtrl.text) ?? 0,
                price: double.tryParse(priceCtrl.text) ?? 0,
                stock: int.tryParse(stockCtrl.text) ?? 0,
                category: selectedCategory == null || selectedCategory.trim().isEmpty ? null : selectedCategory,
              );
              await repo.create(p);
            } else {
              final p = edit.copyWith(
                name: nameCtrl.text.trim(),
                sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                cost: double.tryParse(costCtrl.text) ?? edit.cost,
                price: double.tryParse(priceCtrl.text) ?? edit.price,
                stock: int.tryParse(stockCtrl.text) ?? edit.stock,
                category: selectedCategory == null || selectedCategory.trim().isEmpty ? null : selectedCategory,
                updatedAt: DateTime.now(),
              );
              await repo.update(p);
            }
            if (mounted) Navigator.pop(c);
            ref.invalidate(productsProvider);
          }, child: const Text('Guardar'))
        ],
      ),
    );
  }
}
