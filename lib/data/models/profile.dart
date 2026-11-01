import 'package:flutter/foundation.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.email,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
            ? (json['display_name'] as String).trim()
            : 'Member',
        email: json['email'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
      );

  final String id;
  final String displayName;
  final String? email;
  final DateTime? createdAt;

  /// Up to two initials, e.g. `Michiko Mendola` → `MM`.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Profile copyWith({String? displayName, String? email}) => Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, displayName, email);
}
