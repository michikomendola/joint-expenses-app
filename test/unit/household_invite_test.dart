import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/app_error.dart';
import 'package:joint_expenses/data/models/household.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('HouseholdInvite.fromRpc', () {
    test('reads a table-function list row', () {
      final invite = HouseholdInvite.fromRpc([
        {'code': 'ABCDE23456', 'expires_at': '2026-11-03T12:00:00.000Z'},
      ]);
      expect(invite.code, 'ABCDE23456');
      expect(invite.formattedCode, 'ABCDE-23456');
    });

    test('reads a single map', () {
      final invite = HouseholdInvite.fromRpc({
        'code': 'ABCDE23456',
        'expires_at': '2026-11-03T12:00:00.000Z',
      });
      expect(invite.formattedCode, 'ABCDE-23456');
    });
  });

  group('AppError', () {
    test('explains a missing invite RPC instead of a generic reject', () {
      expect(
        AppError.message(
          const PostgrestException(
            message: 'Could not find the function public.create_household_invite',
            code: 'PGRST202',
          ),
        ),
        contains('SQL migrations'),
      );
      expect(
        AppError.message(
          const PostgrestException(
            message: 'function extensions.gen_random_bytes(integer) does not exist',
            code: '42883',
          ),
        ),
        contains('SQL migrations'),
      );
    });
  });
}
