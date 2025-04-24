import 'package:flutter/material.dart';
import 'widgets/record_button.dart';   // <-- add this import

void main() => runApp(const Hum2TabsApp());

class Hum2TabsApp extends StatelessWidget {
  const Hum2TabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hum2Tabs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hum2Tabs – Sprint 1'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: RecordButton(),        // <-- our mic / stop button
      ),
    );
  }
}
