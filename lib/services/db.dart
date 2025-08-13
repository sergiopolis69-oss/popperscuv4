import 'dart:async';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;

  static const _dbName = 'app.db';
  // Sube esta versión si ya tienes una BD instalada para que corra onUpgrade.
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final path = '$dbDir/$_dbName';
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // --- Products
    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        category TEXT,
        price REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku ON products(sku);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);');

    // --- Customers
    await db.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);');

    // --- Sales (incluye shipping_cost y profit)
    await db.execute('''
      CREATE TABLE sales(
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        shipping_cost REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);');

    // --- Sale items
    await db.execute('''
      CREATE TABLE sale_items(
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost_at_sale REAL NOT NULL DEFAULT 0,
        line_discount REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);');

    // --- Inventory movements
    await db.execute('''
      CREATE TABLE inventory_movements(
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_movements_product_id ON inventory_movements(product_id);');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // v4: agregamos shipping_cost a sales
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN shipping_cost REAL NOT NULL DEFAULT 0;'
      );
    }
    // v5: aseguramos columnas nuevas usadas por POS
    if (oldVersion < 5) {
      // Si ya existen, SQLite ignora el ALTER y lanzaría error; por eso usa try/catch si lo prefieres.
      await db.execute(
        'ALTER TABLE customers ADD COLUMN notes TEXT;'
      );
      await db.execute(
        'ALTER TABLE sale_items ADD COLUMN line_discount REAL NOT NULL DEFAULT 0;'
      );
      await db.execute(
        'ALTER TABLE sale_items ADD COLUMN cost_at_sale REAL NOT NULL DEFAULT 0;'
      );
    }
  }

  // Utilitario opcional
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('inventory_movements');
      await txn.delete('products');
      await txn.delete('customers');
    });
  }
}
