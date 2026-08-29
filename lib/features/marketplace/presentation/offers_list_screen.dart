import 'package:flutter/material.dart';

class OffersListScreen extends StatelessWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Offers')),
      body: const Center(child: Text('Loan Offers')),
    );
  }
}
