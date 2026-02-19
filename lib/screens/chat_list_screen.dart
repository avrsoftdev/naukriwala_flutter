// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'dart:developer' as dev;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
  }

  Future<List<QueryDocumentSnapshot>> _getConversations() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final sentMessages = await _firestore
        .collectionGroup('Chats')
        .where('senderId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();

    final receivedMessages = await _firestore
        .collectionGroup('Chats')
        .where('recipientId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();

    final allMessages = [...sentMessages.docs, ...receivedMessages.docs];
    return allMessages;
  }

  Future<Map<String, dynamic>> _getConversationInfo(String chatId, String otherUserId, String jobId) async {
    try {
      // Get the other user's info
      String name = 'Unknown';
      String? photoUrl;

      final userDoc = await _firestore.collection('UsersIndex').doc(otherUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        name = data['name'] ?? data['fullName'] ?? data['companyName'] ?? 'Unknown';
        photoUrl = data['photoUrl'];
      }

      // Get job title
      String jobTitle = 'Unknown Job';
      final jobDoc = await _firestore.collection('Jobs').doc(jobId).get();
      if (jobDoc.exists) {
        jobTitle = jobDoc.get('title') ?? 'Unknown Job';
      }

      return {
        'name': name,
        'photoUrl': photoUrl,
        'jobTitle': jobTitle,
      };
    } catch (e) {
      dev.log('Error getting conversation info: $e', name: 'ChatListScreen');
      return {
        'name': 'Unknown',
        'photoUrl': null,
        'jobTitle': 'Unknown Job',
      };
    }
  }

  // ────────────────────────────── CHAT OPTIONS (DELETE) ──────────────────────────────
  void _showChatOptions(BuildContext context, String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chat Options',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                'Delete Chat',
                style: TextStyle(fontSize: 16.sp, color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatConfirmation(chatId);
              },
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteChatConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat?', style: TextStyle(fontSize: 18.sp)),
        content: Text(
          'This will delete the entire conversation. This action cannot be undone.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(fontSize: 14.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      final messagesCollection = _firestore
          .collection('Messages')
          .doc(chatId)
          .collection('Chats');
      
      final snapshot = await messagesCollection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete the Messages document itself
      await _firestore.collection('Messages').doc(chatId).delete();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat deleted'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the conversation list
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
      dev.log('Error deleting chat: $e', name: 'ChatListScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Text(
          'Messages',
          style: TextStyle(
            color: const Color.fromARGB(221, 12, 20, 108),
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _getConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading conversations',
                style: TextStyle(fontSize: 16.sp),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Start chatting with recruiters or job seekers',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group messages by chatId and get the latest message for each
          final conversations = <String, Map<String, dynamic>>{};
          for (final doc in messages) {
            final data = doc.data() as Map<String, dynamic>;
            final senderId = data['senderId'] as String;
            final recipientId = data['recipientId'] as String;
            final participants = [senderId, recipientId];
            participants.sort();
            final chatId = '${participants[0]}_${participants[1]}';
            final timestamp = data['timestamp'] as Timestamp?;

            if (!conversations.containsKey(chatId) ||
                (timestamp != null && conversations[chatId]!['timestamp'] == null) ||
                (timestamp != null && conversations[chatId]!['timestamp'] != null &&
                 timestamp.compareTo(conversations[chatId]!['timestamp']) > 0)) {
              conversations[chatId] = {
                'chatId': chatId,
                'message': data['message'] ?? '',
                'timestamp': timestamp,
                'senderId': senderId,
                'recipientId': recipientId,
                'jobId': data['jobId'],
                'isRead': data['status'] == 'read',
              };
            }
          }

          final conversationList = conversations.values.toList()
            ..sort((a, b) {
              final aTime = a['timestamp'] as Timestamp?;
              final bTime = b['timestamp'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          return ListView.builder(
            itemCount: conversationList.length,
            itemBuilder: (context, index) {
              final conv = conversationList[index];
              final chatId = conv['chatId'] as String;
              final message = conv['message'] as String;
              final timestamp = conv['timestamp'] as Timestamp?;
              final jobId = conv['jobId'] as String;
              final senderId = conv['senderId'] as String;
              final recipientId = conv['recipientId'] as String;
              final uid = _auth.currentUser?.uid;
              final otherUserId = senderId == uid ? recipientId : senderId;

              return FutureBuilder<Map<String, dynamic>>(
                future: _getConversationInfo(chatId, otherUserId, jobId),
                builder: (context, infoSnapshot) {
                  final info = infoSnapshot.data ?? {'name': 'Loading...', 'photoUrl': null, 'jobTitle': 'Loading...'};
                  final name = info['name'] as String;
                  final photoUrl = info['photoUrl'] as String?;
                  final jobTitle = info['jobTitle'] as String;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24.sp,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: timestamp != null
                        ? Text(
                            DateFormat('MMM d, HH:mm').format(timestamp.toDate()),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatId,
                            recipientId: otherUserId,
                            jobId: jobId,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      _showChatOptions(context, chatId);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}