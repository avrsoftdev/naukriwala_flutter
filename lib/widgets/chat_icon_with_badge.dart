// Reusable chat icon with unread message count badge
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatIconWithBadge extends StatefulWidget {
  final VoidCallback? onTap;

  const ChatIconWithBadge({this.onTap, super.key});

  @override
  State<ChatIconWithBadge> createState() => _ChatIconWithBadgeState();
}

class _ChatIconWithBadgeState extends State<ChatIconWithBadge> {
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get all unread messages for this user
      final unreadMessages = await FirebaseFirestore.instance
          .collectionGroup('Chats')
          .where('recipientId', isEqualTo: uid)
          .where('status', isEqualTo: 'sent')
          .get();

      // Count unique conversations
      final chatIds = <String>{};
      for (final doc in unreadMessages.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final recipientId = data['recipientId'] as String;
        final participants = [senderId, recipientId];
        participants.sort();
        final chatId = '${participants[0]}_${participants[1]}';
        chatIds.add(chatId);
      }

      setState(() {
        _unreadCount = chatIds.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.chat, color: Colors.black87, size: 24.sp),
          padding: EdgeInsets.all(2.w),
          onPressed: widget.onTap,
        ),
        if (!_isLoading && _unreadCount > 0)
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
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}