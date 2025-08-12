import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../providers/providers.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (c, i) {
            final p = items[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text(p.phone ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(edit: p)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                    await ref.read(customerRepoProvider).delete(p.id);
                    ref.invalidate(customersProvider);
                  }),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _openForm({Customer? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final phone = TextEditingController(text: edit?.phone ?? '');
    final email = TextEditingController(text: edit?.email ?? '');
    final notes = TextEditingController(text: edit?.notes ?? '');

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(edit == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Teléfono')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notas')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () async {
            final repo = ref.read(customerRepoProvider);
            if (edit == null) {
              await repo.create(Customer(
                id: const Uuid().v4(),
                name: name.text.trim(),
                phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                email: email.text.trim().isEmpty ? null : email.text.trim(),
                notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              ));
            } else {
              await repo.update(Customer(
                id: edit.id,
                name: name.text.trim(),
                phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                email: email.text.trim().isEmpty ? null : email.text.trim(),
                notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                createdAt: edit.createdAt,
                updatedAt: DateTime.now(),
              ));
            }
            if (mounted) Navigator.pop(c);
            ref.invalidate(customersProvider);
          }, child: const Text('Guardar'))
        ],
      ),
    );
  }
}
