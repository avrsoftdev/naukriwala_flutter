import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String seekerId;
  const ChatScreen({super.key, required this.seekerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with Seeker')),
      body: Center(
        child: Text('Chat UI for $seekerId will go here'),
      ),
    );
  }
}
