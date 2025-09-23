import 'package:flutter/material.dart';
import '../../repositories/sale_repository.dart';

class SaleDetailPage extends StatefulWidget {
  final int saleId; final SaleRepository repo;
  const SaleDetailPage({super.key, required this.saleId, required this.repo});
  @override State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  Map<String, dynamic>? data;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { data = await widget.repo.getWithItems(widget.saleId); setState((){}); }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar venta'),
      content: const Text('Se devolverá la existencia de todos los productos y la venta será eliminada. ¿Continuar?'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('No')), ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Sí, eliminar'))],
    ));
    if (ok==true) { await widget.repo.deleteSale(widget.saleId); if (mounted) Navigator.pop(context,true); }
  }

  @override
  Widget build(BuildContext context) {
    if (data==null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final h = data!['header'] as Map<String,dynamic>;
    final items = (data!['items'] as List).cast<Map<String,dynamic>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta'), actions: [
        IconButton(onPressed: _delete, icon: const Icon(Icons.delete_forever))
      ]),
      body: ListView(children: [
        ListTile(title: Text('Venta #${h['id']}'), subtitle: Text('Fecha: ${h['created_at']}')),
        const Divider(),
        ...items.map((it)=>ListTile(
          title: Text((it['product_name'] as String?) ?? 'Producto ${it['product_id']}'),
          subtitle: Text('Cant: ${(it['quantity'] as num)}  ·  Precio: \\${(it['unit_price'] as num?)?.toStringAsFixed(2) ?? '-'}'),
          trailing: Text('\\${(it['line_total'] as num?)?.toStringAsFixed(2) ?? ''}'),
        )),
      ]),
    );
  }
}
