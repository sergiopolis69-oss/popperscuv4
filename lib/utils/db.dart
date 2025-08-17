import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'popperscuv.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        // Productos
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY,
            sku TEXT UNIQUE,
            name TEXT,
            price REAL DEFAULT 0,
            cost REAL DEFAULT 0,
            stock INTEGER DEFAULT 0,
            category TEXT,
            created_at TEXT,
            updated_at TEXT
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);');

        // Clientes
        await db.execute('''
          CREATE TABLE customers(
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT UNIQUE,
            created_at TEXT,
            updated_at TEXT
          );
        ''');

        // Ventas
        await db.execute('''
          CREATE TABLE sales(
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            total REAL DEFAULT 0,
            discount REAL DEFAULT 0,
            shipping_cost REAL DEFAULT 0,
            profit REAL DEFAULT 0,
            payment_method TEXT,
            created_at TEXT
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at);');

        // Items de venta
        await db.execute('''
          CREATE TABLE sale_items(
            id TEXT PRIMARY KEY,
            sale_id TEXT,
            product_id TEXT,
            sku TEXT,
            name TEXT,
            price REAL DEFAULT 0,
            cost REAL DEFAULT 0,
            quantity INTEGER DEFAULT 1,
            line_discount REAL DEFAULT 0,
            subtotal REAL DEFAULT 0
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);');
      },
    );
    return _db!;
  }
}