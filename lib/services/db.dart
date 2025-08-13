import 'dart:async';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'popperscuv.db';
  static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/$_dbName';
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onOpen: (db) async {
        // Asegura claves foráneas en SQLite
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // productos
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sku TEXT,
            category TEXT,
            price REAL NOT NULL,
            cost REAL NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // clientes
        await db.execute('''
          CREATE TABLE customers(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT UNIQUE,
            notes TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // ventas
        await db.execute('''
          CREATE TABLE sales(
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            total REAL NOT NULL,
            discount REAL NOT NULL DEFAULT 0,
            shipping_cost REAL NOT NULL DEFAULT 0,
            profit REAL NOT NULL DEFAULT 0,
            payment_method TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id)
          )
        ''');

        // renglones de venta
        await db.execute('''
          CREATE TABLE sale_items(
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            product_id TEXT,
            name TEXT,
            sku TEXT,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            cost REAL NOT NULL,
            line_discount REAL NOT NULL DEFAULT 0,
            subtotal REAL NOT NULL,
            profit REAL NOT NULL,
            FOREIGN KEY(sale_id) REFERENCES sales(id)
          )
        ''');

        // movimientos de inventario
        await db.execute('''
          CREATE TABLE inventory_movements(
            id TEXT PRIMARY KEY,
            product_id TEXT,
            delta INTEGER NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // Aquí podrías manejar migraciones si vienes de esquemas previos.
        // Ejemplo: normalizar nombres de columnas, etc.
      },
    );
    return _db!;
  }
}

/// util: ahora ISO8601 (con milisegundos) para timestamps
String nowIso() => DateTime.now().toIso8601String();

/// util: id simple sin dependencia externa
String genId() => DateTime.now().microsecondsSinceEpoch.toString();