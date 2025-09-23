// lib/main.dart (HOTFIX con manejo de errores en init)
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/database_provider.dart';
import 'modules/purchases/data/purchase_repository.dart';
import 'modules/purchases/logic/purchase_service.dart';
import 'modules/purchases/ui/purchase_list_page.dart';
import 'modules/purchases/ui/purchase_form_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dbProvider = DatabaseProvider();
    await dbProvider.init();
    runApp(MyApp(db: dbProvider.db));
  } catch (e, st) {
    runApp(InitErrorApp(message: e.toString()));
    // ignore: avoid_print
    print('Init error: $e\\n$st');
  }
}

class InitErrorApp extends StatelessWidget {
  final String message;
  const InitErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Error al iniciar')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(message),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Database db;
  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final purchaseRepo = PurchaseRepository(db);
    final purchaseService = PurchaseService(purchaseRepo);

    return MaterialApp(
      title: 'Poppers CUV',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: HomePage(
        purchaseRepo: purchaseRepo,
        purchaseService: purchaseService,
      ),
      routes: {
        '/purchases': (_) => PurchaseListPage(repo: purchaseRepo),
        '/purchases/new': (_) => PurchaseFormPage(service: purchaseService),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  final PurchaseRepository purchaseRepo;
  final PurchaseService purchaseService;
  const HomePage({
    super.key,
    required this.purchaseRepo,
    required this.purchaseService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/purchases'),
          icon: const Icon(Icons.inventory_2),
          label: const Text('Ir a Compras'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/purchases/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}