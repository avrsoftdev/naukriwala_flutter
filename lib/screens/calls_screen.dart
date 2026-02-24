// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  void _addToCalendar(String title, DateTime date) {
    final event = Event(
      title: title,
      description: 'Interview scheduled via Naukariwala',
      location: 'Online/To be decided',
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
    dev.log('[2025-08-09 00:33 IST] Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'CallsScreen');
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      dev.log('[2025-08-09 00:33 IST] No authenticated recruiter', name: 'CallsScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view scheduled calls.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          appBar: AppBar(
            title: const Text(
              'Scheduled Calls',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF134B8A),
            elevation: 0,
          ),
          body: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or date',
                      hintStyle: TextStyle(color: Colors.blueGrey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFF0E4A88), width: 1.3),
                      ),
                      prefixIcon: Icon(Icons.search, size: 20.sp, color: const Color(0xFF134B8A)),
                      isDense: true,
                    ),
                    style: theme.textTheme.bodyMedium,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('Applications')
                        .where('recruiterId', isEqualTo: recruiterId)
                        .where('status', isEqualTo: 'Interview Scheduled')
                        .orderBy('interviewDate', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF134B8A)),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        dev.log('[2025-08-09 00:33 IST] Error loading calls for recruiter $recruiterId: ${snapshot.error}', name: 'CallsScreen');
                        String errorMessage = 'Error loading calls: ${snapshot.error}. Contact support.';
                        if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
                          errorMessage = 'Error loading calls: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes';
                        } else if (snapshot.error.toString().contains('PERMISSION_DENIED')) {
                          errorMessage = 'Permission denied: Ensure /Applications documents have recruiterId=$recruiterId and status=Interview Scheduled.';
                        }
                        return _InfoPanel(
                          icon: Icons.error_outline_rounded,
                          title: 'Unable to load scheduled calls',
                          message: errorMessage,
                          background: const Color(0xFFFFF3F2),
                          accent: const Color(0xFFC93C2A),
                        );
                      }
                      final calls = snapshot.data?.docs ?? [];
                      if (calls.isEmpty) {
                        dev.log('[2025-08-09 00:33 IST] No scheduled calls found for recruiter $recruiterId', name: 'CallsScreen');
                        return const _InfoPanel(
                          icon: Icons.calendar_month_outlined,
                          title: 'No calls scheduled yet',
                          message: 'Interviews you schedule from applications will appear here.',
                          background: Color(0xFFEFF5FF),
                          accent: Color(0xFF134B8A),
                        );
                      }

                      final filteredCalls = calls.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['resume']?['name'] ?? data['name'] ?? '').toLowerCase();
                        final date = data['interviewDate'] as Timestamp?;
                        final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date.toDate()).toLowerCase() : '';
                        return name.contains(_searchQuery) || dateStr.contains(_searchQuery);
                      }).toList();

                      if (filteredCalls.isEmpty) {
                        return const _InfoPanel(
                          icon: Icons.search_off_rounded,
                          title: 'No matching calls',
                          message: 'Try another applicant name or date keyword.',
                          background: Color(0xFFF6F8FB),
                          accent: Color(0xFF425466),
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredCalls.length,
                        separatorBuilder: (_, index) => SizedBox(height: 10.h),
                        itemBuilder: (_, index) {
                          final data = filteredCalls[index].data() as Map<String, dynamic>;
                          final seekerId = data['seekerId'] as String? ?? 'Unknown';
                          final jobId = data['jobId'] as String? ?? 'Unknown';
                          final resume = data['resume'] as Map<String, dynamic>? ?? {};
                          final interviewDate = data['interviewDate'] as Timestamp?;
                          final dateStr = interviewDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate()) : 'N/A';

                          return AnimatedListItem(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.r),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFFFFF), Color(0xFFF1F7FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: const Color(0xFF134B8A), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(14.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3EFFF),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: const Icon(Icons.video_call_rounded, color: Color(0xFF134B8A), size: 22),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            resume['name'] ?? 'Unknown Applicant',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF102A43),
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            data['jobTitle'] ?? 'Unknown Job',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: const Color(0xFF334E68),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            dateStr,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: const Color(0xFF486581),
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          Wrap(
                                            spacing: 8.w,
                                            runSpacing: 8.h,
                                            children: [
                                              _InfoChip(label: 'Seeker: $seekerId'),
                                              _InfoChip(label: 'Job: $jobId'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    AnimatedScaleButton(
                                      onPressed: interviewDate != null
                                          ? () => _addToCalendar(
                                                'Interview with ${resume['name'] ?? 'Applicant'} for ${data['jobTitle'] ?? 'Job'}',
                                                interviewDate.toDate(),
                                              )
                                          : null,
                                      child: Container(
                                        padding: EdgeInsets.all(10.w),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12.r),
                                          color: interviewDate != null ? const Color(0xFF0A8F7B) : Colors.grey.shade400,
                                        ),
                                        child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                                      ),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF243B53),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color accent;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.background,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334E68),
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
  final VoidCallback? onPressed;
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
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              _controller.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
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
