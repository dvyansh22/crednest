import 'package:flutter/material.dart';

class KycStatusScreen extends StatelessWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Status')),
      body: const Center(child: Text('KYC Status')),
    );
  }
}
