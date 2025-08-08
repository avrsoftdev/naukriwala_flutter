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

    // Fetch recipient name
    String recipientName = 'Unknown';
    final recipientDoc = await _firestore.collection(isRecruiter ? 'Seekers' : 'Recruiters').doc(widget.recipientId).get();
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
        dev.log('[2025-08-09 01:15 IST] Sent message in chat ${widget.chatId} for job ${widget.jobId}', name: 'ChatScreen');
      } catch (e) {
        dev.log('[2025-08-09 01:15 IST] Error sending message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getChatDetails(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {'company': 'Unknown', 'resumeUrl': null};
          return Column(
            children: [
              if (snapshot.hasData && data['resumeUrl'] != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () async {
                      final resumeUrl = data['resumeUrl'] as String?;
                      if (resumeUrl != null) {
                        // Implement URL launch logic if needed
                        dev.log('[2025-08-09 01:15 IST] Attempting to open resume URL: $resumeUrl', name: 'ChatScreen');
                      }
                    },
                    child: Text(
                      'Resume URL: ${data['resumeUrl']}',
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getMessagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      dev.log('[2025-08-09 01:15 IST] Error loading messages for chat ${widget.chatId}: ${snapshot.error}', name: 'ChatScreen', error: snapshot.error);
                      return const Center(child: Text('Error loading messages'));
                    }
                    final messages = snapshot.data?.docs ?? [];
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageData = messages[index].data() as Map<String, dynamic>;
                        final isSender = messageData['senderId'] == _auth.currentUser?.uid;
                        final message = messageData['message'] as String? ?? '';
                        final timestamp = (messageData['timestamp'] as Timestamp?)?.toDate();
                        return AnimatedListItem(
                          child: Align(
                            alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSender ? Colors.teal.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                  if (timestamp != null)
                                    Text(
                                      DateFormat('hh:mm a').format(timestamp),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
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
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// Custom Animated Button Widget
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

// Custom Animated List Item Widget
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