// Reusable chat icon with unread message count badge
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/message_state_provider.dart';

class ChatIconWithBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const ChatIconWithBadge({this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: messageStateService,
      builder: (context, _) {
        final totalUnread = messageStateService.totalUnreadCount;

        dev.log(
          'ChatIconWithBadge rebuild: totalUnread=$totalUnread',
          name: 'ChatIconWithBadge',
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.chat, color: Colors.black87, size: 24.sp),
              padding: EdgeInsets.all(2.w),
              onPressed: onTap,
            ),
            // Show badge only if there are unread messages
            if (totalUnread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      totalUnread > 99 ? '99+' : totalUnread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}