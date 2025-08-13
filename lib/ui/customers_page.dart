import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../repositories/customer_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _uuid = const Uuid();
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      _rows = await CustomerRepository().all();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForm({Map<String, Object?>? edit}) async {
    final nameCtrl = TextEditingController(text: (edit?['name'] as String?) ?? '');
    final phoneCtrl = TextEditingController(text: (edit?['phone'] as String?) ?? '');
    final emailCtrl = TextEditingController(text: (edit?['email'] as String?) ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok == true) {
      final m = {
        'id': edit?['id'] as String? ?? _uuid.v4(),
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'createdAt': edit?['createdAt'] ?? DateTime.now().toIso8601String(),
      };
      await CustomerRepository().upsertCustomer(m); // un solo Map como parámetro
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _rows[i];
                final name = (r['name'] as String?) ?? (r['id'] as String? ?? '');
                return ListTile(
                  title: Text(name),
                  subtitle: Text(((r['phone'] as String?) ?? '').trim().isEmpty
                      ? ((r['email'] as String?) ?? '')
                      : (r['phone'] as String)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showForm(edit: r),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
