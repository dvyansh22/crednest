import 'package:flutter/material.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Benefit Ledger')),
      body: const Center(child: Text('Data Benefit Ledger')),
    );
  }
}
