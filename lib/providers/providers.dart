import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../models/product.dart';
import '../models/customer.dart';

final productRepoProvider = Provider<ProductRepository>((ref) => ProductRepository());
final customerRepoProvider = Provider<CustomerRepository>((ref) => CustomerRepository());

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.read(productRepoProvider);
  return repo.all();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.read(customerRepoProvider);
  return repo.all();
});
