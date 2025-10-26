import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Medicine Model Tests', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Add a medicine', () async {
      final medicineRef = firestore.collection('medicines').doc('med1');

      await medicineRef.set({
        'name': 'Paracetamol',
        'price': 0.500,
        'stock': 10,
      });

      final snapshot = await medicineRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()?['name'], 'Paracetamol');
      expect(snapshot.data()?['price'], 0.500);
    });

    test('Update a medicine stock', () async {
      final medicineRef = firestore.collection('medicines').doc('med2');
      await medicineRef.set({'name': 'Ibuprofen', 'stock': 5});

      await medicineRef.update({'stock': 8});

      final snapshot = await medicineRef.get();
      expect(snapshot.data()?['stock'], 8);
    });

    test('Delete a medicine', () async {
      final medicineRef = firestore.collection('medicines').doc('med3');
      await medicineRef.set({'name': 'Aspirin'});

      await medicineRef.delete();

      final snapshot = await medicineRef.get();
      expect(snapshot.exists, false);
    });
  });
}
