import 'package:flutter/material.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  // Coloca aquí tu lógica real (repository, forms, etc.).
  // Te dejo un placeholder minimal para que compile sin errores.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: const Center(
        child: Text('Listado de clientes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: abre formulario para nuevo cliente
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
