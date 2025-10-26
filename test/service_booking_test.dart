import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('ServiceBooking Model Tests', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Book a service', () async {
      final bookingRef = firestore.collection('hospitalBookings').doc('booking1');

      await bookingRef.set({
        'userId': 'user1',
        'hospitalId': 'hosp1',
        'services': [
          {'serviceId': 'svc1', 'name': 'Blood Test', 'price': 5.0}
        ],
        'total': 5.0,
        'status': 'Pending',
      });

      final snapshot = await bookingRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()?['services'].length, 1);
    });

    test('Update booking status', () async {
      final bookingRef = firestore.collection('hospitalBookings').doc('booking2');
      await bookingRef.set({'status': 'Pending'});

      await bookingRef.update({'status': 'Confirmed'});

      final snapshot = await bookingRef.get();
      expect(snapshot.data()?['status'], 'Confirmed');
    });

    test('Delete a booking', () async {
      final bookingRef = firestore.collection('hospitalBookings').doc('booking3');
      await bookingRef.set({'status': 'Pending'});

      await bookingRef.delete();

      final snapshot = await bookingRef.get();
      expect(snapshot.exists, false);
    });
  });
}
