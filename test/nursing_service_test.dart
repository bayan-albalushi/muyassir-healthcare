import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserNursingServicesScreen selection logic', () {
    List<Map<String, dynamic>> selectedServices = [];

    final Map<String, dynamic> sampleService = {
      'id': 'service1',
      'name': 'Blood Test',
      'parentService': 'Lab',
      'price': 10.0,
    };

    setUp(() {
      selectedServices.clear();
    });

    test('Add service to selection', () {
      // Simulate selecting the service
      bool exists = selectedServices.any((e) => e['id'] == sampleService['id']);
      if (!exists) selectedServices.add(sampleService);

      expect(selectedServices.length, 1);
      expect(selectedServices[0]['id'], 'service1');
    });

    test('Prevent duplicate service', () {
      // Add first time
      selectedServices.add(sampleService);

      // Try to add again
      bool exists = selectedServices.any((e) => e['id'] == sampleService['id']);
      if (!exists) selectedServices.add(sampleService);

      expect(selectedServices.length, 1); // duplicate should not be added
    });

    test('Remove service from selection', () {
      selectedServices.add(sampleService);

      // Simulate removing the service
      selectedServices.removeWhere((e) => e['id'] == sampleService['id']);

      expect(selectedServices.isEmpty, true);
    });
  });
}
