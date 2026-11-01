import 'package:flutter/foundation.dart';

import 'transaction_type.dart';

@immutable
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.householdId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        type: TransactionType.fromString(json['type'] as String),
        icon: json['icon'] as String? ?? 'category',
        color: json['color'] as String? ?? '#6366F1',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
      );

  final String id;
  final String householdId;
  final String name;
  final TransactionType type;

  /// Key into `CategoryIcons.all`.
  final String icon;

  /// `#RRGGBB`
  final String color;
  final DateTime? createdAt;

  CategoryModel copyWith({String? name, String? icon, String? color}) =>
      CategoryModel(
        id: id,
        householdId: householdId,
        name: name ?? this.name,
        type: type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is CategoryModel &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.icon == icon &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, name, type, icon, color);

  @override
  String toString() => 'CategoryModel($name, ${type.name})';
}

/// Payload for creating/updating a category.
@immutable
class CategoryInput {
  const CategoryInput({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  final String name;
  final TransactionType type;
  final String icon;
  final String color;

  Map<String, dynamic> toInsertJson(String householdId) => {
        'household_id': householdId,
        'name': name.trim(),
        'type': type.dbValue,
        'icon': icon,
        'color': color,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name.trim(),
        'icon': icon,
        'color': color,
      };
}
