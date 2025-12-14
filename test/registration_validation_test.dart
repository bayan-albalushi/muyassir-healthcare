import 'package:flutter_test/flutter_test.dart';

class RegistrationValidator {
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#\$&*~]'))) return false;
    return true;
  }

  static bool passwordsMatch(String p1, String p2) {
    return p1 == p2;
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^[972]\d{7}$').hasMatch(phone);
  }

  static bool isValidStreetNumber(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  static bool isValidHouseNumber(String value) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value);
  }

  static bool isValidAddress(String value) {
    return value.isNotEmpty && value.length <= 100;
  }
}

void main() {
  group('User Registration Validation Tests', () {
    test('Valid email format', () {
      expect(RegistrationValidator.isValidEmail('test@email.com'), true);
    });

    test('Invalid email format', () {
      expect(RegistrationValidator.isValidEmail('testemail.com'), false);
    });

    test('Valid strong password', () {
      expect(
        RegistrationValidator.isValidPassword('Strong1!'),
        true,
      );
    });

    test('Password missing capital letter fails', () {
      expect(
        RegistrationValidator.isValidPassword('weak1!'),
        false,
      );
    });

    test('Password missing number fails', () {
      expect(
        RegistrationValidator.isValidPassword('Weak!!!'),
        false,
      );
    });

    test('Password missing symbol fails', () {
      expect(
        RegistrationValidator.isValidPassword('Weak1234'),
        false,
      );
    });

    test('Passwords must match', () {
      expect(
        RegistrationValidator.passwordsMatch('Test123!', 'Test123!'),
        true,
      );
    });

    test('Passwords mismatch fails', () {
      expect(
        RegistrationValidator.passwordsMatch('Test123!', 'Test123'),
        false,
      );
    });

    test('Valid phone number', () {
      expect(
        RegistrationValidator.isValidPhone('91234567'),
        true,
      );
    });

    test('Invalid phone number', () {
      expect(
        RegistrationValidator.isValidPhone('81234567'),
        false,
      );
    });

    test('Valid street number', () {
      expect(
        RegistrationValidator.isValidStreetNumber('12'),
        true,
      );
    });

    test('Invalid street number (letters)', () {
      expect(
        RegistrationValidator.isValidStreetNumber('12A'),
        false,
      );
    });

    test('Valid house number', () {
      expect(
        RegistrationValidator.isValidHouseNumber('A12'),
        true,
      );
    });

    test('Invalid house number (symbols)', () {
      expect(
        RegistrationValidator.isValidHouseNumber('@12'),
        false,
      );
    });

    test('Valid address length', () {
      expect(
        RegistrationValidator.isValidAddress('Muscat, Oman'),
        true,
      );
    });

    test('Invalid address too long', () {
      expect(
        RegistrationValidator.isValidAddress('A' * 101),
        false,
      );
    });
  });
}
