import 'package:flutter/foundation.dart';

import 'profile.dart';

@immutable
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.currency,
    this.createdAt,
  });

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String,
        currency: (json['currency'] as String?)?.toUpperCase() ?? 'PHP',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
      );

  final String id;
  final String name;
  final String ownerId;
  final String currency;
  final DateTime? createdAt;

  Household copyWith({String? name, String? currency}) => Household(
        id: id,
        name: name ?? this.name,
        ownerId: ownerId,
        currency: currency ?? this.currency,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Household &&
      other.id == id &&
      other.name == name &&
      other.ownerId == ownerId &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(id, name, ownerId, currency);
}

enum MemberRole {
  owner,
  member;

  static MemberRole fromString(String? value) =>
      value == 'owner' ? MemberRole.owner : MemberRole.member;

  String get label => this == MemberRole.owner ? 'Owner' : 'Member';
}

@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.profile,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        userId: json['user_id'] as String,
        role: MemberRole.fromString(json['role'] as String?),
        joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        profile: json['profile'] is Map<String, dynamic>
            ? Profile.fromJson(json['profile'] as Map<String, dynamic>)
            : null,
      );

  final String id;
  final String householdId;
  final String userId;
  final MemberRole role;
  final DateTime joinedAt;
  final Profile? profile;

  String get displayName => profile?.displayName ?? 'Member';

  @override
  bool operator ==(Object other) =>
      other is HouseholdMember &&
      other.id == id &&
      other.userId == userId &&
      other.role == role &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(id, userId, role, profile);
}

/// Result of `create_household_invite`.
@immutable
class HouseholdInvite {
  const HouseholdInvite({required this.code, required this.expiresAt});

  factory HouseholdInvite.fromJson(Map<String, dynamic> json) => HouseholdInvite(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      );

  final String code;
  final DateTime expiresAt;

  /// `ABCDE-FGHJK`
  String get formattedCode {
    if (code.length != 10) return code;
    return '${code.substring(0, 5)}-${code.substring(5)}';
  }
}
