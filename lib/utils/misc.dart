import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

String genId() => _uuid.v4();
String nowIso() => DateTime.now().toIso8601String();

double toDouble(dynamic v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '.');
  return double.tryParse(s) ?? fallback;
}

int toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? fallback;
}

String toStr(dynamic v) => (v ?? '').toString().trim();