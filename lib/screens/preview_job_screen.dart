import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PreviewJobScreen extends StatelessWidget {
  final Map<String, dynamic> jobData;

  const PreviewJobScreen({super.key, required this.jobData});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Preview Job',
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
          body: SingleChildScrollView( // Added SingleChildScrollView
            padding: EdgeInsets.all(16.w),
            child: Card(
              elevation: 4,
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
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Minimize Column height
                  children: [
                    _buildField('Job Title', jobData['title']?.toString() ?? 'N/A'),
                    _buildField('Company Name', jobData['company']?.toString() ?? 'N/A'),
                    _buildField('Location', jobData['location']?.toString() ?? 'N/A'),
                    _buildField('Experience Required', jobData['experience']?.toString() ?? 'N/A'),
                    _buildField('Salary Range', jobData['salary']?.toString() ?? 'N/A'),
                    _buildField('Job Type', jobData['jobType']?.toString() ?? 'N/A'),
                    _buildField('Required Skills', (jobData['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A'),
                    _buildField('Education Required', jobData['education']?.toString() ?? 'N/A'),
                    _buildField('Specialization', jobData['specialization']?.toString() ?? 'N/A'),
                    _buildField('Job Description', jobData['description']?.toString() ?? 'N/A', maxLines: 4),
                    SizedBox(height: 16.h), // Replaced Spacer with fixed spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: AnimatedScaleButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey.shade600, Colors.grey.shade800],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4.r,
                                    offset: Offset(0, 2.h),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AnimatedScaleButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade700, Colors.teal.shade400],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4.r,
                                    offset: Offset(0, 2.h),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Post Job',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Custom Animated Button Widget (unchanged)
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