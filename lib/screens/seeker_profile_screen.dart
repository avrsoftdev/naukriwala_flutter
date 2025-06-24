import 'package:flutter/material.dart';

class SeekerProfileScreen extends StatelessWidget {
  final Map<String, String> seeker;

  const SeekerProfileScreen({Key? key, required this.seeker}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${seeker['Name']}'s Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: seeker.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.value),
                  const Divider(),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
