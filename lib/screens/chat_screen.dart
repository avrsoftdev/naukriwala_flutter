import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import '../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  bool isNewChat = true;
  Map<String, dynamic>? _chatDetails;
  late Future<void> _initializationFuture = Future.value(); // Default initialized
  bool _showInitialMessagePrompt = false;
  bool? _isRecruiter;

  @override
  void initState() {
    super.initState();
    _determineRole().then((_) {
      setState(() {
        _initializationFuture = _initializeChat(); // Assign after role determination
      });
    }).catchError((e) {
      dev.log('[ChatScreen] Error determining role: $e');
      setState(() {
        _isRecruiter = false; // Default to non-recruiter if role determination fails
        _initializationFuture = _initializeChat(); // Proceed with initialization
      });
    });
  }

  Future<void> _determineRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await _firestore.collection('UsersIndex').doc(uid).get();
        setState(() {
          _isRecruiter = doc.data()?['role'] == 'recruiter';
        });
      } catch (e) {
        dev.log('[ChatScreen] Firestore error in _determineRole: $e');
        setState(() {
          _isRecruiter = false; // Default to non-recruiter on error
        });
      }
    } else {
      setState(() {
        _isRecruiter = false; // Default if no user
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      dev.log('[ChatScreen] Initializing chat ${widget.chatId} with recipientId: ${widget.recipientId}, jobId: ${widget.jobId}');
      await Future.wait([
        _checkChatStatus(),
        _fetchChatDetails(),
      ], eagerError: true);
      if (mounted && isNewChat) {
        setState(() {
          _showInitialMessagePrompt = true;
        });
      }
    } catch (e) {
      dev.log('[ChatScreen] Error initializing chat ${widget.chatId}', error: e);
    }
  }

  Future<void> _checkChatStatus() async {
    try {
      final messagesSnapshot = await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          isNewChat = messagesSnapshot.docs.isEmpty;
          dev.log('[ChatScreen] Chat ${widget.chatId} is ${isNewChat ? 'new' : 'existing'}');
        });
      }
    } catch (e) {
      dev.log('[ChatScreen] Error checking chat status for ${widget.chatId}', error: e);
    }
  }

  Future<void> _fetchChatDetails() async {
    try {
      final details = await _getChatDetails();
      if (mounted) {
        setState(() {
          _chatDetails = details;
          dev.log('[ChatScreen] Fetched chat details for ${widget.chatId}: $details');
        });
      }
    } catch (e) {
      dev.log('[ChatScreen] Error fetching chat details for ${widget.chatId}', error: e);
    }
  }

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
    if (uid == null) {
      dev.log('[ChatScreen] No authenticated user for chat ${widget.chatId}');
      return {'recipientName': 'Unknown', 'company': 'Unknown'};
    }

    String recipientName = 'Unknown';
    String company = 'Unknown';
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        if (_isRecruiter == true) {
          // Recruiter chatting with seeker
          final appDoc = await _firestore.collection('Applications').doc('${widget.recipientId}_${widget.jobId}').get();
          if (appDoc.exists) {
            final resume = appDoc.data()?['resume'] as Map<String, dynamic>? ?? {};
            recipientName = resume['name'] ?? recipientName; // Prioritize resume name
            company = appDoc.data()?['company'] ?? company; // Update company
            dev.log('[ChatScreen] Application data for ${widget.recipientId}_${widget.jobId}: ${appDoc.data()}');
          } else {
            dev.log('[ChatScreen] No application data found for ${widget.recipientId}_${widget.jobId}');
          }
          // Optional check for UsersIndex as secondary fallback
          final seekerDoc = await _firestore.collection('UsersIndex').doc(widget.recipientId).get();
          if (seekerDoc.exists) {
            final data = seekerDoc.data()!;
            recipientName = data['name'] ?? data['fullName'] ?? recipientName;
            dev.log('[ChatScreen] Seeker data from UsersIndex: $data');
          } else {
            dev.log('[ChatScreen] No seeker data found in UsersIndex for ${widget.recipientId}');
          }
        } else {
          // Seeker chatting with recruiter
          final appDoc = await _firestore.collection('Applications').doc('${uid}_${widget.jobId}').get();
          if (appDoc.exists) {
            company = appDoc.data()?['company'] ?? 'Unknown';
            dev.log('[ChatScreen] Fallback company from Applications: $company');
          }
        }
        break; // Exit loop if successful
      } catch (e) {
        retryCount++;
        dev.log('[ChatScreen] Error fetching chat details for ${widget.chatId} (Attempt $retryCount): $e');
        if (retryCount == maxRetries) {
          dev.log('[ChatScreen] Max retries reached, using fallback values');
          return {'recipientName': 'Unknown', 'company': 'Unknown'};
        }
        await Future.delayed(retryDelay * retryCount); // Exponential backoff
      }
    }

    dev.log('[ChatScreen] Final recipient details for ${widget.recipientId}: name=$recipientName, company=$company');
    return {
      'recipientName': recipientName,
      'company': company,
    };
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      dev.log('[ChatScreen] Empty message not sent in chat ${widget.chatId}');
      return;
    }

    try {
      await _authService.sendMessage(widget.recipientId, widget.jobId, message);
      _messageController.clear();
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[ChatScreen] Sent message in chat ${widget.chatId} for job ${widget.jobId}: $message');
    } catch (e) {
      dev.log('[ChatScreen] Error sending message in chat ${widget.chatId}', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _sendInitialMessage() async {
    final initialMessage = 'Hello, let’s discuss your application for "${_chatDetails?['company'] ?? widget.jobId}"!';
    try {
      await _authService.sendMessage(widget.recipientId, widget.jobId, initialMessage);
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[ChatScreen] Sent initial message in chat ${widget.chatId} for job ${widget.jobId}');
    } catch (e) {
      dev.log('[ChatScreen] Error sending initial message in chat ${widget.chatId}', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send initial message'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<void>(
              future: _initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _isRecruiter == null) {
                  return Text(
                    widget.recipientId,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                    overflow: TextOverflow.ellipsis,
                  );
                }
                if (snapshot.hasError || _chatDetails == null) {
                  return Text(
                    widget.recipientId,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                    overflow: TextOverflow.ellipsis,
                  );
                }
                return Text(
                  _isRecruiter! ? _chatDetails!['recipientName'] : _chatDetails!['company'],
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                  overflow: TextOverflow.ellipsis,
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
                child: Stack(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _getMessagesStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          dev.log('[ChatScreen] Error loading messages for chat ${widget.chatId}: ${snapshot.error}');
                          return Center(
                            child: Text(
                              'Unable to load messages. Please check your permissions or try again.',
                              style: TextStyle(color: Colors.red, fontSize: 16.sp),
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
                                margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: isSender ? Colors.teal.shade100 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      messageData['message'] ?? '',
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                    SizedBox(height: 5.h),
                                    Text(
                                      messageData['timestamp'] != null
                                          ? DateFormat('MMM d, h:mm a').format((messageData['timestamp'] as Timestamp).toDate())
                                          : 'Unknown time',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (_showInitialMessagePrompt && isNewChat)
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          color: Colors.white.withValues(alpha: 0.9),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start a new chat with a default message?',
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _sendInitialMessage,
                                    child: Text('Yes', style: TextStyle(fontSize: 14.sp)),
                                  ),
                                  SizedBox(width: 10.w),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showInitialMessagePrompt = false;
                                      });
                                    },
                                    child: Text('No', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.teal, width: 2.w),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    AnimatedScaleButton(
                      onPressed: _sendMessage,
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4.r,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.send, color: Colors.white, size: 24.r),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        child: Container(
          color: Colors.white.withValues(alpha: 0.0), // Added to fix deprecated usage
          child: widget.child,
        ),
      ),
    );
  }
}