import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String jobId;

  const ChatScreen({super.key, required this.chatId, required this.recipientId, required this.jobId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getMessagesStream() {
    return _firestore
        .collection('Messages')
        .doc(widget.chatId)
        .collection('Chats')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _getChatDetails() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'recipientName': 'Unknown', 'jobTitle': 'Unknown', 'company': 'Unknown', 'resumeUrl': null};

    // Determine user role (seeker or recruiter)
    final userDoc = await _firestore.collection('Users').doc(uid).get();
    final isRecruiter = userDoc.exists && userDoc.data()?['role'] == 'recruiter';

    // Fetch recipient name from UsersIndex
    String recipientName = 'Unknown';
    final recipientDoc = await _firestore.collection('UsersIndex').doc(widget.recipientId).get();
    if (recipientDoc.exists) {
      recipientName = recipientDoc.data()?['name'] ?? 'Unknown';
    }

    // Fetch job details
    String jobTitle = 'Unknown';
    String company = 'Unknown';
    String? resumeUrl;
    final appDoc = await _firestore.collection('Applications').doc(isRecruiter ? '${widget.recipientId}_${widget.jobId}' : '${uid}_${widget.jobId}').get();
    if (appDoc.exists) {
      final appData = appDoc.data()!;
      jobTitle = appData['jobTitle'] ?? 'Unknown';
      final jobDoc = await _firestore
          .collection('Recruiters')
          .doc(appData['recruiterId'])
          .collection('Jobs')
          .doc(widget.jobId)
          .get();
      if (jobDoc.exists) {
        company = jobDoc.data()?['company'] ?? 'Unknown';
      }
      if (isRecruiter) {
        resumeUrl = appData['resume']?['cvUrl'] ?? null;
      }
    }

    return {
      'recipientName': recipientName,
      'jobTitle': jobTitle,
      'company': company,
      'resumeUrl': resumeUrl,
    };
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        await _authService.sendMessage(widget.recipientId, widget.jobId, _messageController.text);
        _messageController.clear();
        dev.log('[2025-08-11 16:41 IST] Sent message in chat ${widget.chatId} for job ${widget.jobId}', name: 'ChatScreen');
      } catch (e) {
        dev.log('[2025-08-11 16:41 IST] Error sending message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to send message'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _getChatDetails(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {'recipientName': widget.recipientId, 'jobTitle': 'Unknown'};
            return Text(
              'Chat with ${data['recipientName']} - ${data['jobTitle']}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            );
          },
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  dev.log('Error loading messages for chat ${widget.chatId}: ${snapshot.error}', name: 'ChatScreen');
                  return const Center(
                    child: Text(
                      'Unable to load messages. Please check your permissions or try again.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final isSender = messageData['senderId'] == _auth.currentUser?.uid;
                    return AnimatedListItem(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSender ? Colors.teal.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              messageData['message'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              messageData['timestamp'] != null
                                  ? DateFormat('MMM d, h:mm a').format((messageData['timestamp'] as Timestamp).toDate())
                                  : 'Unknown time',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScaleButton(
                  onPressed: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.teal,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class AnimatedListItem extends StatefulWidget {
  final Widget child;

  const AnimatedListItem({required this.child, super.key});

  @override
  AnimatedListItemState createState() => AnimatedListItemState();
}

class AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
