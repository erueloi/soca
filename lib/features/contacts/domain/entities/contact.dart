class Contact {
  final String id;
  final String name;
  final String role; // e.g., 'Arquitecta', 'Jardiner'
  final String phone;
  final String email;

  const Contact({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
  });

  Contact copyWith({
    String? id,
    String? name,
    String? role,
    String? phone,
    String? email,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'role': role, 'phone': phone, 'email': email};
  }

  factory Contact.fromMap(Map<String, dynamic> map, String id) {
    return Contact(
      id: id,
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
    );
  }
}
