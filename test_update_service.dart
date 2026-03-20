import 'package:flutter/material.dart';
import 'lib/services/update_service.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Update Service Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => UpdateService.checkForUpdate(context),
                child: const Text('Check for Updates'),
              ),
              const SizedBox(height: 20),
              FutureBuilder<String>(
                future: UpdateService.getCurrentVersion(),
                builder: (context, snapshot) {
                  return Text('Current Version: ${snapshot.data ?? 'Loading...'}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
