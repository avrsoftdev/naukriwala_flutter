// lib/screens/applied_seekers_screen.dart
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/seeker_profile_screen.dart';


class AppliedSeekersScreen extends StatelessWidget {
  final List<Map<String, String>> seekers;
  const AppliedSeekersScreen({required this.seekers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Applied Seekers')),
      body: seekers.isEmpty
          ? Center(child: Text('No seekers have applied yet.'))
          : ListView.builder(
              itemCount: seekers.length,
              itemBuilder: (context, index) {
                final seeker = seekers[index];
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: seeker['Photo'] != null
                          ? NetworkImage(seeker['Photo']!)
                          : null,
                      child: seeker['Photo'] == null ? Icon(Icons.person) : null,
                    ),
                    title: Text(seeker['Name'] ?? 'Unnamed'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Experience: ${seeker['Experience'] ?? "-"}'),
                        Text('Specialization: ${seeker['Specialization'] ?? "-"}'),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios),
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