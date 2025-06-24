// lib/screens/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'recruiter_signup_screen.dart';
import 'seeker_signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Your Role")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.business),
              label: Text("I'm a Recruiter"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecruiterSignupScreen(),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.person),
              label: Text("I'm a Seeker"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeekerSignupScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
