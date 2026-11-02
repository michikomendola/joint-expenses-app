import '../../../data/models/category.dart';
import '../../../data/models/transaction_type.dart';

/// Suggests an existing household expense category from a merchant name.
/// Never invents categories and never decides Personal vs Joint.
abstract final class MerchantCategorizer {
  static const Map<String, List<String>> keywords = {
    'Food & Drinks': [
      'jollibee', 'chowking', 'mcdonald', 'kfc', 'yellow cab', 'dunkin',
      'starbucks', 'coffee', 'banh mi', 'llao', 'vikings', 'atmosphere',
      'restaurant', 'food panda', 'foodpanda', 'grabfood', 'kitchen',
    ],
    'Groceries': [
      'supermarket', 'super metro', 'robinsons supermarket', 'save more',
      'savemore', 'puregold', 's m hyper', 'sm hyper',
    ],
    'Transportation': [
      'grab', 'move it', 'moveit', 'maxim', 'petron', 'shell', 'caltex',
      'angeles', 'lrt', 'mrt', 'uber',
    ],
    'Travel': ['ceb pac', 'cebupac', 'cebu air', 'airasia', 'pal ', 'airline'],
    'Shopping': [
      'shopee', 'lazada', 'the loop', 'istore', 'ace hardware', 'decathlon',
      'unitop', 'digital village', 'aerophone', 'echo appliance', 'gintell',
    ],
    'Healthcare': [
      'watsons', 'mercury', 'pharmacy', 'optical', 'rose pharmacy', 'evercare',
      'clinic', 'hospital', 'dental',
    ],
    'Subscriptions': [
      'netflix', 'spotify', 'youtube', 'chatgpt', 'openai', 'cursor',
      'squarespace', 'google', 'icloud', 'apple.com',
    ],
    'Utilities': ['veco', 'pldt', 'globe', 'meralco', 'maynilad', 'converge'],
    'Entertainment': ['timezone', 'cinema', 'sm cinema', 'ayala malls cinemas'],
    'Personal': ['domain#'],
  };

  static CategoryModel? suggest({
    required String? merchant,
    required List<CategoryModel> categories,
    Map<String, String> remembered = const {},
  }) {
    final expenses = categories.where((c) => c.type == TransactionType.expense).toList();
    if (expenses.isEmpty || merchant == null || merchant.trim().isEmpty) {
      return _named(expenses, 'Others');
    }
    final key = merchant.toLowerCase();
    final rememberedId = remembered[key];
    if (rememberedId != null) {
      for (final c in expenses) {
        if (c.id == rememberedId) return c;
      }
    }
    for (final entry in keywords.entries) {
      if (entry.value.any(key.contains)) {
        return _named(expenses, entry.key) ?? _named(expenses, 'Others');
      }
    }
    return _named(expenses, 'Others');
  }

  static CategoryModel? _named(List<CategoryModel> categories, String name) {
    for (final c in categories) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    return categories.isEmpty ? null : categories.last;
  }
}
