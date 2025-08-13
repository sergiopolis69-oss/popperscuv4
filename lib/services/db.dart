// … imports

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  AppDatabase._();
  factory AppDatabase() => _instance;

  static const _dbName = 'app.db';
  static const _dbVersion = 4; // súbela si estabas en 3

  Future<Database> get database async {
    return openDatabase(
      _dbName,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sales(
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        shipping_cost REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE sale_items(
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost_at_sale REAL NOT NULL DEFAULT 0,
        line_discount REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL
      );
    ''');
    // … tus otras tablas (products, customers, inventory_movements, etc.)
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE sales ADD COLUMN shipping_cost REAL NOT NULL DEFAULT 0;');
    }
  }
}
