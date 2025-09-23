import 'package:flutter/material.dart';
import '../modules/purchases/data/purchase_repository.dart';
import '../modules/purchases/ui/purchase_list_page.dart';

class SalesHistoryWidget extends StatelessWidget {
  const SalesHistoryWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Aquí renderiza tu historial de ventas existente'));
  }
}

class HistoryTabScaffold extends StatelessWidget {
  final PurchaseRepository purchaseRepo;
  const HistoryTabScaffold({super.key, required this.purchaseRepo});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ventas'),
              Tab(text: 'Compras'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const SalesHistoryWidget(),
            PurchaseListPage(repo: purchaseRepo),
          ],
        ),
      ),
    );
  }
}
