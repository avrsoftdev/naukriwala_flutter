import 'package:flutter/material.dart';
import 'package:naukariwala/screens/seeker_profile_screen.dart'; // ✅ Import SeekerProfileScreen

class ShortlistedSeekersScreen extends StatelessWidget {
  final List<Map<String, String>> seekers;

  const ShortlistedSeekersScreen({Key? key, required this.seekers}) : super(key: key); // ✅ Add key

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shortlisted Seekers')),
      body: seekers.isEmpty
          ? const Center(child: Text('No seekers shortlisted yet.'))
          : ListView.builder(
              itemCount: seekers.length,
              itemBuilder: (context, index) {
                final seeker = seekers[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: seeker['Photo'] != null
                          ? NetworkImage(seeker['Photo']!)
                          : null,
                      child: seeker['Photo'] == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(seeker['Name'] ?? 'Unnamed'),
                    subtitle: Text('Expected CTC: ${seeker['Expected CTC'] ?? "-"}'),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeekerProfileScreen(seeker: seeker),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
