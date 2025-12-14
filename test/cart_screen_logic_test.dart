import 'package:flutter_test/flutter_test.dart';

class CartLogic {
  static double calculateTotal(List<Map<String, dynamic>> cartItems) {
    double total = 0;

    for (final item in cartItems) {
      final price = (item['price'] ?? 0).toDouble();
      final providerType = item['providerType'];
      final quantity = item['quantity'] ?? 1;

      if (providerType == "pharmacy") {
        total += price * quantity;
      } else {
        total += price; // hospital/lab are fixed price per item
      }
    }

    return total;
  }

  static bool hasWaitingApproval(List<Map<String, dynamic>> cartItems) {
    return cartItems.any((e) => (e['status'] ?? '') == 'waitingApproval');
  }

  static bool needsPrescription(Map<String, dynamic> item) {
    if (item['providerType'] != "pharmacy") return false;

    final type = item['prescriptionType']?.toString() ?? 'none';
    final qty = item['quantity'] ?? 1;

    final limit = item['prescriptionLimit'] is int
        ? item['prescriptionLimit'] as int
        : int.tryParse(item['prescriptionLimit']?.toString() ?? '0') ?? 0;

    return type == "required" || (type == "byQuantity" && qty > limit);
  }

  static bool missingPrescription(List<Map<String, dynamic>> cartItems) {
    for (final item in cartItems) {
      if (item['providerType'] != "pharmacy") continue;

      final required = needsPrescription(item);

      final presList = (item['prescriptions'] is List)
          ? List<String>.from(item['prescriptions'])
          : <String>[];

      if (required && presList.isEmpty) return true;
    }
    return false;
  }

  static bool canCheckout(List<Map<String, dynamic>> cartItems) {
    final hasPharmacy = cartItems.any((e) => e['providerType'] == "pharmacy");
    final hasHospital = cartItems.any((e) => e['providerType'] == "hospital");
    final hasLab = cartItems.any((e) => e['providerType'] == "lab");

    // نفس شرطك: ما مسموح خلط أنواع مزودين
    if ((hasPharmacy && hasHospital) ||
        (hasPharmacy && hasLab) ||
        (hasHospital && hasLab)) {
      return false;
    }
    return true;
  }

  static String convertToArabicDigits(String value) {
    const arabicDigits = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return value.split('').map((c) {
      if (RegExp(r'\d').hasMatch(c)) return arabicDigits[int.parse(c)];
      return c;
    }).join();
  }

  static String formatPrice(double price, {String langCode = 'en', int decimals = 3}) {
    final str = price.toStringAsFixed(decimals);
    return (langCode == 'ar') ? convertToArabicDigits(str) : str;
  }
}

void main() {
  group('Cart Screen Logic Tests (No Firebase)', () {
    late List<Map<String, dynamic>> cartItems;

    setUp(() {
      cartItems = [];
    });

    test('Calculate total for pharmacy uses price * quantity', () {
      cartItems = [
        {'providerType': 'pharmacy', 'price': 0.500, 'quantity': 3},
      ];

      final total = CartLogic.calculateTotal(cartItems);
      expect(total, 1.5);
    });

    test('Calculate total for hospital/lab uses fixed price (no quantity multiply)', () {
      cartItems = [
        {'providerType': 'hospital', 'price': 5.0, 'quantity': 10},
        {'providerType': 'lab', 'price': 3.0, 'quantity': 99},
      ];

      final total = CartLogic.calculateTotal(cartItems);
      expect(total, 8.0);
    });

    test('Detect waitingApproval status disables checkout', () {
      cartItems = [
        {'providerType': 'pharmacy', 'price': 1.0, 'quantity': 1, 'status': 'waitingApproval'},
      ];

      final hasWait = CartLogic.hasWaitingApproval(cartItems);
      expect(hasWait, true);
    });

    test('Prescription required when type = required and prescriptions empty', () {
      cartItems = [
        {
          'providerType': 'pharmacy',
          'price': 1.0,
          'quantity': 1,
          'prescriptionType': 'required',
          'prescriptions': [],
        }
      ];

      final missing = CartLogic.missingPrescription(cartItems);
      expect(missing, true);
    });

    test('Prescription required when byQuantity and quantity > limit', () {
      cartItems = [
        {
          'providerType': 'pharmacy',
          'price': 1.0,
          'quantity': 5,
          'prescriptionType': 'byQuantity',
          'prescriptionLimit': 2,
          'prescriptions': [],
        }
      ];

      expect(CartLogic.needsPrescription(cartItems.first), true);
      expect(CartLogic.missingPrescription(cartItems), true);
    });

    test('If prescription uploaded then missingPrescription is false', () {
      cartItems = [
        {
          'providerType': 'pharmacy',
          'price': 1.0,
          'quantity': 5,
          'prescriptionType': 'byQuantity',
          'prescriptionLimit': 2,
          'prescriptions': ['https://x/prescription.pdf'],
        }
      ];

      final missing = CartLogic.missingPrescription(cartItems);
      expect(missing, false);
    });

    test('Reject checkout when cart has mixed provider types', () {
      cartItems = [
        {'providerType': 'pharmacy', 'price': 1.0, 'quantity': 1},
        {'providerType': 'lab', 'price': 2.0, 'quantity': 1},
      ];

      final ok = CartLogic.canCheckout(cartItems);
      expect(ok, false);
    });

    test('Allow checkout when only one provider type exists', () {
      cartItems = [
        {'providerType': 'lab', 'price': 2.0, 'quantity': 1},
        {'providerType': 'lab', 'price': 3.0, 'quantity': 1},
      ];

      final ok = CartLogic.canCheckout(cartItems);
      expect(ok, true);
    });

    test('Format price in Arabic digits', () {
      final formatted = CartLogic.formatPrice(12.345, langCode: 'ar', decimals: 3);
      expect(formatted, '١٢.٣٤٥');
    });

    test('Format price in English digits', () {
      final formatted = CartLogic.formatPrice(12.345, langCode: 'en', decimals: 3);
      expect(formatted, '12.345');
    });
  });
}
