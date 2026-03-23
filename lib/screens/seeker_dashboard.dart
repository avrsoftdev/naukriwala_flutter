// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/job_screen.dart';
import 'package:naukariwala/screens/my_applications_screen.dart';
import 'package:naukariwala/screens/notifications_screen.dart';
import 'package:naukariwala/widgets/notification_bell.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:naukariwala/screens/chat_list_screen.dart';
import '../widgets/chat_icon_with_badge.dart';
import 'dart:developer' as dev;
import '../services/update_service.dart';

void main() {
  runApp(const SeekerDashboardApp());
}

class SeekerDashboardApp extends StatelessWidget {
  const SeekerDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title: 'Seeker Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SeekerDashboard(),
        '/login': (context) =>
            const Placeholder(), // Replace with actual login screen
      },
    );
  }
}

class SeekerDashboard extends StatefulWidget {
  final String? seekerName;
  final String? photoUrl;

  const SeekerDashboard({super.key, this.seekerName, this.photoUrl});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  @override
  void initState() {
    super.initState();
    _checkForAppUpdate();
  }

  void _checkForAppUpdate() async {
    // Add a small delay to ensure the widget is fully built
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      UpdateService.checkForUpdate(context);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: const Size(360, 640),
      minTextAdapt: true,
      splitScreenMode: true,
    );
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          dev.log(
            'No user logged in, redirecting to login',
            name: 'SeekerDashboard',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please log in to access the dashboard.',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        // title: Text(
        //   // 'Seeker Dashboard',
        //   // style: TextStyle(
        //   //   color: const Color.fromARGB(221, 12, 20, 108),
        //   //   fontWeight: FontWeight.bold,
        //   //   fontSize: 22.sp,
        //   // ),
        // ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black87, size: 28.sp),
            padding: EdgeInsets.all(2.w),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          NotificationBell(
            isRecruiter: false,
            onTap: () {
              dev.log(
                'Navigating to NotificationsScreen',
                name: 'SeekerDashboard',
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(isRecruiter: false),
                ),
              );
            },
          ),
          ChatIconWithBadge(
            onTap: () {
              dev.log('Navigating to ChatListScreen', name: 'SeekerDashboard');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 18.h),
            children: [
              _buildDrawerHeader(),
              SizedBox(height: 10.h),
              _buildDrawerItem(
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  dev.log(
                    'Navigating to ProfileScreen',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProfileScreen(isRecruiter: false),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work,
                title: 'Search Jobs',
                onTap: () {
                  dev.log(
                    'Navigating to SearchJobScreen',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JobScreen()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work_history_rounded,
                title: 'Applied Jobs',
                onTap: () {
                  dev.log(
                    'Navigating to MyApplicationsScreen',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyApplicationsScreen(
                        seekerId: uid,
                        showAppBar: true,
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.bookmark,
                title: 'Saved Jobs',
                onTap: () {
                  dev.log(
                    'Navigating to Saved Jobs',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JobScreen(
                        isSeekerProfileView: true,
                        showSavedOnly: true,
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.description,
                title: 'Resume',
                onTap: () {
                  dev.log(
                    'Navigating to ResumeBuilderScreen',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResumeBuilderScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.notification_add,
                title: 'Notifications',
                onTap: () {
                  dev.log(
                    'Navigating to NotificationsScreen',
                    name: 'SeekerDashboard',
                  );
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const NotificationsScreen(isRecruiter: false),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () async {
                  dev.log('Logging out', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Logged out successfully',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20.r)),
                  color: Colors.white24,
                ),
                tabs: [
                  _buildTab(Icons.person, 'Profile'),
                  _buildTab(Icons.work, 'Jobs'),
                  _buildTab(Icons.bookmark, 'Saved Jobs'),
                  _buildTab(Icons.work_history_rounded, 'Applications'),
                  _buildTab(Icons.description, 'Resume'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  children: [
                    const ProfileScreen(isRecruiter: false),
                    const JobScreen(isSeekerProfileView: true),
                    const JobScreen(
                      isSeekerProfileView: true,
                      showSavedOnly: true,
                    ),
                    MyApplicationsScreen(seekerId: uid),
                    const ResumeBuilderScreen(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15.sp,
            color: Colors.white70,
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          tileColor: Colors.transparent,
          hoverColor: Colors.white12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final displayName = (widget.seekerName ?? '').trim().isNotEmpty
        ? widget.seekerName!.trim()
        : 'Seeker';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Image.asset(
              'assets/logo.png',
              height: 62.h,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    dev.log('Building tab: $label', name: 'SeekerDashboard');
    return Tab(
      child: Container(
        constraints: BoxConstraints(maxWidth: 120.w),
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: Colors.white),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});

  @override
  _ResumeBuilderScreenState createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  // Form data
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _presentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _headerController = TextEditingController();
  final _summaryController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _hobbiesController = TextEditingController();
  List<Map<String, String>> education = [
    {'institution': '', 'degree': '', 'year': ''},
  ];
  List<Map<String, String>> experience = [
    {'company': '', 'role': '', 'duration': '', 'description': ''},
  ];
  List<Map<String, String>> projects = [
    {'title': '', 'description': '', 'duration': ''},
  ];
  List<String> skills = [''];
  List<Map<String, String>> extraCurricular = [
    {'activity': '', 'description': '', 'duration': ''},
  ];
  List<Map<String, String>> certifications = [
    {'title': '', 'issuer': '', 'year': ''},
    {'title': '', 'issuer': '', 'year': ''},
  ];
  List<Map<String, String>> awards = [
    {'title': '', 'issuer': '', 'year': ''},
    {'title': '', 'issuer': '', 'year': ''},
  ];

  // Add education entry
  void _addEducation() {
    setState(() {
      education.add({'institution': '', 'degree': '', 'year': ''});
    });
  }

  // Add experience entry
  void _addExperience() {
    setState(() {
      experience.add({
        'company': '',
        'role': '',
        'duration': '',
        'description': '',
      });
    });
  }

  // Add project entry
  void _addProject() {
    setState(() {
      projects.add({'title': '', 'description': '', 'duration': ''});
    });
  }

  // Add skill entry
  void _addSkill() {
    setState(() {
      skills.add('');
    });
  }

  // Add extra-curricular activity entry
  void _addExtraCurricular() {
    setState(() {
      extraCurricular.add({'activity': '', 'description': '', 'duration': ''});
    });
  }

  // Add certification entry
  void _addCertification() {
    setState(() {
      certifications.add({'title': '', 'issuer': '', 'year': ''});
    });
  }

  // Add award entry
  void _addAward() {
    setState(() {
      awards.add({'title': '', 'issuer': '', 'year': ''});
    });
  }

  // Generate and download PDF
  Future<void> _downloadResume() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              _headerController.text.isEmpty
                  ? 'Resume'
                  : _headerController.text,
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${_emailController.text.isEmpty ? 'email@example.com' : _emailController.text} | ${_phoneController.text.isEmpty ? 'Phone Number' : _phoneController.text}',
          ),
          pw.Text(
            'Present Address: ${_presentAddressController.text.isEmpty ? 'Present Address' : _presentAddressController.text}',
          ),
          pw.Text(
            'Permanent Address: ${_permanentAddressController.text.isEmpty ? 'Permanent Address' : _permanentAddressController.text}',
          ),
          pw.Divider(height: 20),
          if (_summaryController.text.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(_summaryController.text),
                pw.SizedBox(height: 16),
              ],
            ),
          if (_objectiveController.text.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Objective',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(_objectiveController.text),
                pw.SizedBox(height: 16),
              ],
            ),
          pw.Text(
            'Education',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...education.map(
            (edu) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${edu['institution']!.isEmpty ? 'Institution' : edu['institution']} - ${edu['degree']!.isEmpty ? 'Degree' : edu['degree']}',
                ),
                pw.Text(edu['year']!.isEmpty ? 'Year' : edu['year']!),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Text(
            'Work Experience',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...experience.map(
            (exp) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${exp['company']!.isEmpty ? 'Company' : exp['company']} - ${exp['role']!.isEmpty ? 'Role' : exp['role']}',
                ),
                pw.Text(
                  exp['duration']!.isEmpty ? 'Duration' : exp['duration']!,
                ),
                pw.Text(
                  exp['description']!.isEmpty
                      ? 'Description'
                      : exp['description']!,
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Text(
            'Projects',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...projects.map(
            (proj) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  proj['title']!.isEmpty ? 'Project Title' : proj['title']!,
                ),
                pw.Text(
                  proj['duration']!.isEmpty ? 'Duration' : proj['duration']!,
                ),
                pw.Text(
                  proj['description']!.isEmpty
                      ? 'Description'
                      : proj['description']!,
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Text(
            'Skills',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            children: skills
                .asMap()
                .entries
                .map(
                  (entry) => pw.Text(
                    entry.value.isEmpty
                        ? 'Skill ${entry.key + 1}'
                        : entry.value,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Extra-Curricular Activities',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...extraCurricular.map(
            (ec) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(ec['activity']!.isEmpty ? 'Activity' : ec['activity']!),
                pw.Text(ec['duration']!.isEmpty ? 'Duration' : ec['duration']!),
                pw.Text(
                  ec['description']!.isEmpty
                      ? 'Description'
                      : ec['description']!,
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Text(
            'Certifications',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...certifications.map(
            (cert) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  cert['title']!.isEmpty
                      ? 'Certification Title'
                      : cert['title']!,
                ),
                pw.Text(cert['issuer']!.isEmpty ? 'Issuer' : cert['issuer']!),
                pw.Text(cert['year']!.isEmpty ? 'Year' : cert['year']!),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Text(
            'Awards and Recognitions',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...awards.map(
            (award) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  award['title']!.isEmpty ? 'Award Title' : award['title']!,
                ),
                pw.Text(award['issuer']!.isEmpty ? 'Issuer' : award['issuer']!),
                pw.Text(award['year']!.isEmpty ? 'Year' : award['year']!),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          if (_hobbiesController.text.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Hobbies',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(_hobbiesController.text),
              ],
            ),
        ],
      ),
    );

    Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${_nameController.text}_Resume.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Builder'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Header',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _headerController,
                decoration: const InputDecoration(
                  labelText: 'Resume Header (e.g., Professional Resume)',
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _presentAddressController,
                decoration: const InputDecoration(labelText: 'Present Address'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _permanentAddressController,
                decoration: const InputDecoration(
                  labelText: 'Permanent Address',
                ),
              ),
              const SizedBox(height: 24),

              // Summary
              const Text(
                'Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(
                  labelText: 'Professional Summary',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Objective
              const Text(
                'Objective',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _objectiveController,
                decoration: const InputDecoration(
                  labelText: 'Career Objective',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Education Section
              const Text(
                'Education',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...education.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Institution',
                      ),
                      onChanged: (value) =>
                          education[index]['institution'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Degree'),
                      onChanged: (value) => education[index]['degree'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Year'),
                      onChanged: (value) => education[index]['year'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addEducation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Education'),
              ),
              const SizedBox(height: 24),

              // Work Experience Section
              const Text(
                'Work Experience',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...experience.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Company'),
                      onChanged: (value) =>
                          experience[index]['company'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Role'),
                      onChanged: (value) => experience[index]['role'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Duration (e.g., 2020-2022)',
                      ),
                      onChanged: (value) =>
                          experience[index]['duration'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                      onChanged: (value) =>
                          experience[index]['description'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addExperience,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Experience'),
              ),
              const SizedBox(height: 24),

              // Projects Section
              const Text(
                'Projects',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...projects.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Project Title',
                      ),
                      onChanged: (value) => projects[index]['title'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Duration (e.g., Jan 2023 - Mar 2023)',
                      ),
                      onChanged: (value) => projects[index]['duration'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                      onChanged: (value) =>
                          projects[index]['description'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addProject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Project'),
              ),
              const SizedBox(height: 24),

              // Skills Section
              const Text(
                'Skills',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...skills.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Skill'),
                      onChanged: (value) => skills[index] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addSkill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Skill'),
              ),
              const SizedBox(height: 24),

              // Extra-Curricular Activities Section
              const Text(
                'Extra-Curricular Activities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...extraCurricular.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Activity'),
                      onChanged: (value) =>
                          extraCurricular[index]['activity'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Duration (e.g., 2021-2022)',
                      ),
                      onChanged: (value) =>
                          extraCurricular[index]['duration'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                      onChanged: (value) =>
                          extraCurricular[index]['description'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addExtraCurricular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Activity'),
              ),
              const SizedBox(height: 24),

              // Certifications Section
              const Text(
                'Certifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...certifications.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Certification Title',
                      ),
                      onChanged: (value) =>
                          certifications[index]['title'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Issuer'),
                      onChanged: (value) =>
                          certifications[index]['issuer'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Year'),
                      onChanged: (value) =>
                          certifications[index]['year'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addCertification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Certification'),
              ),
              const SizedBox(height: 24),

              // Awards and Recognitions Section
              const Text(
                'Awards and Recognitions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...awards.asMap().entries.map((entry) {
                int index = entry.key;
                return Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Award Title',
                      ),
                      onChanged: (value) => awards[index]['title'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Issuer'),
                      onChanged: (value) => awards[index]['issuer'] = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Year'),
                      onChanged: (value) => awards[index]['year'] = value,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              ElevatedButton(
                onPressed: _addAward,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Award'),
              ),
              const SizedBox(height: 24),

              // Hobbies
              const Text(
                'Hobbies',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hobbiesController,
                decoration: const InputDecoration(
                  labelText: 'Hobbies (e.g., Reading, Hiking)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Resume Preview
              const Text(
                'Resume Preview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headerController.text.isEmpty
                          ? 'Resume'
                          : _headerController.text,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Your Name'
                          : _nameController.text,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_emailController.text.isEmpty ? 'email@example.com' : _emailController.text} | ${_phoneController.text.isEmpty ? 'Phone Number' : _phoneController.text}',
                    ),
                    Text(
                      'Present Address: ${_presentAddressController.text.isEmpty ? 'Present Address' : _presentAddressController.text}',
                    ),
                    Text(
                      'Permanent Address: ${_permanentAddressController.text.isEmpty ? 'Permanent Address' : _permanentAddressController.text}',
                    ),
                    const Divider(height: 20),
                    if (_summaryController.text.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_summaryController.text),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (_objectiveController.text.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Objective',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_objectiveController.text),
                          const SizedBox(height: 16),
                        ],
                      ),
                    const Text(
                      'Education',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...education.map(
                      (edu) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${edu['institution']!.isEmpty ? 'Institution' : edu['institution']} - ${edu['degree']!.isEmpty ? 'Degree' : edu['degree']}',
                          ),
                          Text(edu['year']!.isEmpty ? 'Year' : edu['year']!),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const Text(
                      'Work Experience',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...experience.map(
                      (exp) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${exp['company']!.isEmpty ? 'Company' : exp['company']} - ${exp['role']!.isEmpty ? 'Role' : exp['role']}',
                          ),
                          Text(
                            exp['duration']!.isEmpty
                                ? 'Duration'
                                : exp['duration']!,
                          ),
                          Text(
                            exp['description']!.isEmpty
                                ? 'Description'
                                : exp['description']!,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const Text(
                      'Projects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...projects.map(
                      (proj) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proj['title']!.isEmpty
                                ? 'Project Title'
                                : proj['title']!,
                          ),
                          Text(
                            proj['duration']!.isEmpty
                                ? 'Duration'
                                : proj['duration']!,
                          ),
                          Text(
                            proj['description']!.isEmpty
                                ? 'Description'
                                : proj['description']!,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: skills
                          .asMap()
                          .entries
                          .map(
                            (entry) => Text(
                              entry.value.isEmpty
                                  ? 'Skill ${entry.key + 1}'
                                  : entry.value,
                              style: const TextStyle(fontSize: 14),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Extra-Curricular Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...extraCurricular.map(
                      (ec) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ec['activity']!.isEmpty
                                ? 'Activity'
                                : ec['activity']!,
                          ),
                          Text(
                            ec['duration']!.isEmpty
                                ? 'Duration'
                                : ec['duration']!,
                          ),
                          Text(
                            ec['description']!.isEmpty
                                ? 'Description'
                                : ec['description']!,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const Text(
                      'Certifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...certifications.map(
                      (cert) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cert['title']!.isEmpty
                                ? 'Certification Title'
                                : cert['title']!,
                          ),
                          Text(
                            cert['issuer']!.isEmpty
                                ? 'Issuer'
                                : cert['issuer']!,
                          ),
                          Text(cert['year']!.isEmpty ? 'Year' : cert['year']!),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const Text(
                      'Awards and Recognitions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...awards.map(
                      (award) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            award['title']!.isEmpty
                                ? 'Award Title'
                                : award['title']!,
                          ),
                          Text(
                            award['issuer']!.isEmpty
                                ? 'Issuer'
                                : award['issuer']!,
                          ),
                          Text(
                            award['year']!.isEmpty ? 'Year' : award['year']!,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    if (_hobbiesController.text.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hobbies',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_hobbiesController.text),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Download Button
              Center(
                child: ElevatedButton(
                  onPressed: _downloadResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Download Resume as PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _presentAddressController.dispose();
    _permanentAddressController.dispose();
    _headerController.dispose();
    _summaryController.dispose();
    _objectiveController.dispose();
    _hobbiesController.dispose();
    super.dispose();
  }
}
