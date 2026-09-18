// ponytail: minimal app shell; add state management (Bloc/Riverpod) when screen count exceeds 5.
import 'package:flutter/material.dart';

void main() {
  runApp(const DrugTimeApp());
}

class DrugTimeApp extends StatelessWidget {
  const DrugTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DrugTime',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF009688)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'DrugTime - Sẵn sàng cho Sprint 1',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
