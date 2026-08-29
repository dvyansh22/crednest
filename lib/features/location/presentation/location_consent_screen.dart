import 'package:flutter/material.dart';

class LocationConsentScreen extends StatelessWidget {
  const LocationConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Consent')),
      body: const Center(child: Text('Location Consent')),
    );
  }
}
