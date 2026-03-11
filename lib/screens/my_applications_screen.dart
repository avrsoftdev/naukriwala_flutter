// ignore_for_file: use_build_context_synchronously, deprecated_member_use

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
  final bool showAppBar;

  const MyApplicationsScreen({
    super.key,
    required this.seekerId,
    this.showAppBar = false,
  });

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _searchQuery = '';

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'shortlisted':
        return const Color(0xFF0E9F6E);
      case 'rejected':
        return const Color(0xFFE02424);
      case 'interview scheduled':
        return const Color(0xFF1C64F2);
      case 'applied':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[2025-08-19 04:14 IST] No authenticated user', name: 'MyApplicationsScreen');
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
      dev.log('[2025-08-19 04:14 IST] Unauthorized access: seekerId $uid does not match widget.seekerId ${widget.seekerId}', name: 'MyApplicationsScreen');
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
          appBar: widget.showAppBar
              ? AppBar(
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
                )
              : null,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F7FB), Color(0xFFEAF2FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by title...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: const Color(0xFF1C64F2), width: 1.6.w),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1C64F2)),
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
                      dev.log('[2025-08-19 04:14 IST] Error loading applications for seekerId $uid: ${snapshot.error}', name: 'MyApplicationsScreen');
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
                      dev.log('[2025-08-19 04:14 IST] No applications found for seekerId $uid', name: 'MyApplicationsScreen');
                      return Center(
                        child: Text(
                          'No applications found.',
                          style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final allApplications = snapshot.data!.docs;
                    final applications = allApplications.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['jobTitle'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery);
                    }).toList();

                    final interviewCount = allApplications.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['status'] ?? '').toString().toLowerCase() == 'interview scheduled';
                    }).length;
                    final shortlistedCount = allApplications.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['status'] ?? '').toString().toLowerCase() == 'shortlisted';
                    }).length;

                    if (applications.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching applications found.',
                          style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Total',
                                  value: '${allApplications.length}',
                                  icon: Icons.inventory_2_rounded,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _StatCard(
                                  label: 'Interviews',
                                  value: '$interviewCount',
                                  icon: Icons.event_note_rounded,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _StatCard(
                                  label: 'Shortlisted',
                                  value: '$shortlistedCount',
                                  icon: Icons.verified_rounded,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
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
                              final interviewConfirmationStatus = (data['interviewConfirmationStatus'] as String?) ?? 'pending';

                              return AnimatedListItem(
                                child: _ApplicationCard(
                                  title: title,
                                  company: company,
                                  status: status,
                                  appliedAtStr: appliedAtStr,
                                  interviewDateStr: interviewDateStr,
                                  interviewConfirmationStatus: interviewConfirmationStatus,
                                  statusColor: _statusColor(status),
                                  onChatTap: () async {
                                    if (!mounted) {
                                      dev.log('[2025-08-19 04:14 IST] Widget not mounted, cannot start chat', name: 'MyApplicationsScreen');
                                      return;
                                    }
                                    try {
                                      final chatId = await _authService.getChatId(
                                        seekerId: uid,
                                        jobId: jobId,
                                      );
                                      if (!mounted) {
                                        dev.log('[2025-08-19 04:14 IST] Widget not mounted after async, cannot navigate', name: 'MyApplicationsScreen');
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
                                      dev.log('[2025-08-19 04:14 IST] Navigated to ChatScreen for job $jobId with chatId $chatId', name: 'MyApplicationsScreen');
                                    } catch (e) {
                                      dev.log('[2025-08-19 04:14 IST] Error starting chat for job $jobId: $e', name: 'MyApplicationsScreen', error: e);
                                      if (!mounted) {
                                        dev.log('[2025-08-19 04:14 IST] Widget not mounted, cannot show snackbar', name: 'MyApplicationsScreen');
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to start chat'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          )),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 15.sp, color: color),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String title;
  final String company;
  final String status;
  final String appliedAtStr;
  final String interviewDateStr;
  final String interviewConfirmationStatus;
  final Color statusColor;
  final VoidCallback onChatTap;

  const _ApplicationCard({
    required this.title,
    required this.company,
    required this.status,
    required this.appliedAtStr,
    required this.interviewDateStr,
    required this.interviewConfirmationStatus,
    required this.statusColor,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: statusColor.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.apartment_rounded, size: 15.sp, color: Colors.grey.shade600),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    company,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 15.sp, color: Colors.grey.shade600),
                SizedBox(width: 6.w),
                Text(
                  'Applied $appliedAtStr',
                  style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700),
                ),
              ],
            ),
            if (status.toLowerCase() == 'interview scheduled') ...[
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.video_camera_front_rounded, color: Color(0xFF1D4ED8), size: 17),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Interview: $interviewDateStr',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      () {
                        final s = interviewConfirmationStatus.trim();
                        final label = s.isEmpty ? 'Pending' : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
                        return 'Confirmation: $label';
                      }(),
                      style: TextStyle(fontSize: 12.sp, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedScaleButton(
                onPressed: onChatTap,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        'Message',
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
