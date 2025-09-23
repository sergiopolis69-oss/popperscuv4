// lib/data/database_provider.dart (HOTFIX)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../db/migrations/m_003_purchases_sql.dart';

class DatabaseProvider {
  static final DatabaseProvider _instance = DatabaseProvider._();
  DatabaseProvider._();
  factory DatabaseProvider() => _instance;

  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'app.db');
    _db = await openDatabase(
      path,
      version: 5, // ⬅️ sube la versión para forzar migración
      onCreate: (db, version) async {
        await _enableFk(db);
        await _applyPurchasesMigration(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _enableFk(db);
        if (oldVersion < 3) {
          await _applyPurchasesMigration(db);
        }
      },
    );
  }

  Future<void> _enableFk(Database db) => db.execute('PRAGMA foreign_keys = ON');

  Future<void> _applyPurchasesMigration(Database db) async {
    for (final raw in kPurchasesMigration.split(';')) {
      final s = raw.trim();
      if (s.isNotEmpty) {
        await db.execute('$s;');
      }
    }
  }
}