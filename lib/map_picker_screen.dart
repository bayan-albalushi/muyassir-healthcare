import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPickerScreen extends StatelessWidget {
  final double lat;
  final double lng;

  const MapPickerScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  // ✅ فتح Google Maps على الإحداثيات
  Future<void> _openGoogleMaps() async {
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              "Open Google Maps to pick your location",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.location_on),
              label: const Text("Open in Google Maps"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
