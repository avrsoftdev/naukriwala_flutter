// ignore_for_file: unnecessary_brace_in_string_interps, use_build_context_synchronously

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
import 'package:naukariwala/screens/seeker_details_screen.dart';
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
  final Map<String, String?> _photoUrlCache = {};

  final List<String> experienceOptions = [
    'Fresher',
    '1-2 years',
    '2-4 years',
    '4-6 years',
    '6-8 years',
    '8-10 years',
    '10-12 years',
    '12+ years',
  ];

  final List<String> educationOptions = [
    'High School (Class 10)',
    'Senior Secondary (Class 12)',
    'Diploma',
    'Associate Degree',
    'Bachelor\'s Degree',
    'Postgraduate Diploma',
    'Master\'s Degree',
    'Doctorate/PhD',
    'Professional Certification',
    'Other',
  ];

  final List<String> specializationOptions = [
    'Computer Science / IT',
    'Artificial Intelligence / Machine Learning / Data Science',
    'Electronics / Electrical / Robotics',
    'Mechanical / Civil / Architecture',
    'Aerospace / Aeronautical / Automotive',
    'Chemical / Petroleum / Environmental',
    'Biomedical / Biotechnology / Nanotechnology',
    'Business / Finance / Management',
    'Medicine / Healthcare / Pharma',
    'Physiotherapy / Public Health / Veterinary Science',
    'Law / Political Science / Public Administration',
    'Arts / Humanities / Education',
    'Design / Media / Communication',
    'Hotel / Travel / Event Management',
    'Science / Research / Environment',
    'Astronomy / Astrophysics / Planetary Science',
    'Vocational/Domestic Services',
    'Others',
  ];

  final Map<String, List<String>> skillsBySpecialization = {
    'Computer Science / IT': [
      'Java', 'Python', 'C++', 'C#', 'Dart', 'Flutter', 'Android Development',
      'iOS Development', 'React', 'Angular', 'Vue.js', 'Node.js', 'Firebase',
      'AWS', 'Azure', 'Google Cloud', 'Docker', 'Kubernetes', 'SQL', 'NoSQL',
      'MongoDB', 'REST APIs', 'GraphQL', 'Data Structures & Algorithms', 'DevOps',
      'Cybersecurity', 'System Design', 'Web Development', 'Unit Testing', 'Git',
      'Jenkins', 'Agile Methodologies',
    ],
    'Artificial Intelligence / Machine Learning / Data Science': [
      'Python', 'R', 'TensorFlow', 'PyTorch', 'Keras', 'Scikit-learn', 'Pandas',
      'NumPy', 'Data Visualization', 'Tableau', 'Power BI', 'Big Data', 'Hadoop',
      'Spark', 'Deep Learning', 'Natural Language Processing', 'Computer Vision',
      'Statistical Modeling', 'Data Mining', 'Machine Learning Algorithms',
      'Time Series Analysis', 'SQL', 'Feature Engineering', 'Model Deployment',
      'Cloud Computing (AWS, Azure)', 'Jupyter Notebooks',
    ],
    'Electronics / Electrical / Robotics': [
      'Embedded Systems', 'PCB Design', 'VLSI', 'MATLAB', 'Simulink', 'Verilog',
      'VHDL', 'FPGA Programming', 'Arduino', 'Raspberry Pi', 'IoT Development',
      'Signal Processing', 'Power Systems', 'Control Systems', 'SCADA', 'PLC Programming',
      'Circuit Design', 'Robotics Programming', 'Sensor Integration', 'Microcontrollers',
      'Power Electronics', 'Automation', 'Proteus', 'Multisim',
      'Calculus', 'Algebra', 'Differential Equations', 'Electromagnetism',
      'Circuit Theory', 'Ohm\'s Law', 'Basic Electrical Components',
      'Power Systems Design', 'C Programming', 'C++ Programming', 'Python Programming',
      'SPICE Simulation', 'System Design & Analysis', 'Troubleshooting Electronics',
      'Microprocessor Design', 'Hardware Applications',
      'Problem-Solving', 'Technical Communication', 'Team Collaboration',
      'Attention to Detail', 'Critical Thinking', 'Creativity in Design',
    ],
    'Mechanical / Civil / Architecture': [
      'AutoCAD', 'SolidWorks', 'CATIA', 'ANSYS', 'STAAD Pro', 'Revit', 'ETABS',
      'Structural Analysis', 'Thermodynamics', 'Fluid Mechanics', 'Manufacturing Processes',
      'Finite Element Analysis', 'Construction Management', 'Urban Planning', 'BIM (Building Information Modeling)',
      'Geotechnical Engineering', 'Hydraulics', 'Surveying', 'CAD/CAM', 'HVAC Design',
      '3D Printing', 'Project Estimation', 'Material Science',
    ],
    'Aerospace / Aeronautical / Automotive': [
      'CATIA', 'ANSYS Fluent', 'SolidWorks', 'MATLAB', 'Aerodynamics', 'Propulsion Systems',
      'Flight Mechanics', 'Automotive Design', 'Vehicle Dynamics', 'CFD (Computational Fluid Dynamics)',
      'Finite Element Analysis', 'Aerospace Materials', 'Avionics', 'AutoCAD', 'Structural Design',
      'Engine Testing', 'CAD/CAM', 'Thermal Analysis', 'Manufacturing Processes', 'Simulation Tools',
    ],
    'Chemical / Petroleum / Environmental': [
      'Aspen HYSYS', 'MATLAB', 'Chemical Process Design', 'Petroleum Refining', 'Environmental Impact Assessment',
      'Waste Management', 'Water Treatment', 'Process Simulation', 'Thermodynamics', 'Mass Transfer',
      'Heat Transfer', 'Piping Design', 'HSE (Health, Safety, Environment)', 'Geochemical Analysis',
      'Reservoir Engineering', 'Pollution Control', 'Sustainable Design', 'Chemical Safety',
    ],
    'Biomedical / Biotechnology / Nanotechnology': [
      'Bioinformatics', 'Molecular Biology', 'Genetic Engineering', 'Cell Culture', 'PCR Techniques',
      'Biomedical Instrumentation', 'Biomaterials', 'Nanoparticle Synthesis', 'Microscopy', 'Lab Techniques',
      'Proteomics', 'Genomics', 'Biomedical Imaging', 'Tissue Engineering', 'Biosensors', 'MATLAB',
      'Biostatistics', 'Drug Delivery Systems', 'Nanofabrication', 'Biochemical Analysis',
    ],
    'Business / Finance / Management': [
      'Financial Analysis', 'Accounting', 'Tally ERP', 'QuickBooks', 'MS Excel', 'SAP FICO',
      'Financial Modeling', 'Taxation', 'Auditing', 'Cost Accounting', 'Business Strategy',
      'Market Research', 'Entrepreneurship Development', 'Investment Analysis', 'Risk Management',
      'Corporate Finance', 'Budgeting', 'Financial Reporting', 'Business Plan Development',
      'Venture Capital Analysis', 'GST Compliance', 'Digital Marketing', 'Google Ads', 'SEO',
      'Social Media Marketing', 'Project Management', 'Agile', 'Scrum', 'Salesforce',
      'Customer Relationship Management (CRM)',
    ],
    'Medicine / Healthcare / Pharma': [
      'Clinical Diagnosis', 'Patient Care', 'Surgical Assistance', 'Nursing Procedures', 'Pharmacology',
      'Medical Coding', 'First Aid', 'CPR', 'Dental Procedures', 'Orthodontics', 'Prescription Management',
      'Clinical Pharmacy', 'Drug Dispensing', 'Wound Care', 'Vital Signs Monitoring', 'Patient Counseling',
      'Anesthesia Administration', 'Infection Control', 'Medical Ethics', 'Health Education',
    ],
    'Physiotherapy / Public Health / Veterinary Science': [
      'Manual Therapy', 'Exercise Prescription', 'Electrotherapy', 'Rehabilitation Techniques',
      'Epidemiology', 'Public Health Policy', 'Health Program Management', 'Community Health',
      'Veterinary Diagnosis', 'Animal Surgery', 'Veterinary Pharmacology', 'Animal Husbandry',
      'Biostatistics', 'Health Promotion', 'Injury Assessment', 'Kinesiology', 'Vaccination Protocols',
      'Zoonotic Disease Management', 'Public Health Surveillance',
    ],
    'Law / Political Science / Public Administration': [
      'Legal Research', 'Case Analysis', 'Contract Drafting', 'Litigation', 'Legal Writing',
      'Constitutional Law Analysis', 'International Law Compliance', 'Arbitration', 'Mediation',
      'Intellectual Property Law', 'Criminal Law Practice', 'Corporate Law', 'Legal Compliance',
      'Courtroom Advocacy', 'Policy Analysis', 'Public Speaking', 'Governance Studies',
      'International Diplomacy', 'Conflict Resolution', 'Public Policy Formulation',
      'Political Research', 'Legislative Analysis', 'International Trade Policy',
      'Geopolitical Analysis', 'Public Administration Management',
    ],
    'Arts / Humanities / Education': [
      'Creative Writing', 'Literary Analysis', 'Historical Research', 'Archival Studies',
      'Philosophical Analysis', 'Critical Thinking', 'Content Writing', 'Editing & Proofreading',
      'Cultural Studies', 'Art Criticism', 'Translation', 'Manuscript Analysis', 'Oral History',
      'Ethnography', 'Research Methodologies', 'Academic Writing', 'Classroom Management',
      'Curriculum Design', 'Lesson Planning', 'E-Learning Tools', 'Pedagogical Techniques',
      'Special Education Strategies', 'Inclusive Education', 'Assessment Design',
      'Educational Technology', 'Student Counseling',
    ],
    'Design / Media / Communication': [
      'Adobe Photoshop', 'Adobe Illustrator', 'Figma', 'Adobe XD', 'Canva', 'UI/UX Design',
      'Fashion Illustration', 'Pattern Making', 'Textile Design', '3D Modeling', 'Blender',
      'SketchUp', 'Graphic Design', 'Typography', 'Branding', 'Motion Graphics', 'Color Theory',
      'Video Editing', 'Adobe Premiere Pro', 'Final Cut Pro', 'Journalism Ethics', 'News Writing',
      'Copywriting', 'Broadcast Journalism', 'Photojournalism', 'Social Media Content Creation',
      'Public Relations', 'Storyboarding', 'Media Production', 'Podcast Production',
    ],
    'Hotel / Travel / Event Management': [
      'Hospitality Management', 'Event Planning', 'Customer Service', 'Food & Beverage Service',
      'Culinary Techniques', 'Menu Planning', 'Bartending', 'Housekeeping Management',
      'Travel Planning', 'Tour Operations', 'Ticketing & Reservations', 'Catering Management',
      'Hotel Operations', 'Guest Relations', 'Inventory Management', 'Sustainable Tourism',
      'Vendor Management', 'Event Logistics', 'Budget Planning', 'Sponsorship Management',
    ],
    'Science / Research / Environment': [
      'Laboratory Techniques', 'Chemical Analysis', 'Microscopy', 'Spectroscopy', 'Experimental Design',
      'Data Analysis', 'Physics Modeling', 'Organic Chemistry', 'Molecular Biology', 'Biochemistry',
      'Quantum Mechanics', 'Thermodynamics', 'Cell Biology', 'Scientific Writing', 'Lab Safety',
      'Instrumentation', 'Environmental Impact Assessment', 'Geographic Information System (GIS)',
      'Remote Sensing', 'Geological Mapping', 'Climate Modeling', 'Marine Biology', 'Oceanography',
      'Environmental Monitoring', 'Soil Analysis', 'Hydrology', 'Biodiversity Conservation',
    ],
    'Astronomy / Astrophysics / Planetary Science': [
      'Astrometry', 'Telescopic Observation', 'Data Analysis', 'Astrostatistics', 'Orbital Mechanics',
      'Stellar Astrophysics', 'Planetary Geology', 'Spectroscopy', 'Computational Modeling',
      'Space Mission Design', 'Astronomical Software (Stellarium, IRAF)', 'Exoplanet Research',
      'Cosmology', 'Radio Astronomy', 'Image Processing',
    ],
    'Vocational/Domestic Services': [
      'Driving', 'Vehicle Operation (Cars, Trucks, Buses)', 'Defensive Driving', 'Route Navigation',
      'Vehicle Maintenance', 'Traffic Regulations', 'GPS Usage', 'Delivery Scheduling', 'Cargo Handling',
      'Housekeeping', 'Cleaning & Sanitation', 'Inventory Stocking', 'Office Management',
      'Document Handling', 'Filing & Organization', 'Basic Computer Skills (MS Office)', 'Errand Running',
      'Office Equipment Maintenance', 'Mail Distribution', 'Reception Duties', 'Woodworking',
      'Furniture Making', 'Carpentry Tools (Saws, Drills, Chisels)', 'Blueprint Reading', 'Wood Finishing',
      'Cabinet Making', 'Framing', 'Joinery', 'Timber Measurement', 'Wood Carving', 'Cooking',
      'Childcare', 'Elderly Care', 'Gardening', 'Landscaping', 'Basic Maintenance', 'Plumbing',
      'Pipe Fitting', 'Electrical Wiring', 'Masonry', 'Painting', 'Welding', 'Construction Labor',
      'Scaffolding', 'Heavy Machinery Operation', 'Forklift Operation', 'Pest Control',
      'Customer Service', 'Time Management', 'Physical Stamina', 'Teamwork', 'Problem-Solving',
      'Work Safety Practices',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation', 'Ethical Analysis', 'Policy Formulation', 'Interdisciplinary Research',
      'Digital Archiving', 'Data Ethics', 'Climate Policy Analysis', 'Stakeholder Engagement',
      'Text Analysis', 'Digital Storytelling', 'Public Policy Research', 'AI Governance',
      'Environmental Ethics', 'Cross-Cultural Analysis',
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
    dev.log('[2025-09-01 14:37 IST] Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'AppliedSeekersScreen');
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
        dev.log('[2025-09-01 14:37 IST] Job $jobId not owned by recruiter $recruiterId: ${jobDoc.data()}', name: 'AppliedSeekersScreen');
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
        dev.log('[2025-09-01 14:37 IST] Application $applicationId not found or not owned by recruiter $recruiterId', name: 'AppliedSeekersScreen');
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
        dev.log('[2025-09-01 14:37 IST] Initiating chat with seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
        if (!mounted) {
          dev.log('[2025-09-01 14:37 IST] Widget not mounted, cannot navigate to ChatScreen', name: 'AppliedSeekersScreen');
          return;
        }
        dev.log('[2025-09-01 14:37 IST] Navigating to ChatScreen for seeker $seekerId', name: 'AppliedSeekersScreen');
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
          dev.log('[2025-09-01 14:37 IST] Downloaded CV for seeker $seekerId: $url', name: 'AppliedSeekersScreen');
        } else {
          dev.log('[2025-09-01 14:37 IST] No CV available for seeker $seekerId', name: 'AppliedSeekersScreen');
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
      dev.log('[2025-09-01 14:37 IST] Error handling action $action for seeker $seekerId, job $jobId: $e', name: 'AppliedSeekersScreen', error: e);
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

  void _openSeekerDetails(String seekerId, String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeekerDetailsScreen(
          seekerId: seekerId,
          jobId: jobId,
        ),
      ),
    );
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> applicants) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Applicants'];
      sheet.appendRow([
       TextCellValue('Name'),
       TextCellValue('Mobile'),
       TextCellValue('Specialization'),
       TextCellValue('Education'),
       TextCellValue('Experience'),
       TextCellValue('Skills'),
       TextCellValue('Status'),
       TextCellValue('Job Title'),
]);

      for (var a in applicants) {
        final resume = a['resume'] as Map<String, dynamic>? ?? {};
        final specialization = specializationOptions.contains(resume['specialization'] ?? a['specialization'])
            ? (resume['specialization'] ?? a['specialization'] ?? 'N/A')
            : 'N/A';
        // Prioritize applicant.skills if available, fall back to resume.skills
        final skillsList = (a['skills'] is List<dynamic> && a['skills'].isNotEmpty)
            ? a['skills'].cast<String>()
            : (resume['skills'] is List<dynamic> && resume['skills'].isNotEmpty)
                ? resume['skills'].cast<String>()
                : (a['skills'] is String && a['skills'].isNotEmpty)
                    ? a['skills'].split(', ')
                    : [];
        final skillsDisplay = skillsList.isNotEmpty ? skillsList.join(', ') : 'N/A';

        sheet.appendRow([
          resume['name'] ?? a['name'] ?? '',
          resume['mobileNumber'] ?? a['mobile'] ?? '',
          specialization,
          resume['education'] ?? a['education'] ?? '',
          resume['experience'] ?? a['experience'] ?? '',
          skillsDisplay,
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
      dev.log('[2025-09-01 14:37 IST] Exported applicants to $path', name: 'AppliedSeekersScreen');
    } catch (e) {
      dev.log('[2025-09-01 14:37 IST] Error exporting to Excel: $e', name: 'AppliedSeekersScreen', error: e);
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
  backgroundColor: const Color(0xFF0E4A88),
  automaticallyImplyLeading: false,
  title: const Text(
    'Applied Seekers',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    ),
  ),
),
        body: const Center(child: Text('Please log in to view applicants')),
      );
    }
    final titleText = (widget.jobTitle.trim().isNotEmpty)
        ? 'Applied Seekers for ${widget.jobTitle}'
        : 'Applied Seekers';

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
  elevation: 0,
  backgroundColor: const Color(0xFF0E4A88),
  automaticallyImplyLeading: false, // removes back arrow
  title: Text(
    titleText,
    style: TextStyle(
      fontSize: 19.sp,
      fontWeight: FontWeight.w700,
      color: Colors.white, // makes text white
    ),
  ),
),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAF1FA), Color(0xFFF8FBFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10.r,
                          offset: Offset(0, 3.h),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by name or job title',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFF0E4A88), width: 1.3),
                              ),
                              prefixIcon: Icon(Icons.search, size: 20.sp),
                              isDense: true,
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
                                dev.log('[2025-09-01 14:37 IST] No applicants to export for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No applicants available to export.')),
                                  );
                                }
                                return;
                              }
                              await _exportToExcel(applicants);
                            } catch (e) {
                              dev.log('[2025-09-01 14:37 IST] Error exporting applicants for recruiter $recruiterId: $e', name: 'AppliedSeekersScreen', error: e);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error exporting applicants. Check logs.')),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.download_rounded, size: 18.sp),
                          label: Text('Export', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E4A88),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: widget.authService.fetchAppliedSeekers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(strokeWidth: 3.w));
                        }
                        if (snapshot.hasError) {
                          final error = snapshot.error;
                          String errorMessage = 'Error loading applied seekers. Please verify Firestore permissions or contact support.';
                          if (error is FirebaseException) {
                            errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                            if (error.code == 'permission-denied') {
                              errorMessage +=
                                  '\nEnsure /Applications/{jobId} exists with recruiterId=$recruiterId and job exists in /Recruiters/$recruiterId/Jobs/{jobId}.';
                              dev.log('[2025-09-01 14:37 IST] Permission denied in fetchAppliedSeekers. Check /Applications/{jobId} and /Recruiters/$recruiterId/Jobs for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                            }
                          }
                          dev.log('[2025-09-01 14:37 IST] Error loading applied seekers for recruiter $recruiterId: $error', name: 'AppliedSeekersScreen', error: error, stackTrace: snapshot.stackTrace);
                          return _buildStateCard(
                            icon: Icons.error_outline,
                            text: errorMessage,
                            color: Colors.red.shade700,
                          );
                        }

                        final applicants = snapshot.data ?? [];

                        if (applicants.isEmpty) {
                          dev.log('[2025-09-01 14:37 IST] No applicants found for recruiter $recruiterId. Verify /Applications/{jobId} exists with correct recruiterId.', name: 'AppliedSeekersScreen');
                          return _buildStateCard(
                            icon: Icons.group_off_outlined,
                            text: 'No applied seekers found',
                            color: Colors.blueGrey.shade600,
                          );
                        }

                        final filteredApplicants = applicants.where((applicant) {
                          final name = (applicant['resume']?['name'] ?? applicant['name'] ?? '').toLowerCase();
                          final jobTitle = (applicant['jobTitle'] ?? '').toLowerCase();
                          return name.contains(_searchQuery) || jobTitle.contains(_searchQuery);
                        }).toList();

                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E4A88),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '${filteredApplicants.length} of ${applicants.length} seekers shown',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.sp),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredApplicants.length,
                                itemBuilder: (_, index) {
                                  final applicant = filteredApplicants[index];
                                  final seekerId = applicant['seekerId'] as String? ?? 'Unknown';
                                  final jobId = applicant['jobId'] as String? ?? 'Unknown';
                                  final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
                                  final specialization = specializationOptions.contains(resume['specialization'] ?? applicant['specialization'])
                                      ? (resume['specialization'] ?? applicant['specialization'] ?? 'N/A')
                                      : 'N/A';
                                  final skillsList = (applicant['skills'] is List<dynamic> && applicant['skills'].isNotEmpty)
                                      ? applicant['skills'].cast<String>()
                                      : (resume['skills'] is List<dynamic> && resume['skills'].isNotEmpty)
                                          ? resume['skills'].cast<String>()
                                          : (applicant['skills'] is String && applicant['skills'].isNotEmpty)
                                              ? applicant['skills'].split(', ')
                                              : [];
                                  final skillsDisplay = skillsList.isNotEmpty ? skillsList.join(', ') : 'N/A';
                                  final status = (applicant['status'] ?? 'N/A').toString();

                                  final normalizedStatus = status.toLowerCase();
                                  final bool isShortlisted = normalizedStatus == 'shortlisted';
                                  final bool isRejected = normalizedStatus == 'rejected';
                                  final Color outlineColor = isShortlisted
                                      ? const Color(0xFF2E7D32)
                                      : isRejected
                                          ? const Color(0xFFC62828)
                                          : Colors.transparent;

                                  return Card(
                                    elevation: 2,
                                    margin: EdgeInsets.symmetric(vertical: 5.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      side: BorderSide(
                                        color: outlineColor,
                                        width: isShortlisted || isRejected ? 1.4 : 0,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14.r),
                                      onTap: () => _openSeekerDetails(seekerId, jobId),
                                      child: Padding(
                                        padding: EdgeInsets.all(10.w),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _buildApplicantAvatar(
                                                  seekerId: seekerId,
                                                  applicant: applicant,
                                                  resume: resume,
                                                ),
                                                SizedBox(width: 10.w),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _displayName(resume, applicant, seekerId),
                                                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                                                      ),
                                                      Text(
                                                        applicant['jobTitle'] ?? jobId,
                                                        style: TextStyle(fontSize: 12.sp, color: Colors.blueGrey.shade600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'View seeker details',
                                                  onPressed: () => _openSeekerDetails(seekerId, jobId),
                                                  icon: Icon(Icons.open_in_new, size: 18.sp, color: Colors.blue.shade700),
                                                ),
                                                PopupMenuButton<String>(
                                                  onSelected: (action) => _handleAction(action, jobId, seekerId, {'resume': resume, ...applicant}),
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(value: 'shortlist', child: Text('Shortlist')),
                                                    const PopupMenuItem(value: 'reject', child: Text('Reject')),
                                                    const PopupMenuItem(value: 'schedule', child: Text('Schedule Interview')),
                                                    const PopupMenuItem(value: 'download_cv', child: Text('Download CV')),
                                                    const PopupMenuItem(value: 'chat', child: Text('Chat')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8.h),
                                            _detailLine(Icons.mail_outline, 'Email', resume['email'] ?? 'N/A'),
                                            _detailLine(Icons.school_outlined, 'Education', resume['education'] ?? applicant['education'] ?? 'N/A'),
                                            _detailLine(Icons.work_outline, 'Experience', resume['experience'] ?? applicant['experience'] ?? 'N/A'),
                                            _detailLine(Icons.account_tree_outlined, 'Specialization', specialization),
                                            _detailLine(Icons.psychology_outlined, 'Skills', skillsDisplay),
                                            SizedBox(height: 8.h),
                                            Row(
                                              children: [
                                                const Spacer(),
                                                _statusBadge(status),
                                              ],
                                            ),
                                            // Container(
                                            //   padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                            //   decoration: BoxDecoration(
                                            //     color: Colors.blue.shade50,
                                            //     borderRadius: BorderRadius.circular(999.r),
                                            //   ),
                                            //   // child: Row(
                                            //   //   mainAxisSize: MainAxisSize.min,
                                            //   //   children: [
                                            //   //     Icon(Icons.touch_app_outlined, size: 14.sp, color: Colors.blue.shade700),
                                            //   //     SizedBox(width: 6.w),
                                            //   //     // Text(
                                            //   //     //   'Tap card to view full seeker details',
                                            //   //     //   style: TextStyle(
                                            //   //     //     fontSize: 11.sp,
                                            //   //     //     fontWeight: FontWeight.w600,
                                            //   //     //     color: Colors.blue.shade700,
                                            //   //     //   ),
                                            //   //     // ),
                                            //   //   ],
                                            //   // ),
                                            // ),
                                          ],
                                        ),
                                      ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: Colors.blueGrey.shade600),
          SizedBox(width: 6.w),
          SizedBox(
            width: 90.w,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(
    Map<String, dynamic> resume,
    Map<String, dynamic> applicant,
    String seekerId,
  ) {
    final text = (resume['name'] ?? applicant['name'] ?? seekerId).toString().trim();
    return text.isEmpty ? seekerId : text;
  }

  String _initialFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  String? _extractPhotoUrl(Map<String, dynamic> applicant, Map<String, dynamic> resume) {
    final candidates = <dynamic>[
      resume['photoUrl'],
      resume['profilePhotoUrl'],
      applicant['photoUrl'],
      applicant['profilePhotoUrl'],
      applicant['seekerPhotoUrl'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<String?> _getSeekerPhotoUrl(String seekerId) async {
    if (_photoUrlCache.containsKey(seekerId)) return _photoUrlCache[seekerId];
    try {
      final usersIndexDoc = await FirebaseFirestore.instance.collection('UsersIndex').doc(seekerId).get();
      final usersIndexUrl = usersIndexDoc.data()?['photoUrl']?.toString().trim() ?? '';
      if (usersIndexUrl.isNotEmpty) {
        _photoUrlCache[seekerId] = usersIndexUrl;
        return usersIndexUrl;
      }

      final seekersDoc = await FirebaseFirestore.instance.collection('Seekers').doc(seekerId).get();
      final seekersUrl = seekersDoc.data()?['photoUrl']?.toString().trim() ?? '';
      _photoUrlCache[seekerId] = seekersUrl.isNotEmpty ? seekersUrl : null;
      return _photoUrlCache[seekerId];
    } catch (e) {
      dev.log('[2026-02-23 16:50 IST] Failed to fetch profile photo for seeker $seekerId: $e', name: 'AppliedSeekersScreen', error: e);
      _photoUrlCache[seekerId] = null;
      return null;
    }
  }

  Widget _buildApplicantAvatar({
    required String seekerId,
    required Map<String, dynamic> applicant,
    required Map<String, dynamic> resume,
  }) {
    final name = _displayName(resume, applicant, seekerId);
    final directUrl = _extractPhotoUrl(applicant, resume);
    if (directUrl != null && directUrl.isNotEmpty) {
      return _networkAvatar(directUrl, name);
    }

    return FutureBuilder<String?>(
      future: _getSeekerPhotoUrl(seekerId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url != null && url.isNotEmpty) {
          return _networkAvatar(url, name);
        }
        return CircleAvatar(
          radius: 20.r,
          backgroundColor: const Color(0xFF0E4A88),
          child: Text(
            _initialFromName(name),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp),
          ),
        );
      },
    );
  }

  Widget _networkAvatar(String url, String name) {
    return CircleAvatar(
      radius: 20.r,
      backgroundColor: const Color(0xFF0E4A88),
      child: ClipOval(
        child: Image.network(
          url,
          width: 40.r,
          height: 40.r,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                _initialFromName(name),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    Color bg = const Color(0xFFE8F5E9);
    Color fg = const Color(0xFF1B5E20);
    if (normalized == 'rejected') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    } else if (normalized == 'scheduled') {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF0D47A1);
    } else if (normalized == 'applied' || normalized == 'pending') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFEF6C00);
    }

    return Container(
      margin: EdgeInsets.only(right: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 8.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
