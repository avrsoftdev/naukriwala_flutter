import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      dev.log('[2025-08-09 01:29 IST] No authenticated user', name: 'MyApplicationsScreen');
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'Please log in to view your applications.',
                style: TextStyle(fontSize: 16.sp, color: Colors.red),
              ),
            ),
          ),
        ),
      );
    }
    if (uid != widget.seekerId) {
      dev.log('[2025-08-09 01:29 IST] Unauthorized access: seekerId $uid does not match widget.seekerId ${widget.seekerId}', name: 'MyApplicationsScreen');
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'Unauthorized access. Seeker ID mismatch.',
                style: TextStyle(fontSize: 16.sp, color: Colors.red),
              ),
            ),
          ),
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'My Applications',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22.sp),
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
                padding: EdgeInsets.all(16.w),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by title...',
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.teal, width: 2.w),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                      .where('seekerId', isEqualTo: uid)
                      .orderBy('appliedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                          strokeWidth: 4.w,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      dev.log('[2025-08-09 01:29 IST] Error loading applications for seekerId $uid: ${snapshot.error}', name: 'MyApplicationsScreen');
                      String errorMessage = 'Error loading applications. Please verify Firestore permissions or contact support.';
                      if (snapshot.error is FirebaseException) {
                        final error = snapshot.error as FirebaseException;
                        errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                        if (error.code == 'permission-denied') {
                          errorMessage += '\nEnsure /Applications/{seekerId_jobId} exists with seekerId=$uid.';
                        }
                      }
                      return Center(
                        child: Card(
                          elevation: 4,
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              errorMessage,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      dev.log('[2025-08-09 01:29 IST] No applications found for seekerId $uid', name: 'MyApplicationsScreen');
                      return Center(
                        child: Text(
                          'No applications found.',
                          style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final applications = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['jobTitle'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery);
                    }).toList();

                    return ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final data = applications[index].data() as Map<String, dynamic>;
                        final jobId = data['jobId'] as String? ?? 'Unknown';
                        final title = data['jobTitle'] as String? ?? 'Unknown';
                        final company = data['company'] as String? ?? 'Unknown';
                        final status = data['status'] as String? ?? 'Unknown';
                        final appliedAt = data['appliedAt'] as Timestamp?;
                        final interviewDate = data['interviewDate'] as Timestamp?;
                        final recruiterId = data['recruiterId'] as String? ?? 'Unknown';
                        final appliedAtStr = appliedAt != null ? DateFormat('dd MMM yyyy').format(appliedAt.toDate()) : 'N/A';
                        final interviewDateStr = interviewDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate()) : 'N/A';

                        return AnimatedListItem(
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16.w),
                                title: Text(
                                  title,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 16.sp),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Company: $company', style: TextStyle(fontSize: 14.sp)),
                                    Text('Status: $status', style: TextStyle(fontSize: 14.sp)),
                                    Text('Applied: $appliedAtStr', style: TextStyle(fontSize: 14.sp)),
                                    if (status == 'Interview Scheduled') Text('Interview: $interviewDateStr', style: TextStyle(fontSize: 14.sp)),
                                  ],
                                ),
                                trailing: AnimatedScaleButton(
                                  onPressed: () async {
                                    if (!mounted) {
                                      dev.log('[2025-08-09 01:29 IST] Widget not mounted, cannot start chat', name: 'MyApplicationsScreen');
                                      return;
                                    }
                                    try {
                                      final chatId = await _authService.getChatId(
                                        seekerId: uid,
                                        jobId: jobId,
                                      );
                                      await _authService.sendMessage(
                                        recruiterId,
                                        jobId,
                                        'Hello, I’d like to discuss my application!',
                                      );
                                      if (!mounted) {
                                        dev.log('[2025-08-09 01:29 IST] Widget not mounted after async, cannot navigate', name: 'MyApplicationsScreen');
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            chatId: chatId,
                                            recipientId: recruiterId,
                                            jobId: jobId,
                                          ),
                                        ),
                                      );
                                      dev.log('[2025-08-09 01:29 IST] Navigated to ChatScreen for job $jobId with chatId $chatId', name: 'MyApplicationsScreen');
                                    } catch (e) {
                                      dev.log('[2025-08-09 01:29 IST] Error starting chat for job $jobId: $e', name: 'MyApplicationsScreen', error: e);
                                      if (!mounted) {
                                        dev.log('[2025-08-09 01:29 IST] Widget not mounted, cannot show snackbar', name: 'MyApplicationsScreen');
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Failed to start chat'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.teal,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4.r,
                                          offset: Offset(0, 2.h),
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
                ),
              ),
            ],
          ),
        );
      },
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