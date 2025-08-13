
import 'package:flutter/material.dart';
import '../repositories/customer_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';

  String _asString(Object? v) => v?.toString() ?? '';
  String _lower(Object? v) => _asString(v).toLowerCase();
  String _idOf(Object o) { try { return (o as dynamic).id as String; } catch (_) { try { return (o as dynamic)['id'] as String; } catch (_) { return ''; } } }
  String _nameOf(Object o) { try { return (o as dynamic).name as String; } catch (_) { try { return (o as dynamic)['name'] as String; } catch (_) { return ''; } } }
  String? _phoneOf(Object o) { try { return (o as dynamic).phone as String?; } catch (_) { try { return (o as dynamic)['phone'] as String?; } catch (_) { return null; } } }
  String? _emailOf(Object o) { try { return (o as dynamic).email as String?; } catch (_) { try { return (o as dynamic)['email'] as String?; } catch (_) { return null; } } }

  Future<List<Object>> _loadCustomers() async {
    final list = await CustomerRepository().all();
    final objs = List<Object>.from(list);
    if (_query.trim().isEmpty) return objs;
    final q = _query.trim().toLowerCase();
    return objs.where((c) =>
      _lower(_nameOf(c)).contains(q) ||
      _lower(_phoneOf(c)).contains(q) ||
      _lower(_emailOf(c)).contains(q)
    ).toList();
  }

  Future<void> _openForm({Object? editing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CustomerForm(editing: editing),
      ),
    );
    if (changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
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
                labelText: 'Buscar por nombre / teléfono / email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Object>>(
              future: _loadCustomers(),
              builder: (context, snap) {
                final items = snap.data ?? const <Object>[];
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Sin clientes'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (c, i) {
                    final x = items[i];
                    return ListTile(
                      title: Text(_nameOf(x)),
                      subtitle: Text([_phoneOf(x), _emailOf(x)].where((e) => (e ?? '').isNotEmpty).join(' · ')),
                      onTap: () => _openForm(editing: x),
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

class CustomerForm extends StatefulWidget {
  final Object? editing;
  const CustomerForm({super.key, this.editing});
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;

  String? _get(Object? o, String key) { try { return (o as dynamic)[key]?.toString(); } catch (_) { try { return (o as dynamic).toJson()[key]?.toString(); } catch (_) { return null; } } }
  String _idOf(Object o) { try { return (o as dynamic).id as String; } catch (_) { try { return (o as dynamic)['id'] as String; } catch (_) { return ''; } } }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = _get(e, 'name') ?? '';
      _phoneCtrl.text = _get(e, 'phone') ?? '';
      _emailCtrl.text = _get(e, 'email') ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
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
        await CustomerRepository().deleteById(id);
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
                  Text(isEditing ? 'Editar cliente' : 'Nuevo cliente', style: Theme.of(context).textTheme.titleLarge),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: _saving ? null : () => _confirmDelete(editingId!),
                      tooltip: 'Eliminar cliente',
                    )
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
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
                      await CustomerRepository().upsertCustomer(
                        id: isEditing ? editingId : null,
                        name: _nameCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
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
