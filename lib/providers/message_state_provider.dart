import 'package:flutter/material.dart';
import '../services/message_state_service.dart';

/// Global singleton instance of MessageStateService
/// Use this to access unread message state from anywhere in the app
final messageStateService = MessageStateService();

/// A provider widget that makes MessageStateService available via context
/// Wrap your app with this to enable automatic unread message tracking
class MessageStateProvider extends StatefulWidget {
  final Widget child;

  const MessageStateProvider({required this.child, super.key});

  @override
  State<MessageStateProvider> createState() => _MessageStateProviderState();
}

class _MessageStateProviderState extends State<MessageStateProvider> {
  @override
  void initState() {
    super.initState();
    // Initialize unread tracking when provider is created
    messageStateService.initializeUnreadTracking();
  }

  @override
  void dispose() {
    // Clean up when provider is disposed
    messageStateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: messageStateService,
      builder: (context, child) {
        return widget.child;
      },
    );
  }
}
