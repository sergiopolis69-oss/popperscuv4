
import 'package:flutter/material.dart';
import '../repositories/product_repository.dart';
import '../services/db.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _query = '';

  String _asString(Object? v) => v?.toString() ?? '';
  String _lower(Object? v) => _asString(v).toLowerCase();
  String _idOf(Object o) { try { return (o as dynamic).id as String; } catch (_) { try { return (o as dynamic)['id'] as String; } catch (_) { return ''; } } }
  String _nameOf(Object o) { try { return (o as dynamic).name as String; } catch (_) { try { return (o as dynamic)['name'] as String; } catch (_) { return ''; } } }
  String? _skuOf(Object o) { try { return (o as dynamic).sku as String?; } catch (_) { try { return (o as dynamic)['sku'] as String?; } catch (_) { return null; } } }
  String? _catOf(Object o) { try { return (o as dynamic).category as String?; } catch (_) { try { return (o as dynamic)['category'] as String?; } catch (_) { return null; } } }
  int _stockOf(Object o) { try { return (o as dynamic).stock as int; } catch (_) { try { return (o as dynamic)['stock'] as int; } catch (_) { return 0; } } }
  double _priceOf(Object o) { try { return ((o as dynamic).price as num).toDouble(); } catch (_) { try { return ((o as dynamic)['price'] as num).toDouble(); } catch (_) { return 0; } } }
  double _costOf(Object o) { try { return ((o as dynamic).cost as num).toDouble(); } catch (_) { try { return ((o as dynamic)['cost'] as num).toDouble(); } catch (_) { return 0; } } }

  Future<List<Object>> _loadProducts() async {
    final list = await ProductRepository().all();
    final objs = List<Object>.from(list);
    if (_query.trim().isEmpty) return objs;
    final q = _query.trim().toLowerCase();
    return objs.where((p) =>
      _lower(_nameOf(p)).contains(q) ||
      _lower(_skuOf(p)).contains(q) ||
      _lower(_catOf(p)).contains(q)
    ).toList();
  }

  Future<void> _openForm({Object? editing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ProductForm(editing: editing),
      ),
    );
    if (changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre / SKU / categoría',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Object>>(
              future: _loadProducts(),
              builder: (context, snap) {
                final items = snap.data ?? const <Object>[];
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Sin artículos'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (c, i) {
                    final p = items[i];
                    final sku = _skuOf(p);
                    final skuText = (sku == null || sku.isEmpty) ? "-" : sku;
                    return ListTile(
                      title: Text(_nameOf(p)),
                      subtitle: Text('SKU: ' + skuText + '  |  Stock: ' + _stockOf(p).toString() +
                        '  |  Compra: ' + _costOf(p).toStringAsFixed(2) +
                        '  |  Venta: ' + _priceOf(p).toStringAsFixed(2)),
                      onTap: () => _openForm(editing: p),
                      trailing: Text('\$' + _priceOf(p).toStringAsFixed(2)),
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

class ProductForm extends StatefulWidget {
  final Object? editing;
  const ProductForm({super.key, this.editing});
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '0');
  final _priceCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');
  final _newCategoryCtrl = TextEditingController();

  String? _selectedCategory;
  bool _addingNewCategory = false;
  bool _saving = false;

  static const _kNew = '__NEW__';

  String _asString(Object? v) => v?.toString() ?? '';
  String? _get(Object? o, String key) { try { return (o as dynamic)[key]?.toString(); } catch (_) { try { return (o as dynamic).toJson()[key]?.toString(); } catch (_) { return null; } } }
  String _idOf(Object o) { try { return (o as dynamic).id as String; } catch (_) { try { return (o as dynamic)['id'] as String; } catch (_) { return ''; } } }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = _get(e, 'name') ?? '';
      _skuCtrl.text = _get(e, 'sku') ?? '';
      _costCtrl.text = (_get(e, 'cost') ?? '0');
      _priceCtrl.text = (_get(e, 'price') ?? '0');
      _stockCtrl.text = (_get(e, 'stock') ?? '0');
      _selectedCategory = _get(e, 'category');
    }
  }

  Future<List<String>> _loadCategories() async {
    final list = await ProductRepository().categoriesDistinct();
    if (_selectedCategory != null && _selectedCategory!.trim().isNotEmpty && !list.contains(_selectedCategory)) {
      list.add(_selectedCategory!);
    }
    return list;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: const Text('Esta acción no se puede deshacer. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _saving = true);
      try {
        await ProductRepository().deleteById(id);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    final editingId = isEditing ? _idOf(widget.editing!) : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Editar artículo' : 'Nuevo artículo', style: Theme.of(context).textTheme.titleLarge),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: _saving ? null : () => _confirmDelete(editingId!),
                      tooltip: 'Eliminar artículo',
                    )
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _loadCategories(),
                      builder: (context, snap) {
                        final items = snap.data ?? const <String>[];
                        return DropdownButtonFormField<String>(
                          value: _addingNewCategory
                              ? _kNew
                              : (items.contains(_selectedCategory) ? _selectedCategory : null),
                          items: [
                            ...items.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                            const DropdownMenuItem(value: _kNew, child: Text('Agregar nueva categoría…')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              if (v == _kNew) {
                                _addingNewCategory = true;
                                _selectedCategory = null;
                              } else {
                                _addingNewCategory = false;
                                _selectedCategory = v;
                              }
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Categoría'),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_addingNewCategory)
                TextFormField(
                  controller: _newCategoryCtrl,
                  decoration: const InputDecoration(labelText: 'Nueva categoría'),
                ),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio compra'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio venta'),
                  )),
                ],
              ),
              TextFormField(
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando…' : 'Guardar'),
                  onPressed: _saving ? null : () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    setState(() => _saving = true);
                    try {
                      final category = _addingNewCategory
                        ? (_newCategoryCtrl.text.trim().isEmpty ? null : _newCategoryCtrl.text.trim())
                        : _selectedCategory;

                      await ProductRepository().upsertProduct(
                        id: isEditing ? editingId : null,
                        name: _nameCtrl.text.trim(),
                        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
                        category: (category == null || category.trim().isEmpty) ? null : category.trim(),
                        cost: double.tryParse(_costCtrl.text) ?? 0,
                        price: double.tryParse(_priceCtrl.text) ?? 0,
                        stock: int.tryParse(_stockCtrl.text) ?? 0,
                      );
                      if (!mounted) return;
                      Navigator.pop(context, true);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
