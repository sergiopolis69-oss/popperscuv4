import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseProvider {
  static final DatabaseProvider _i = DatabaseProvider._();
  DatabaseProvider._();
  factory DatabaseProvider() => _i;

  static const int dbVersion = 7; // súbelo si ya tienes otra versión
  static const String dbName = 'popperscuv4.db';

  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, v) async {
        await _createBase(db);
        await _createPurchases(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // Migraciones idempotentes
        if (oldV < 2) await _createPurchases(db);
        if (oldV < 3) await _ensureColumn(db, 'products', 'last_cost', 'REAL');
        if (oldV < 4) await _ensureColumn(db, 'products', 'stock', 'REAL DEFAULT 0');
        if (oldV < 5) await _ensurePurchaseFlags(db);
        if (oldV < 6) await _createSupplierCosts(db);
      },
    );
  }

  Future<void> _createBase(Database db) async {
    // Tablas mínimas si vienes "en limpio"
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT,
        stock REAL DEFAULT 0,
        last_cost REAL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL,
        line_total REAL,
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');
  }

  Future<void> _createPurchases(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        is_canceled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL,
        is_canceled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');
  }

  Future<void> _createSupplierCosts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_supplier_costs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        last_cost REAL NOT NULL,
        average_cost REAL NOT NULL,
        samples INTEGER NOT NULL DEFAULT 1,
        UNIQUE(product_id, supplier_id),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      );
    ''');
  }

  Future<void> _ensurePurchaseFlags(Database db) async {
    await _ensureColumn(db, 'purchases', 'is_canceled', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'purchase_items', 'is_canceled', 'INTEGER NOT NULL DEFAULT 0');
  }

  Future<void> _ensureColumn(Database db, String table, String col, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((r) => r['name'] == col);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
    }
  }
}
