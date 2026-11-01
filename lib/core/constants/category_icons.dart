import 'package:flutter/material.dart';

/// Icons available for categories. The key is persisted in the database
/// (`categories.icon`) so the map must stay backwards compatible: never rename
/// a key, only add new ones.
abstract final class CategoryIcons {
  static const Map<String, IconData> all = {
    // Expense-leaning
    'restaurant': Icons.restaurant_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'home': Icons.home_rounded,
    'bolt': Icons.bolt_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'directions_car': Icons.directions_car_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'movie': Icons.movie_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'medical_services': Icons.medical_services_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'flight': Icons.flight_rounded,
    'hotel': Icons.hotel_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_android': Icons.phone_android_rounded,
    'person': Icons.person_rounded,
    'checkroom': Icons.checkroom_rounded,
    'spa': Icons.spa_rounded,
    'pets': Icons.pets_rounded,
    'school': Icons.school_rounded,
    'child_care': Icons.child_care_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'celebration': Icons.celebration_rounded,
    'build': Icons.build_rounded,
    'water_drop': Icons.water_drop_rounded,
    'credit_card': Icons.credit_card_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'savings': Icons.savings_rounded,
    // Income-leaning
    'payments': Icons.payments_rounded,
    'business_center': Icons.business_center_rounded,
    'laptop': Icons.laptop_rounded,
    'star': Icons.star_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'account_balance': Icons.account_balance_rounded,
    'handshake': Icons.handshake_rounded,
    'attach_money': Icons.attach_money_rounded,
    'redeem': Icons.redeem_rounded,
    // Generic
    'category': Icons.category_rounded,
    'more_horiz': Icons.more_horiz_rounded,
  };

  static const String fallbackKey = 'category';

  static IconData resolve(String? key) =>
      all[key] ?? all[fallbackKey] ?? Icons.category_rounded;

  static List<String> get keys => all.keys.toList(growable: false);
}

/// Curated palette for category colours (stored as `#RRGGBB`).
abstract final class CategoryColors {
  static const List<String> palette = [
    '#F97316', // orange
    '#EF4444', // red
    '#EC4899', // pink
    '#DB2777', // rose
    '#A855F7', // purple
    '#8B5CF6', // violet
    '#6366F1', // indigo
    '#2563EB', // blue
    '#0EA5E9', // sky
    '#14B8A6', // teal
    '#0D9488', // teal dark
    '#22C55E', // green
    '#16A34A', // green dark
    '#EAB308', // yellow
    '#F59E0B', // amber
    '#D97706', // amber dark
    '#64748B', // slate
    '#475569', // slate dark
  ];

  static Color parse(String? hex, {Color fallback = const Color(0xFF6366F1)}) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }

  static String toHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
