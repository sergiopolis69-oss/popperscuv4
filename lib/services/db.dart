// lib/utils/db.dart
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'popperscuv.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        // Productos
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products(
            id TEXT PRIMARY KEY,
            name TEXT,
            sku TEXT,
            category TEXT,
            price REAL NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            stock INTEGER NOT NULL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(LOWER(name))');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(LOWER(sku))');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_cat ON products(LOWER(category))');

        // Clientes
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers(
            id TEXT PRIMARY KEY,      -- puedes usar phone como id si quieres
            name TEXT,
            phone TEXT,
            email TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(LOWER(name))');

        // Ventas
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales(
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            total REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            shipping_cost REAL NOT NULL DEFAULT 0,
            profit REAL NOT NULL DEFAULT 0,      -- utilidad de la venta
            payment_method TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)');

        // Partidas de venta
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sale_items(
            id TEXT PRIMARY KEY,
            sale_id TEXT,
            product_id TEXT,
            name TEXT,
            sku TEXT,
            price REAL NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            quantity INTEGER NOT NULL DEFAULT 1,
            line_discount REAL NOT NULL DEFAULT 0,
            subtotal REAL NOT NULL DEFAULT 0,
            created_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_items_sale ON sale_items(sale_id)');

        // Movimientos de inventario
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_movements(
            id TEXT PRIMARY KEY,
            product_id TEXT,
            delta INTEGER NOT NULL,
            reason TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_mov_prod ON inventory_movements(product_id)');
      },
      onUpgrade: (db, oldV, newV) async {
        // Asegura columnas si vienes de una BD vieja
        if (oldV < 2) {
          await db.execute('ALTER TABLE sales ADD COLUMN profit REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE sales ADD COLUMN shipping_cost REAL NOT NULL DEFAULT 0');
        }
      },
    );
  }
}