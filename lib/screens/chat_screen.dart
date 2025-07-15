import 'package:flutter/material.dart';
import 'dart:developer' as dev;

class ChatScreen extends StatelessWidget {
  final String seekerId;
  const ChatScreen({super.key, required this.seekerId});

  @override
  Widget build(BuildContext context) {
    dev.log('Opened ChatScreen for seeker: $seekerId', name: 'ChatScreen');
    return Scaffold(
      appBar: AppBar(title: Text('Chat with Seeker $seekerId')),
      body: const Center(child: Text('Chat functionality to be implemented')),
    );
  }
}