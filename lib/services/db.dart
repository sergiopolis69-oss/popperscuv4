
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = dbPath + '/popperscuv.db';

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        category TEXT,
        cost REAL NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total REAL NOT NULL,
        discount REAL NOT NULL,
        profit REAL NOT NULL,
        shipping REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost_at_sale REAL NOT NULL,
        line_discount REAL NOT NULL,
        subtotal REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory_movements(product_id);');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Ejemplo de migraciones simples
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sales ADD COLUMN shipping REAL NOT NULL DEFAULT 0;');
    }
  }
}
