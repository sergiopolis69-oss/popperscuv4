class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;

  Supplier({ this.id, required this.name, this.phone, this.email, this.notes });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'notes': notes,
  };

  static Supplier fromMap(Map<String, dynamic> m) => Supplier(
    id: m['id'] as int?,
    name: m['name'] as String,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    notes: m['notes'] as String?,
  );
}
