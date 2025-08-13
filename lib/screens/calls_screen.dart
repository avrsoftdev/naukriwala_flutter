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
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Scheduled Calls',
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
          body: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by name or date...',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Colors.teal, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
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
                      final calls = snapshot.data?.docs ?? [];
                      if (calls.isEmpty) {
                        dev.log('[2025-08-09 00:33 IST] No scheduled calls found for recruiter $recruiterId', name: 'CallsScreen');
                        return const Center(
                          child: Text(
                            'No scheduled calls found.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      final filteredCalls = calls.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['resume']?['name'] ?? data['name'] ?? '').toLowerCase();
                        final date = data['interviewDate'] as Timestamp?;
                        final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date.toDate()).toLowerCase() : '';
                        return name.contains(_searchQuery) || dateStr.contains(_searchQuery);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredCalls.length,
                        itemBuilder: (_, index) {
                          final data = filteredCalls[index].data() as Map<String, dynamic>;
                          final seekerId = data['seekerId'] as String? ?? 'Unknown';
                          final jobId = data['jobId'] as String? ?? 'Unknown';
                          final resume = data['resume'] as Map<String, dynamic>? ?? {};
                          final interviewDate = data['interviewDate'] as Timestamp?;
                          final dateStr = interviewDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate()) : 'N/A';

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
                                  leading: const Icon(Icons.event, color: Colors.teal, size: 28),
                                  title: Text(
                                    resume['name'] ?? 'Unknown Applicant',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Job: ${data['jobTitle'] ?? 'Unknown Job'}'),
                                      Text('Date: $dateStr'),
                                      Text('Seeker ID: $seekerId'),
                                      Text('Job ID: $jobId'),
                                    ],
                                  ),
                                  trailing: AnimatedScaleButton(
                                    onPressed: interviewDate != null
                                        ? () => _addToCalendar(
                                              'Interview with ${resume['name'] ?? 'Applicant'} for ${data['jobTitle'] ?? 'Job'}',
                                              interviewDate.toDate(),
                                            )
                                        : null,
                                    child: Container(
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: interviewDate != null ? Colors.teal : Colors.grey,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
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
          ),
        );
      },
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