import '../constants/app_constants.dart';
import 'money.dart';

/// Form validators. Each returns `null` when valid or a user-facing message.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < AppConstants.minPasswordLength) {
      return 'Use at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? displayName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length > AppConstants.maxDisplayNameLength) {
      return 'Name must be ${AppConstants.maxDisplayNameLength} characters or fewer';
    }
    return null;
  }

  static String? householdName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Household name is required';
    if (text.length > AppConstants.maxHouseholdNameLength) {
      return 'Keep it under ${AppConstants.maxHouseholdNameLength} characters';
    }
    return null;
  }

  static String? categoryName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Category name is required';
    if (text.length > AppConstants.maxCategoryNameLength) {
      return 'Keep it under ${AppConstants.maxCategoryNameLength} characters';
    }
    return null;
  }

  static String? description(String? value) {
    if (value == null) return null;
    if (value.length > AppConstants.maxDescriptionLength) {
      return 'Keep it under ${AppConstants.maxDescriptionLength} characters';
    }
    return null;
  }

  static String? amount(String? value, {bool allowNegative = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Amount is required';
    final money = Money.tryParse(text);
    if (money == null) return 'Enter a valid amount';
    if (money.isZero) return 'Amount must not be zero';
    if (money.isNegative && !allowNegative) return 'Amount must be greater than zero';
    if (money.abs.minor > AppConstants.maxAmountMinor) return 'Amount is too large';
    return null;
  }

  static String? inviteCode(String? value) {
    final cleaned = (value ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return 'Invite code is required';
    if (cleaned.length != AppConstants.inviteCodeLength) {
      return 'Invite codes have ${AppConstants.inviteCodeLength} characters';
    }
    return null;
  }
}
