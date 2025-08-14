import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Utilidades simples, sin dependencias externas.
String nowIso() => DateTime.now().toIso8601String();
String genId() => DateTime.now().microsecondsSinceEpoch.toString() +
    Random().nextInt(1 << 20).toString();

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'popperscuv.db');

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // Productos
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sku TEXT,
            category TEXT,
            price REAL NOT NULL,
            cost REAL NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Clientes (usamos phone como identificador si no hay id)
        await db.execute('''
          CREATE TABLE customers(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Ventas (usa customer_id; shipping_cost no afecta utilidad)
        await db.execute('''
          CREATE TABLE sales(
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            total REAL NOT NULL,
            discount REAL NOT NULL,
            shipping_cost REAL NOT NULL,
            profit REAL NOT NULL,
            payment_method TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Items de venta
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
            line_discount REAL NOT NULL,
            subtotal REAL NOT NULL,
            profit REAL NOT NULL
          )
        ''');

        // Movimientos de inventario
        await db.execute('''
          CREATE TABLE inventory_movements(
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL,
            delta INTEGER NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // Asegura columnas con nombres correctos por si vienen de esquemas viejos
        if (oldV < 2) {
          await db.execute("ALTER TABLE sales ADD COLUMN shipping_cost REAL NOT NULL DEFAULT 0");
        }
        if (oldV < 3) {
          // Si alguien tenía 'customerId' en lugar de 'customer_id'
          // intenta crear vista/renombrar (best-effort, ignora si ya existe)
          try {
            await db.execute("ALTER TABLE sales RENAME COLUMN customerId TO customer_id");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE sales RENAME COLUMN createdAt TO created_at");
          } catch (_) {}
        }
      },
    );
    return _db!;
  }
}