import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import '../../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer' as dev;

class AppliedSeekersScreen extends StatefulWidget {
  final AuthService authService;
  final String jobId;
  final String jobTitle;

  const AppliedSeekersScreen({
    super.key,
    required this.authService,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<AppliedSeekersScreen> createState() => _AppliedSeekersScreenState();
}

class _AppliedSeekersScreenState extends State<AppliedSeekersScreen> {
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  // Specialization options (same as ProfileScreen and AuthService)
  final List<String> specializationOptions = [
    'Computer Science / IT',
    'Electronics / Electrical / Robotics',
    'Mechanical / Civil / Architecture',
    'Business / Finance / Management',
    'Medicine / Healthcare / Pharma',
    'Law / Political Science / Public Administration',
    'Arts / Humanities / Education',
    'Design / Media / Communication',
    'Hotel / Travel / Event Management',
    'Science / Research / Environment',
    'Others',
  ];

  // Skills by specialization (same as ProfileScreen and AuthService)
  final Map<String, List<String>> skillsBySpecialization = {
    'Computer Science / IT': [
      'Java', 'Python', 'C++', 'C#', 'Dart', 'Flutter', 'Android Development',
      'iOS Development', 'React', 'Angular', 'Vue.js', 'Node.js', 'Firebase',
      'AWS', 'Docker', 'Kubernetes', 'SQL', 'MongoDB', 'REST APIs', 'GraphQL',
      'Machine Learning', 'Data Structures & Algorithms', 'DevOps', 'Cybersecurity',
      'System Design',
    ],
    'Electronics / Electrical / Robotics': [
      'Embedded Systems', 'PCB Design', 'VLSI', 'MATLAB', 'Simulink', 'Verilog',
      'FPGA Programming', 'Arduino', 'Raspberry Pi', 'IoT Development',
      'Signal Processing', 'Power Systems', 'Automation', 'SCADA',
    ],
    'Mechanical / Civil / Architecture': [
      'AutoCAD', 'SolidWorks', 'CATIA', 'ANSYS', 'STAAD Pro', 'Revit',
      'Structural Analysis', 'Thermodynamics', 'Manufacturing Processes',
      'Fluid Mechanics', 'Construction Management', 'Urban Planning',
    ],
    'Business / Finance / Management': [
      'Financial Analysis', 'Accounting', 'MS Excel', 'Tally', 'Business Intelligence',
      'SAP', 'QuickBooks', 'Digital Marketing', 'Google Ads', 'SEO',
      'Social Media Marketing', 'Project Management', 'Agile', 'Scrum',
      'Business Strategy', 'Market Research', 'Customer Relationship Management (CRM)',
      'Salesforce',
    ],
    'Medicine / Healthcare / Pharma': [
      'Clinical Research', 'Patient Care', 'Surgical Assistance', 'Nursing Procedures',
      'Medical Coding', 'Public Health', 'Pharmacology', 'First Aid', 'CPR',
      'Health Education', 'Lab Testing', 'Radiology', 'Therapeutic Skills',
    ],
    'Law / Political Science / Public Administration': [
      'Legal Research', 'Case Analysis', 'Contract Drafting', 'Litigation',
      'Legal Compliance', 'Constitutional Law', 'Criminal Law', 'International Law',
      'Arbitration', 'Policy Analysis', 'Public Speaking',
    ],
    'Arts / Humanities / Education': [
      'Creative Writing', 'Content Writing', 'Linguistics', 'Public Speaking',
      'Editing & Proofreading', 'Critical Thinking', 'Classroom Management',
      'Curriculum Development', 'E-Learning Tools', 'Art History', 'Philosophical Analysis',
    ],
    'Design / Media / Communication': [
      'Adobe Photoshop', 'Adobe Illustrator', 'Adobe XD', 'Figma', 'Canva',
      'UI/UX Design', 'Video Editing', '3D Modeling', 'Motion Graphics', 'Photography',
      'Copywriting', 'Branding', 'Social Media Content Creation', 'Typography', 'Storyboarding',
      'Final Cut Pro', 'Lightroom',
    ],
    'Hotel / Travel / Event Management': [
      'Event Planning', 'Hospitality Management', 'Customer Service', 'Bartending',
      'Housekeeping', 'Food & Beverage Service', 'Travel Planning', 'Ticketing & Reservations',
      'Catering Services', 'Inventory Management', 'Public Relations', 'Vendor Management',
    ],
    'Science / Research / Environment': [
      'Laboratory Techniques', 'Statistical Analysis', 'Research Writing', 'Data Collection',
      'Environmental Impact Assessment', 'Geographic Information System (GIS)', 'Microscopy',
      'Chemical Analysis', 'Climate Modeling', 'Bioinformatics',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation',
    ],
  };

  void _addToCalendar(String title, DateTime date) {
    final event = Event(
      title: title,
      description: 'Interview scheduled via Naukariwala',
      location: 'Online/To be decided',
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
    dev.log('[2025-08-07 23:10 IST] Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'AppliedSeekersScreen');
  }

  void _handleAction(String action, String jobId, String seekerId, Map<String, dynamic> applicant) async {
    try {
      // Verify job ownership
      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(recruiterId)
          .collection('Jobs')
          .doc(jobId)
          .get();
      if (!jobDoc.exists || jobDoc.data()?['recruiterId'] != recruiterId) {
        dev.log('[2025-08-11 18:50 IST] Job $jobId not owned by recruiter $recruiterId: ${jobDoc.data()}', name: 'AppliedSeekersScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unauthorized job access'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Verify application exists
      final applicationId = '${seekerId}_${jobId}';
      final appDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc(applicationId)
          .get();
      if (!appDoc.exists || appDoc.data()?['recruiterId'] != recruiterId) {
        dev.log('[2025-08-11 18:50 IST] Application $applicationId not found or not owned by recruiter $recruiterId', name: 'AppliedSeekersScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application does not exist or you lack permission'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (action == 'chat') {
        final participants = [seekerId, recruiterId!];
        participants.sort();
        final chatId = '${participants[0]}_${participants[1]}';
        dev.log('[2025-08-11 18:50 IST] Initiating chat with seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
        await widget.authService.sendMessage(seekerId, jobId, 'Hello! I would like to discuss your application for ${applicant['jobTitle']}.');
        if (!mounted) {
          dev.log('[2025-08-11 18:50 IST] Widget not mounted, cannot navigate to ChatScreen', name: 'AppliedSeekersScreen');
          return;
        }
        dev.log('[2025-08-11 18:50 IST] Navigating to ChatScreen for seeker $seekerId', name: 'AppliedSeekersScreen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              recipientId: seekerId,
              jobId: jobId,
            ),
          ),
        );
      } else if (action == 'schedule') {
        final pickedDate = await showDatePicker(
          // ignore: use_build_context_synchronously
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate != null && mounted) {
          await widget.authService.handleAction(
            action: action,
            jobId: jobId,
            seekerId: seekerId,
            additionalData: {
              'interviewDate': Timestamp.fromDate(pickedDate),
            },
          );
          _addToCalendar('Interview with ${applicant['resume']?['name'] ?? applicant['name'] ?? seekerId}', pickedDate);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Interview scheduled successfully'),
                backgroundColor: Colors.teal,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else if (action == 'download_cv') {
        final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
        final url = resume['cvUrl'] as String? ?? '';
        if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          dev.log('[2025-08-11 18:50 IST] Downloaded CV for seeker $seekerId: $url', name: 'AppliedSeekersScreen');
        } else {
          dev.log('[2025-08-11 18:50 IST] No CV available for seeker $seekerId', name: 'AppliedSeekersScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No CV available'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // Handle other actions (shortlist, reject)
        await widget.authService.handleAction(
          action: action,
          jobId: jobId,
          seekerId: seekerId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${action[0].toUpperCase()}${action.substring(1)} action completed'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      dev.log('[2025-08-11 18:50 IST] Error handling action $action for seeker $seekerId, job $jobId: $e', name: 'AppliedSeekersScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to perform $action: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> applicants) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Applicants'];
      sheet.appendRow(['Name', 'Mobile', 'Specialization', 'Education', 'Experience', 'Skills', 'Status', 'Job Title']);
      for (var a in applicants) {
        final resume = a['resume'] as Map<String, dynamic>? ?? {};
        final specialization = specializationOptions.contains(resume['specialization'] ?? a['specialization'])
            ? (resume['specialization'] ?? a['specialization'] ?? 'N/A')
            : 'N/A';
        final skillsList = (resume['skills'] as List<dynamic>?)?.cast<String>() ?? (a['skills'] is String ? a['skills'].split(', ') : a['skills'] ?? []);
        final validSkills = skillsBySpecialization[specialization] ?? skillsBySpecialization['Others']!;
        final filteredSkills = skillsList.where((skill) => validSkills.contains(skill)).join(', ');
        sheet.appendRow([
          resume['name'] ?? a['name'] ?? '',
          resume['mobileNumber'] ?? a['mobile'] ?? '',
          specialization,
          resume['education'] ?? a['education'] ?? '',
          resume['experience'] ?? a['experience'] ?? '',
          filteredSkills.isEmpty ? 'N/A' : filteredSkills,
          a['status'] ?? '',
          a['jobTitle'] ?? '',
        ]);
      }
      final bytes = excel.encode();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/applicants_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(Uint8List.fromList(bytes!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
      dev.log('[2025-08-07 23:10 IST] Exported applicants to $path', name: 'AppliedSeekersScreen');
    } catch (e) {
      dev.log('[2025-08-07 23:10 IST] Error exporting to Excel: $e', name: 'AppliedSeekersScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error exporting applicants. Check logs.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Applied Seekers'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Please log in to view applicants')),
      );
    }
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Applied Seekers for ${widget.jobTitle}', style: TextStyle(fontSize: 20.sp)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search applicants...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final applicants = await widget.authService.fetchAppliedSeekers();
                          if (applicants.isEmpty) {
                            dev.log('[2025-08-07 23:10 IST] No applicants to export for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No applicants available to export.')),
                              );
                            }
                            return;
                          }
                          await _exportToExcel(applicants);
                        } catch (e) {
                          dev.log('[2025-08-07 23:10 IST] Error exporting applicants for recruiter $recruiterId: $e', name: 'AppliedSeekersScreen', error: e);
                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error exporting applicants. Check logs.')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 220, 217, 226)),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: widget.authService.fetchAppliedSeekers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(strokeWidth: 4.w));
                      }
                      if (snapshot.hasError) {
                        final error = snapshot.error;
                        String errorMessage = 'Error loading applied seekers. Please verify Firestore permissions or contact support.';
                        if (error is FirebaseException) {
                          errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                          if (error.code == 'permission-denied') {
                            errorMessage +=
                                '\nEnsure /Applications/{jobId} exists with recruiterId=$recruiterId and job exists in /Recruiters/$recruiterId/Jobs/{jobId}.';
                            dev.log('[2025-08-07 23:10 IST] Permission denied in fetchAppliedSeekers. Check /Applications/{jobId} and /Recruiters/$recruiterId/Jobs for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                          }
                        }
                        dev.log('[2025-08-07 23:10 IST] Error loading applied seekers for recruiter $recruiterId: $error', name: 'AppliedSeekersScreen', error: error, stackTrace: snapshot.stackTrace);
                        return Center(child: Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.sp)));
                      }
                      final applicants = snapshot.data ?? [];

                      if (applicants.isEmpty) {
                        dev.log('[2025-08-07 23:10 IST] No applicants found for recruiter $recruiterId. Verify /Applications/{jobId} exists with correct recruiterId.', name: 'AppliedSeekersScreen');
                        return const Center(
                          child: Text(
                            'No applied seekers found',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final filteredApplicants = applicants.where((applicant) {
                        final name = (applicant['resume']?['name'] ?? applicant['name'] ?? '').toLowerCase();
                        final jobTitle = (applicant['jobTitle'] ?? '').toLowerCase();
                        return name.contains(_searchQuery) || jobTitle.contains(_searchQuery);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredApplicants.length,
                        itemBuilder: (_, index) {
                          final applicant = filteredApplicants[index];
                          final seekerId = applicant['seekerId'] as String? ?? 'Unknown';
                          final jobId = applicant['jobId'] as String? ?? 'Unknown';
                          final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
                          final specialization = specializationOptions.contains(resume['specialization'] ?? applicant['specialization'])
                              ? (resume['specialization'] ?? applicant['specialization'] ?? 'N/A')
                              : 'N/A';
                          final skillsList = (resume['skills'] as List<dynamic>?)?.cast<String>() ?? (applicant['skills'] is String ? applicant['skills'].split(', ') : applicant['skills'] ?? []);
                          final validSkills = skillsBySpecialization[specialization] ?? skillsBySpecialization['Others']!;
                          final filteredSkills = skillsList.where((skill) => validSkills.contains(skill)).join(', ');

                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.symmetric(vertical: 5.h),
                            child: ListTile(
                              title: Text(resume['name'] ?? applicant['name'] ?? seekerId, style: TextStyle(fontSize: 16.sp)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Job: ${applicant['jobTitle'] ?? jobId}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Name: ${resume['name'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Email: ${resume['email'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Skills: ${filteredSkills.isEmpty ? 'N/A' : filteredSkills}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Specialization: $specialization', style: TextStyle(fontSize: 14.sp)),
                                  Text('Education: ${resume['education'] ?? applicant['education'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Experience: ${resume['experience'] ?? applicant['experience'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                  Text('Status: ${applicant['status'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => _handleAction(action, jobId, seekerId, {'resume': resume, ...applicant}),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'shortlist', child: Text('Shortlist')),
                                  const PopupMenuItem(value: 'reject', child: Text('Reject')),
                                  const PopupMenuItem(value: 'schedule', child: Text('Schedule Interview')),
                                  const PopupMenuItem(value: 'download_cv', child: Text('Download CV')),
                                  const PopupMenuItem(value: 'chat', child: Text('Chat')),
                                ],
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