import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static final AppDatabase _i = AppDatabase._internal();
  factory AppDatabase() => _i;
  AppDatabase._internal();

  static const _dbName = 'popperscu.db';
  static const _dbVersion = 4; // bump para shipping_cost

  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(path, version: _dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
    return _db!;
    }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        category TEXT,
        cost REAL NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total REAL NOT NULL,
        discount REAL NOT NULL,
        profit REAL NOT NULL,
        shipping_cost REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
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
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE sales ADD COLUMN shipping_cost REAL NOT NULL DEFAULT 0");
    }
  }
}
