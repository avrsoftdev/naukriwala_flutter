import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/message_state_provider.dart';

/// A widget that displays a dynamic unread count badge for a specific chat
/// Updates reactively when the total unread count changes
class ChatUnreadBadge extends StatelessWidget {
  final String chatId;
  final bool compact;

  const ChatUnreadBadge({
    required this.chatId,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: messageStateService,
      builder: (context, _) {
        final unreadCount = messageStateService.getUnreadCountForChat(chatId);

        // Hide badge if no unread messages
        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        if (compact) {
          // Compact version - small badge
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          // Standard badge
          return Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      },
    );
  }
}
