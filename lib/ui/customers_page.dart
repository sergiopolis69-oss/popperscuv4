
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/customer_repository.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Map<String, Object?>? _edit;

  Future<void> _loadForEdit(Map<String, Object?> row) async {
    _edit = row;
    _nameCtrl.text = (row['name'] ?? '') as String;
    _phoneCtrl.text = (row['phone'] ?? '') as String;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await CustomerRepository().upsertCustomerNamed(
      id: _edit?['id'] as String?,
      name: _nameCtrl.text.trim(),
      phone: (() {
        final p = _phoneCtrl.text.trim();
        return p.isEmpty ? null : p;
      })(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    setState(() {});
  }

  Future<void> _delete(String id) async {
    await CustomerRepository().deleteById(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: CustomerRepository().all(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? const <Map<String, Object?>>[];
          if (rows.isEmpty) {
            return const Center(child: Text('Sin clientes. Usa el botón + para agregar.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = rows[i];
              return ListTile(
                title: Text((c['name'] ?? '') as String),
                subtitle: Text((c['phone'] ?? '-') as String),
                onTap: () async {
                  await _loadForEdit(c);
                  if (!mounted) return;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _EditorSheet(
                      nameCtrl: _nameCtrl,
                      phoneCtrl: _phoneCtrl,
                      onSave: _save,
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete((c['id'] ?? '') as String),
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
          _phoneCtrl.clear();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EditorSheet(
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
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
  final TextEditingController phoneCtrl;
  final VoidCallback onSave;

  const _EditorSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
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
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
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
