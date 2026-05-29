import 'dart:convert';

class SosContact {
  final String id;
  final String name;
  final String phoneNumber;

  SosContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }

  factory SosContact.fromMap(Map<String, dynamic> map) {
    return SosContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SosContact.fromJson(String source) =>
      SosContact.fromMap(json.decode(source));
}
