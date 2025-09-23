import 'package:flutter/material.dart';
import 'db/database_provider.dart';
import 'repositories/purchase_repository.dart';
import 'repositories/sale_repository.dart';
import 'ui/purchases/purchases_list_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final DatabaseProvider provider;
  PurchaseRepository? purchaseRepo;
  SaleRepository? saleRepo;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    provider = DatabaseProvider();
    final db = await provider.database;
    purchaseRepo = PurchaseRepository(db);
    saleRepo = SaleRepository(db);
    setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'popperscuv4 Android',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: !ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : PurchasesListPage(repo: purchaseRepo!),
    );
  }
}
