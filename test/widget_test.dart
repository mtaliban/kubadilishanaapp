import 'package:flutter_test/flutter_test.dart';
import 'package:kubadilishanaapp/providers/auth_provider.dart';

void main() {
  group('AuthUser', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'user_id': 'abc123',
        'full_name': 'Amina Hassan',
        'phone_primary': '0712345678',
        'email': 'amina@example.com',
        'category': 'health',
        'cadre_code': 'CO',
        'cadre_display': 'Clinical Officer',
        'employment_sector': 'wizara_afya',
        'is_admin': false,
        'is_verified': true,
        'contact_enabled': true,
        'current_station': {'region_name': 'Dar es Salaam'},
      };
      final user = AuthUser.fromJson(json);
      expect(user.userId, 'abc123');
      expect(user.fullName, 'Amina Hassan');
      expect(user.phone, '0712345678');
      expect(user.email, 'amina@example.com');
      expect(user.category, 'health');
      expect(user.cadreCode, 'CO');
      expect(user.cadreDisplay, 'Clinical Officer');
      expect(user.employmentSector, 'wizara_afya');
      expect(user.isAdmin, false);
      expect(user.isVerified, true);
      expect(user.contactEnabled, true);
      expect(user.currentStation?['region_name'], 'Dar es Salaam');
    });

    test('fromJson uses defaults for missing fields', () {
      final user = AuthUser.fromJson({
        'user_id': 'x',
        'full_name': 'Test',
        'phone_primary': '0700000000',
      });
      expect(user.isAdmin, false);
      expect(user.isVerified, false);
      expect(user.contactEnabled, false);
      expect(user.email, isNull);
      expect(user.currentStation, isNull);
    });

    test('copyWith updates only specified fields', () {
      final user = AuthUser.fromJson({
        'user_id': 'u1',
        'full_name': 'John',
        'phone_primary': '0700000001',
        'is_verified': false,
        'contact_enabled': false,
      });
      final updated = user.copyWith(isVerified: true, contactEnabled: true);
      expect(updated.isVerified, true);
      expect(updated.contactEnabled, true);
      expect(updated.fullName, 'John');
      expect(updated.userId, 'u1');
    });

    test('copyWith without args keeps original values', () {
      final user = AuthUser.fromJson({
        'user_id': 'u2',
        'full_name': 'Jane',
        'phone_primary': '0700000002',
        'is_verified': true,
        'contact_enabled': true,
      });
      final copy = user.copyWith();
      expect(copy.isVerified, true);
      expect(copy.contactEnabled, true);
    });
  });
}
