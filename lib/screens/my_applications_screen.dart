
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'dart:developer' as dev;

class MyApplicationsScreen extends StatefulWidget {
  final String seekerId;
  const MyApplicationsScreen({super.key, required this.seekerId});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[2025-08-07 23:13 IST] No authenticated user', name: 'MyApplicationsScreen');
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Please log in to view your applications.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        ),
      );
    }
    if (uid != widget.seekerId) {
      dev.log('[2025-08-07 23:13 IST] Unauthorized access: seekerId $uid does not match widget.seekerId ${widget.seekerId}', name: 'MyApplicationsScreen');
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Unauthorized access. Seeker ID mismatch.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Applications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by title...',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('Applications')
                  .doc(uid)
                  .collection('AppliedJobs')
                  .orderBy('appliedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  dev.log('[2025-08-07 23:13 IST] Error loading applications for seekerId $uid: ${snapshot.error}', name: 'MyApplicationsScreen');
                  return Center(
                    child: Card(
                      elevation: 4,
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  dev.log('[2025-08-07 23:13 IST] No applications found for seekerId: $uid', name: 'MyApplicationsScreen');
                  return const Center(
                    child: Text(
                      'No jobs applied yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['jobTitle'] ?? '').toLowerCase();
                  return title.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final job = docs[index].data() as Map<String, dynamic>;
                    final appliedAt = job['appliedAt'] != null
                        ? (job['appliedAt'] as Timestamp).toDate()
                        : null;
                    final interviewDate = job['interviewDate'] != null
                        ? (job['interviewDate'] as Timestamp).toDate()
                        : null;
                    final appliedDate = appliedAt != null
                        ? DateFormat('dd MMM yyyy').format(appliedAt)
                        : 'N/A';
                    final interviewDateStr = interviewDate != null
                        ? DateFormat('dd MMM yyyy').format(interviewDate)
                        : null;
                    final jobId = job['jobId'] as String? ?? 'Unknown';
                    final recruiterId = job['recruiterId'] as String? ?? 'Unknown';

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('Recruiters')
                          .doc(job['recruiterId'])
                          .collection('Jobs')
                          .doc(job['jobId'])
                          .get(),
                      builder: (context, jobSnapshot) {
                        String companyName = 'Unknown Company';
                        if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
                          final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;
                          companyName = jobData['company'] ?? 'Unknown Company';
                        }

                        return AnimatedListItem(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16.0),
                                leading: const Icon(Icons.work_outline, color: Colors.teal, size: 28),
                                title: Text(
                                  '${job['jobTitle']} - $companyName',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Applied on: $appliedDate', style: TextStyle(color: Colors.grey.shade600)),
                                    Text('Status: ${job['status'] ?? 'Applied'}', style: TextStyle(color: Colors.grey.shade600)),
                                    if (interviewDateStr != null)
                                      Text('Interview: $interviewDateStr', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                                trailing: AnimatedScaleButton(
                                  onPressed: () {
                                    if (!mounted) {
                                      dev.log('[2025-08-07 23:13 IST] Widget not mounted, cannot start chat', name: 'MyApplicationsScreen');
                                      return;
                                    }
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(context);
                                    final chatId = [uid, recruiterId].join('_').split('_')..sort();
                                    final normalizedChatId = '${chatId[0]}_${chatId[1]}';
                                    dev.log('[2025-08-07 23:13 IST] Initiating chat with chatId $normalizedChatId for job $jobId', name: 'MyApplicationsScreen');
                                    _authService
                                        .sendMessage(recruiterId, jobId, 'Hello, I’d like to discuss my application!')
                                        .then((_) {
                                      if (mounted) {
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              chatId: normalizedChatId,
                                              recipientId: recruiterId,
                                              jobId: jobId,
                                            ),
                                          ),
                                        );
                                        dev.log('[2025-08-07 23:13 IST] Navigated to ChatScreen for job $jobId', name: 'MyApplicationsScreen');
                                      }
                                    }).catchError((e) {
                                      dev.log('[2025-08-07 23:13 IST] Error starting chat for job $jobId: $e', name: 'MyApplicationsScreen', error: e);
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: const Text('Failed to start chat'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.teal,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.chat, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
