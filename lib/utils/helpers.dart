import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String genId() => _uuid.v4();
String nowIso() => DateTime.now().toIso8601String();

double _asDouble(Object? v, [double def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  final s = v.toString();
  return double.tryParse(s) ?? def;
}

int _asInt(Object? v, [int def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toInt();
  final s = v.toString();
  return int.tryParse(s) ?? def;
}

/// Helpers exportados por si los quieres usar en más lados.
extension MapNum on Map<String, Object?> {
  double getD(String k, [double def = 0]) => _asDouble(this[k], def);
  int getI(String k, [int def = 0]) => _asInt(this[k], def);
}