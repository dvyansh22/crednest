import 'package:flutter/material.dart';

class ScoreLoadingScreen extends StatelessWidget {
  const ScoreLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Score Loading')),
      body: const Center(child: Text('Score Loading')),
    );
  }
}
