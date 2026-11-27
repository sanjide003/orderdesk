import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final String source; // 'manual' | 'excel' | 'order'
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.notes = '',
    this.source = 'manual',
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    String? source,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOptDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return CustomerModel(
      id: id,
      name: (map['name'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      source: (map['source'] ?? 'manual') as String,
      isDeleted: (map['isDeleted'] ?? false) as bool,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      deletedAt: parseOptDate(map['deletedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'source': source,
        'isDeleted': isDeleted,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'deletedAt':
            deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      };
}
