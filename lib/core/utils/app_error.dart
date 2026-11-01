import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates low-level exceptions into short, friendly messages.
abstract final class AppError {
  static String message(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';

    if (error is AuthException) return _auth(error);

    if (error is PostgrestException) return _postgrest(error);

    if (error is SocketException || error is TimeoutException) {
      return 'No internet connection. Check your network and try again.';
    }

    if (error is FormatException) return 'Some of the data was invalid.';

    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String _auth(AuthException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Please confirm your email address first. Check your inbox.';
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('password should be')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'No internet connection. Check your network and try again.';
    }
    return error.message;
  }

  static String _postgrest(PostgrestException error) {
    final code = error.code ?? '';
    final raw = error.message;

    // Messages raised explicitly by our SQL functions are already friendly.
    if (code == '22023' || code == 'P0001') return raw;

    switch (code) {
      case '42501':
        return raw.contains('member') || raw.contains('signed in')
            ? raw
            : 'You do not have permission to do that.';
      case '23505':
        return 'That name is already in use.';
      case '23503':
        return 'This item is still referenced by other records.';
      case '23514':
        return 'Some of the values were not valid.';
      case 'PGRST301':
      case 'PGRST302':
        return 'Your session has expired. Please sign in again.';
    }
    if (raw.toLowerCase().contains('jwt')) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'The server rejected the request. Please try again.';
  }
}
