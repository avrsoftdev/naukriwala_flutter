// ignore_for_file: unnecessary_null_comparison

import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/apply_job_screen.dart';
import 'package:naukariwala/screens/edit_job_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class JobScreen extends StatefulWidget {
  final bool isSeekerProfileView;
  final bool showSavedOnly;

  const JobScreen({
    super.key,
    this.isSeekerProfileView = false,
    this.showSavedOnly = false,
  });

  @override
  JobScreenState createState() => JobScreenState();
}

class JobScreenState extends State<JobScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> filteredJobs = [];
  bool isLoading = true;
  bool isJobDetailsLoading = false;
  String? errorMessage;
  Map<String, dynamic>? _seekerProfile;
  final Set<String> _appliedJobIds = {};
  Map<String, dynamic>? _selectedJob;
  Stream<QuerySnapshot>? _applicantsStream;
  Map<String, dynamic>? _jobData;
  bool _isEligible = false;
  String? _ineligibilityReason;
  final Set<String> _savedJobIds = {};
  double? _selectedDistanceKm;
  String? _selectedGender;

  final List<double> distanceOptions = [50, 100, 150, 200];
  final List<String> genderOptions = ['Any', 'Male', 'Female'];

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

  // Education options
final List<String> educationOptions = [
  'Secondary (Class 10)',
  'Higher Secondary (Class 12)',
  'Diploma/Certificate',
  'Undergraduate (Bachelor\'s Degree)',
  'Postgraduate Diploma',
  'Postgraduate (Master\'s Degree)',
  'Doctorate/PhD/MPhil',
  'Professional Certification',
  'Vocational Training',
];

// Specialization options
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

// Skills by specialization
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(() => _filterJobs(_searchController.text));
    dev.log('[2025-09-01 14:44 IST] JobScreen initialized, isSeekerProfileView: ${widget.isSeekerProfileView}', name: 'JobScreen');
  }

  Future<void> _initializeData() async {
    await fetchSeekerProfile();
    await _fetchSavedJobs();
    if (_seekerProfile != null || FirebaseAuth.instance.currentUser == null) {
      await fetchJobsFromFirestore();
    }
  }

  Future<void> _fetchSavedJobs() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Bookmarks')
          .doc(currentUser.uid)
          .collection('SavedJobs')
          .get();

      if (!mounted) return;
      setState(() {
        _savedJobIds
          ..clear()
          ..addAll(snapshot.docs.map((doc) => doc.id));
        _recomputeFilteredJobs();
      });
    } catch (e, stackTrace) {
      dev.log(
        '[2025-09-01 14:44 IST] Error fetching saved jobs: $e',
        name: 'JobScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> fetchSeekerProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      dev.log('[2025-09-01 14:44 IST] No authenticated user', name: 'JobScreen');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('UsersIndex')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        final seekerDoc = await FirebaseFirestore.instance
            .collection('Seekers')
            .doc(currentUser.uid)
            .get();
        if (seekerDoc.exists) {
          setState(() {
            _seekerProfile = seekerDoc.data();
          });
          final applications = await FirebaseFirestore.instance
              .collection('Applications')
              .where('seekerId', isEqualTo: currentUser.uid)
              .get();
          setState(() {
            _appliedJobIds.addAll(applications.docs.map((doc) => doc['jobId'] as String));
          });
          dev.log('[2025-09-01 14:44 IST] Fetched seeker profile for ${currentUser.uid}', name: 'JobScreen');
          if (mounted && isLoading) {
            await fetchJobsFromFirestore();
          }
        } else {
          dev.log('[2025-09-01 14:44 IST] No seeker profile found for ${currentUser.uid}', name: 'JobScreen');
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 14:44 IST] Error fetching seeker profile: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading profile: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchJobsFromFirestore() async {
    try {
      dev.log('[2025-09-01 14:44 IST] Fetching jobs with collection group query, emulator: ${kDebugMode ? "localhost:8080" : "default"}', name: 'JobScreen');
      if (kDebugMode) {
        FirebaseFirestore.instance.settings = const Settings(
          host: 'localhost:8080',
          sslEnabled: false,
          persistenceEnabled: false,
        );
      }
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('Jobs')
          .where('status', isEqualTo: 'open')
          .orderBy('isFeatured', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      final jobList = snapshot.docs.map((doc) {
        final data = doc.data();
        final isFeatured = data['isFeatured'] ?? false; // Explicitly handle null
        dev.log('[2025-09-01 14:44 IST] Job ${doc.id}: isFeatured=$isFeatured, title=${data['title']}, company=${data['company']}', name: 'JobScreen');
        return {
          ...data,
          'jobId': doc.id,
          'recruiterId': data['recruiterId'],
          'isFeatured': isFeatured,
          'postedAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'isEligible': _seekerProfile != null ? _checkJobCompatibilityForJob(data) : false,
        };
      }).toList();

      dev.log('[2025-09-01 14:44 IST] Fetched ${snapshot.docs.length} jobs, featured: ${jobList.where((j) => j['isFeatured'] == true).length}, non-featured: ${jobList.where((j) => j['isFeatured'] == false).length}', name: 'JobScreen');

      if (mounted) {
        setState(() {
          jobs = jobList;
          _recomputeFilteredJobs();
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 14:44 IST] Error fetching jobs: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load jobs: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load jobs: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _filterJobs(String query) {
    _searchQuery = query.toLowerCase();
    setState(_recomputeFilteredJobs);
  }

  void _recomputeFilteredJobs() {
    final sourceJobs = widget.showSavedOnly
        ? jobs.where((job) => _savedJobIds.contains(job['jobId']?.toString() ?? '')).toList()
        : jobs;

    List<Map<String, dynamic>> working = sourceJobs;

    if (_searchQuery.isNotEmpty) {
      working = working.where((job) {
        final title = (job['title'] ?? '').toString().toLowerCase();
        final company = (job['company'] ?? '').toString().toLowerCase();
        final location = (job['location'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) ||
            company.contains(_searchQuery) ||
            location.contains(_searchQuery);
      }).toList();
    }

    if (_selectedDistanceKm != null && _hasSeekerLocation) {
      working = working.where((job) {
        final distance = _getJobDistanceKm(job);
        if (distance == null) return false;
        return distance <= _selectedDistanceKm!;
      }).toList();
    }

    if (_selectedGender != null && _selectedGender != 'Any') {
      working = working.where((job) {
        final jobGender = job['gender']?.toString().toLowerCase();
        return jobGender == null || jobGender.isEmpty || jobGender.toLowerCase() == _selectedGender!.toLowerCase();
      }).toList();
    }

    filteredJobs = working;

    dev.log(
      '[2025-09-01 14:44 IST] Filtered jobs: ${filteredJobs.length} found for query "$_searchQuery"',
      name: 'JobScreen',
    );
  }

  bool get _hasSeekerLocation {
    final location = _seekerProfile?['city']?.toString().trim();
    return location != null && location.isNotEmpty;
  }

  double? _getJobDistanceKm(Map<String, dynamic> job) {
    if (!_hasSeekerLocation) return null;
    final seekerLocation = _seekerProfile?['city']?.toString() ?? '';
    final jobLocation = job['location']?.toString() ?? '';
    return _calculateDistanceKm(jobLocation, seekerLocation);
  }

  double? _calculateDistanceKm(String location1, String location2) {
    if (location1.trim().isEmpty || location2.trim().isEmpty) return null;

    final city1 = _resolveCityKey(location1);
    final city2 = _resolveCityKey(location2);
    if (city1 == null || city2 == null) return null;

    final coords1 = _cityCoordinates[city1];
    final coords2 = _cityCoordinates[city2];
    if (coords1 == null || coords2 == null) return null;

    final lat1 = coords1[0];
    final lon1 = coords1[1];
    final lat2 = coords2[0];
    final lon2 = coords2[1];

    const radius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c;
  }

  String? _resolveCityKey(String location) {
    final normalized = location.toLowerCase();
    for (final city in _cityCoordinates.keys) {
      if (normalized.contains(city.toLowerCase())) {
        return city;
      }
    }

    final aliasMatch = _cityAliases.entries.firstWhere(
      (entry) => normalized.contains(entry.key),
      orElse: () => const MapEntry('', ''),
    );
    if (aliasMatch.key.isNotEmpty && aliasMatch.value.isNotEmpty) {
      return aliasMatch.value;
    }

    final firstPart = location.split(',').first.trim().toLowerCase();
    for (final city in _cityCoordinates.keys) {
      if (firstPart == city.toLowerCase()) {
        return city;
      }
    }
    return null;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  final Map<String, List<double>> _cityCoordinates = {
    'Mumbai': [19.0760, 72.8777],
    'Delhi': [28.6139, 77.2090],
    'Bangalore': [12.9716, 77.5946],
    'Bengaluru': [12.9716, 77.5946],
    'Chennai': [13.0827, 80.2707],
    'Kolkata': [22.5726, 88.3639],
    'Hyderabad': [17.3850, 78.4867],
    'Pune': [18.5204, 73.8567],
    'Ahmedabad': [23.0225, 72.5714],
    'Jaipur': [26.9124, 75.7873],
    'Surat': [21.1702, 72.8311],
    'Lucknow': [26.8467, 80.9462],
    'Kanpur': [26.4499, 80.3319],
    'Nagpur': [21.1458, 79.0882],
    'Indore': [22.7196, 75.8577],
    'Bhopal': [23.2599, 77.4126],
    'Patna': [25.5941, 85.1376],
    'Chandigarh': [30.7333, 76.7794],
    'Kochi': [9.9312, 76.2673],
    'Coimbatore': [11.0168, 76.9558],
    'Thiruvananthapuram': [8.5241, 76.9366],
    'Visakhapatnam': [17.6868, 83.2185],
    'Vadodara': [22.3072, 73.1812],
    'Noida': [28.5355, 77.3910],
    'Gurgaon': [28.4595, 77.0266],
  };

  final Map<String, String> _cityAliases = {
    'gurugram': 'Gurgaon',
    'bengaluru': 'Bangalore',
    'bangalore': 'Bangalore',
    'delhi ncr': 'Delhi',
    'ncr': 'Delhi',
  };

  Future<void> _shareJob(Map<String, dynamic> job) async {
    final text = [
      'Job Opportunity on Naukariwala',
      'Title: ${job['title'] ?? 'N/A'}',
      'Company: ${job['company'] ?? 'N/A'}',
      'Location: ${job['location'] ?? 'N/A'}',
      'Type: ${job['jobType'] ?? 'N/A'}',
      'Salary: ${job['salary'] ?? 'Not specified'}',
      '',
      'Download Now - https://play.google.com/store/apps/details?id=com.naukariwala.avr',
    ].join('\n');

    try {
      await Share.share(text, subject: 'Job Opportunity');
    } catch (e, stackTrace) {
      dev.log(
        '[2025-09-01 14:44 IST] Error sharing job: $e',
        name: 'JobScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share job: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleSavedJob(Map<String, dynamic> job) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save jobs.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final jobId = job['jobId']?.toString() ?? '';
    if (jobId.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('Bookmarks')
        .doc(currentUser.uid)
        .collection('SavedJobs')
        .doc(jobId);

    final isAlreadySaved = _savedJobIds.contains(jobId);

    try {
      if (isAlreadySaved) {
        await docRef.delete();
      } else {
        await docRef.set({
          'jobId': jobId,
          'title': job['title'],
          'company': job['company'],
          'location': job['location'],
          'jobType': job['jobType'],
          'recruiterId': job['recruiterId'],
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() {
        if (isAlreadySaved) {
          _savedJobIds.remove(jobId);
          if (widget.showSavedOnly && _selectedJob?['jobId']?.toString() == jobId) {
            _selectedJob = null;
          }
        } else {
          _savedJobIds.add(jobId);
        }
        _recomputeFilteredJobs();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAlreadySaved ? 'Removed from saved jobs' : 'Job saved successfully'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stackTrace) {
      dev.log(
        '[2025-09-01 14:44 IST] Error saving job: $e',
        name: 'JobScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save job: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectJob(Map<String, dynamic> job) async {
    setState(() {
      _selectedJob = job;
      isJobDetailsLoading = true;
      _jobData = null;
      _applicantsStream = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        isJobDetailsLoading = false;
        _isEligible = false;
        _ineligibilityReason = 'Please log in to view eligibility.';
      });
      return;
    }

    try {
      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(job['recruiterId']?.toString())
          .collection('Jobs')
          .doc(job['jobId']?.toString())
          .get();

      if (!jobDoc.exists || jobDoc.data()?['status'] != 'open') {
        setState(() {
          isJobDetailsLoading = false;
          _isEligible = false;
          _ineligibilityReason = 'This job is no longer available.';
        });
        return;
      }

      _jobData = {...job, ...jobDoc.data()!};

      if (currentUser.uid == job['recruiterId']?.toString()) {
        setState(() {
          isJobDetailsLoading = false;
          _isEligible = true;
        });
        _fetchApplicants();
        return;
      }

      if (_seekerProfile == null) {
        final seekerDoc = await FirebaseFirestore.instance
            .collection('Seekers')
            .doc(currentUser.uid)
            .get();
        if (!seekerDoc.exists) {
          setState(() {
            isJobDetailsLoading = false;
            _isEligible = false;
            _ineligibilityReason = 'Please complete your profile to determine eligibility.';
          });
          return;
        }
        _seekerProfile = seekerDoc.data()!;
        if (_seekerProfile!['specialization'] != null && !specializationOptions.contains(_seekerProfile!['specialization'])) {
          _seekerProfile!['specialization'] = 'Others';
        }
      }

      setState(() {
        _isEligible = job['isEligible'] ?? _checkJobCompatibility();
        isJobDetailsLoading = false;
        _ineligibilityReason = _isEligible ? null : _getIneligibilityReason();
      });
      _fetchApplicants();
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 14:44 IST] Error fetching job details: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      setState(() {
        isJobDetailsLoading = false;
        _isEligible = false;
        _ineligibilityReason = 'Failed to load job details: $e';
      });
    }
  }

  Future<void> _fetchApplicants() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != _selectedJob?['recruiterId']?.toString()) return;
    setState(() {
      _applicantsStream = FirebaseFirestore.instance
          .collection('Applications')
          .doc(_selectedJob?['jobId']?.toString())
          .collection('AppliedJobs')
          .snapshots();
    });
  }

  // Helper function to safely convert skills to List<String>
  List<String> _convertSkillsToList(dynamic skills) {
    if (skills == null) return [];
    
    if (skills is List) {
      return skills.map((s) => s.toString().toLowerCase()).toList();
    } else if (skills is String) {
      final skillsString = skills;
      return skillsString.isNotEmpty ? skillsString.split(',').map((s) => s.trim().toLowerCase()).toList() : [];
    }
    
    return [];
  }

  Set<String> _extractSkillKeywords(List<String> skills) {
    final keywords = <String>{};
    final tokenPattern = RegExp(r'[a-z0-9]+');
    for (final skill in skills) {
      final matches = tokenPattern.allMatches(skill.toLowerCase());
      for (final match in matches) {
        final token = match.group(0);
        if (token != null && token.isNotEmpty) {
          keywords.add(token);
        }
      }
    }
    return keywords;
  }

  // Helper function to format skills for display
  String _formatSkillsForDisplay(dynamic skills) {
    if (skills == null) return 'N/A';
    
    if (skills is List) {
      return skills.map((s) => s.toString()).join(', ');
    } else if (skills is String) {
      final skillsString = skills;
      return skillsString.isNotEmpty ? skillsString : 'N/A';
    }
    
    return 'N/A';
  }

  bool _checkJobCompatibilityForJob(Map<String, dynamic> jobData) {
    if (_seekerProfile == null || jobData == null) return false;

    final jobSkills = _convertSkillsToList(jobData['skills']);
    final seekerSkills = _convertSkillsToList(_seekerProfile!['skills']);
    final jobEducation = jobData['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = jobData['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(jobData['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['totalExperienceYears']?.toString() ?? '0');

    final jobKeywords = _extractSkillKeywords(jobSkills);
    final seekerKeywords = _extractSkillKeywords(seekerSkills);
    final matchingKeywords = jobKeywords.intersection(seekerKeywords).length;
    final skillsMatch = jobKeywords.isEmpty || matchingKeywords > 0;
    final skillMatchPercentage = jobKeywords.isEmpty ? 100.0 : (matchingKeywords / jobKeywords.length) * 100;
    final educationMatch = jobEducation.isEmpty || jobEducation == seekerEducation;
    final specializationMatch = jobSpecialization.isEmpty || jobSpecialization == seekerSpecialization;
    final experienceMatch = seekerExperience >= jobExperience;

    dev.log('[2025-09-01 14:44 IST] Pre-check compatibility for job ${jobData['jobId']}: Skills match=$skillsMatch ($skillMatchPercentage%), Education match=$educationMatch, Specialization match=$specializationMatch, Experience match=$experienceMatch',
        name: 'JobScreen');
    return skillsMatch && educationMatch && specializationMatch && experienceMatch;
  }

  bool _checkJobCompatibility() {
    if (_seekerProfile == null || _jobData == null) return false;

    final jobSkills = _convertSkillsToList(_jobData!['skills']);
    final seekerSkills = _convertSkillsToList(_seekerProfile!['skills']);
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['totalExperienceYears']?.toString() ?? '0');

    final jobKeywords = _extractSkillKeywords(jobSkills);
    final seekerKeywords = _extractSkillKeywords(seekerSkills);
    final matchingKeywords = jobKeywords.intersection(seekerKeywords).length;
    final skillsMatch = jobKeywords.isEmpty || matchingKeywords > 0;
    final skillMatchPercentage = jobKeywords.isEmpty ? 100.0 : (matchingKeywords / jobKeywords.length) * 100;
    final educationMatch = jobEducation.isEmpty || jobEducation == seekerEducation;
    final specializationMatch = jobSpecialization.isEmpty || jobSpecialization == seekerSpecialization;
    final experienceMatch = seekerExperience >= jobExperience;

    dev.log('[2025-09-01 14:44 IST] Compatibility check for job ${_jobData!['jobId']}: Skills match=$skillsMatch ($skillMatchPercentage%), Education match=$educationMatch, Specialization match=$specializationMatch, Experience match=$experienceMatch',
        name: 'JobScreen');
    return skillsMatch && educationMatch && specializationMatch && experienceMatch;
  }

  String _getIneligibilityReason() {
    if (_seekerProfile == null || _jobData == null) {
      return 'Unable to verify eligibility due to missing profile or job data.';
    }

    final jobSkills = _convertSkillsToList(_jobData!['skills']);
    final seekerSkills = _convertSkillsToList(_seekerProfile!['skills']);
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['totalExperienceYears']?.toString() ?? '0');

    List<String> reasons = [];
    if (jobSkills.isNotEmpty) {
      final jobKeywords = _extractSkillKeywords(jobSkills);
      final seekerKeywords = _extractSkillKeywords(seekerSkills);
      final hasKeywordMatch = jobKeywords.any(seekerKeywords.contains);
      if (!hasKeywordMatch) {
        reasons.add('Your skills do not match the required skills (${jobSkills.join(', ')}).');
      }
    }
    if (jobEducation.isNotEmpty && jobEducation != seekerEducation) {
      reasons.add('Your education does not match the requirement ($jobEducation).');
    }
    if (jobSpecialization.isNotEmpty && jobSpecialization != seekerSpecialization) {
      reasons.add('Your specialization does not match the requirement ($jobSpecialization).');
    }
    if (seekerExperience < jobExperience) {
      reasons.add('Your experience (${seekerExperience.toInt()} years) is less than required ($jobExperience years).');
    }
    return reasons.isEmpty
        ? 'This job does not match your education, specialization, skills, or experience.'
        : reasons.join(' ');
  }

  double _parseExperience(String experience) {
    try {
      final match = RegExp(r'\d+').firstMatch(experience);
      return double.parse(match?.group(0) ?? '0');
    } catch (e) {
      return 0;
    }
  }

  Future<void> _applyToJob(Map<String, dynamic> job) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please log in to apply',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApplyJobScreen(
            jobId: job['jobId'],
            recruiterId: job['recruiterId'],
            jobTitle: job['title'] ?? 'Untitled',
            seekerProfile: _seekerProfile,
          ),
        ),
      );
      if (mounted && result == true) {
        setState(() {
          _appliedJobIds.add(job['jobId']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application submitted successfully',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 14:44 IST] Error navigating to ApplyJobScreen: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to apply: $e',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _selectedJob?['recruiterId']?.toString()) return;

    try {
      await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(user.uid)
          .collection('Jobs')
          .doc(_selectedJob?['jobId']?.toString())
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Job deleted successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          jobs = jobs.where((job) => job['jobId'] != _selectedJob?['jobId']).toList();
          filteredJobs = filteredJobs.where((job) => job['jobId'] != _selectedJob?['jobId']).toList();
          _selectedJob = null;
        });
      }
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 14:44 IST] Error deleting job: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete job: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDistanceBottomSheet() {
    if (!_hasSeekerLocation) return;
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Distance',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 20.h),
            ...distanceOptions.map((distance) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                title: Text('Under ${distance.toStringAsFixed(0)} km'),
                trailing: _selectedDistanceKm == distance
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedDistanceKm = distance;
                    _recomputeFilteredJobs();
                  });
                  Navigator.pop(context);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(
                    color: _selectedDistanceKm == distance
                        ? Colors.blue.shade300
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            )),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Gender',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 20.h),
            ...genderOptions.map((gender) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                title: Text(gender),
                trailing: _selectedGender == gender
                    ? Icon(Icons.check, color: Colors.pink.shade700)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedGender = gender;
                    _recomputeFilteredJobs();
                  });
                  Navigator.pop(context);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(
                    color: _selectedGender == gender
                        ? Colors.pink.shade300
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            )),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(360, 640), minTextAdapt: true, splitScreenMode: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showSavedOnly
              ? 'Saved Jobs'
              : (widget.isSeekerProfileView ? 'Available Jobs' : 'Search & Available Jobs'),
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20.sp),
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
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Card(
                    elevation: 4,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Compact Filter Bar
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Compact Search and Filters Row
                          Row(
                            children: [
                              // Search Field
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search jobs...',
                                    prefixIcon: Icon(Icons.search, size: 18.sp),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                      borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              
                              // Filter Chips
                              Expanded(
                                flex: 1,
                                child: Row(
                                  children: [
                                    // Distance Filter Chip
                                    Expanded(
                                      child: FilterChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 12.sp,
                                              color: _selectedDistanceKm != null ? Colors.blue.shade700 : Colors.grey.shade600,
                                            ),
                                            SizedBox(width: 4.w),
                                            Flexible(
                                              child: Text(
                                                _selectedDistanceKm != null 
                                                    ? '${_selectedDistanceKm!.toStringAsFixed(0)}km'
                                                    : 'Distance',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: _selectedDistanceKm != null ? Colors.blue.shade700 : Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        selected: _selectedDistanceKm != null,
                                        onSelected: _hasSeekerLocation ? (value) {
                                          _showDistanceBottomSheet();
                                        } : null,
                                        backgroundColor: Colors.grey.shade100,
                                        selectedColor: Colors.blue.shade50,
                                        checkmarkColor: Colors.blue.shade700,
                                        disabledColor: Colors.grey.shade50,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    
                                    // Gender Filter Chip
                                    Expanded(
                                      child: FilterChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 12.sp,
                                              color: _selectedGender != null ? Colors.pink.shade700 : Colors.grey.shade600,
                                            ),
                                            SizedBox(width: 4.w),
                                            Flexible(
                                              child: Text(
                                                _selectedGender ?? 'Gender',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: _selectedGender != null ? Colors.pink.shade700 : Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        selected: _selectedGender != null,
                                        onSelected: (value) {
                                          _showGenderBottomSheet();
                                        },
                                        backgroundColor: Colors.grey.shade100,
                                        selectedColor: Colors.pink.shade50,
                                        checkmarkColor: Colors.pink.shade700,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Clear Button
                              if (_selectedDistanceKm != null || _selectedGender != null)
                                Padding(
                                  padding: EdgeInsets.only(left: 6.w),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedDistanceKm = null;
                                        _selectedGender = null;
                                        _recomputeFilteredJobs();
                                      });
                                    },
                                    icon: Icon(Icons.clear_all, size: 18.sp),
                                    iconSize: 18.sp,
                                    color: Colors.red.shade600,
                                    tooltip: 'Clear all filters',
                                    constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
                                    padding: EdgeInsets.all(6.w),
                                  ),
                                ),
                            ],
                          ),
                          
                          // Helper Text
                          if (!_hasSeekerLocation)
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                'Add address in profile to enable distance filter',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Scrollable Job List
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? Center(
                              child: Text(
                                widget.showSavedOnly
                                    ? 'No saved jobs yet.'
                                    : 'No jobs found matching your criteria.',
                                style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
                                final jobId = job['jobId']?.toString() ?? '';
                                final isApplied = _appliedJobIds.contains(job['jobId']);
                                final isFeatured = job['isFeatured'] ?? false;
                                final isSaved = _savedJobIds.contains(jobId);
                                final distanceKm = _getJobDistanceKm(job);
                                final distanceText = distanceKm == null
                                    ? null
                                    : '${distanceKm.toStringAsFixed(1)} km away';
                                final Color eligibilityBorderColor = _seekerProfile == null
                                    ? Colors.grey.shade300
                                    : (job['isEligible'] == true ? Colors.green.shade400 : Colors.red.shade300);
                                return Column(
                                  children: [
                                    AnimatedListItem(
                                      child: Card(
                                        elevation: 3,
                                        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                          side: BorderSide(color: eligibilityBorderColor, width: 1.2),
                                        ),
                                        color: Colors.white,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12.r),
                                          onTap: () => _selectJob(job),
                                          child: Stack(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.fromLTRB(16.w, 16.h, 58.w, 16.h),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            job['title'] ?? 'Untitled',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 18.sp,
                                                              color: Colors.black87,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (isFeatured)
                                                          Padding(
                                                            padding: EdgeInsets.only(left: 8.w),
                                                            child: Chip(
                                                              label: Text(
                                                                'Featured',
                                                                style: TextStyle(fontSize: 12.sp, color: Colors.white),
                                                              ),
                                                              backgroundColor: Colors.blue.shade600,
                                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 8.h),
                                                    Text(
                                                      [
                                                        "${job['company'] ?? ''}",
                                                        "${job['location'] ?? ''}",
                                                        "${job['jobType'] ?? ''}",
                                                        if (distanceText != null) distanceText,
                                                      ].where((part) => part.trim().isNotEmpty).join(' | '),
                                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Positioned(
                                                top: 6.h,
                                                right: 4.w,
                                                child: IconButton(
                                                  icon: Icon(Icons.share, color: Colors.blue.shade800, size: 22.sp),
                                                  onPressed: () => _shareJob(job),
                                                  tooltip: 'Share',
                                                ),
                                              ),
                                              Positioned(
                                                right: 4.w,
                                                bottom: 6.h,
                                                child: IconButton(
                                                  icon: Icon(
                                                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                                                    color: isSaved ? Colors.orange.shade700 : Colors.grey.shade700,
                                                    size: 24.sp,
                                                  ),
                                                  onPressed: () => _toggleSavedJob(job),
                                                  tooltip: isSaved ? 'Saved' : 'Save',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_selectedJob != null && _selectedJob!['jobId'] == job['jobId'])
                                      isJobDetailsLoading
                                          ? Center(
                                              child: CircularProgressIndicator(
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                                              ),
                                            )
                                          : Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                              child: Card(
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.w),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              _jobData?['title']?.toString() ?? _selectedJob!['title']?.toString() ?? 'Job Details',
                                                              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (_jobData?['isFeatured'] ?? _selectedJob!['isFeatured'] ?? false)
                                                            Padding(
                                                              padding: EdgeInsets.only(left: 8.w),
                                                              child: Chip(
                                                                label: Text(
                                                                  'Featured',
                                                                  style: TextStyle(fontSize: 12.sp, color: Colors.white),
                                                                ),
                                                                backgroundColor: Colors.blue.shade600,
                                                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 12.h),
                                                      Text(
                                                        '${_jobData?['company']?.toString() ?? _selectedJob!['company']?.toString() ?? 'Unknown Company'} | '
                                                        '${_jobData?['location']?.toString() ?? _selectedJob!['location']?.toString() ?? 'Unknown Location'} | '
                                                        '${_jobData?['jobType']?.toString() ?? _selectedJob!['jobType']?.toString() ?? 'Unknown Type'}',
                                                        style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700),
                                                      ),
                                                      SizedBox(height: 12.h),
                                                      Text('Salary: ${_jobData?['salary']?.toString() ?? _selectedJob!['salary']?.toString() ?? 'Not specified'}', style: TextStyle(fontSize: 16.sp)),
                                                      Text('Experience Required: ${_jobData?['experience']?.toString() ?? _selectedJob!['experience']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                                      Text('Skills: ${_formatSkillsForDisplay(_jobData?['skills'] ?? _selectedJob!['skills'])}', style: TextStyle(fontSize: 16.sp)),
                                                      Text('Education: ${_jobData?['education']?.toString() ?? _selectedJob!['education']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                                      Text('Specialization: ${_jobData?['specialization']?.toString() ?? _selectedJob!['specialization']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                                      SizedBox(height: 20.h),
                                                      Text(
                                                        'Job Description',
                                                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                      ),
                                                      SizedBox(height: 8.h),
                                                      Text(
                                                        _jobData?['description']?.toString() ?? _selectedJob!['description']?.toString() ?? 'No description provided',
                                                        style: TextStyle(fontSize: 16.sp),
                                                      ),
                                                      SizedBox(height: 20.h),
                                                      Text(
                                                        _isEligible ? 'Eligible' : 'Non-Eligible',
                                                        style: TextStyle(
                                                          fontSize: 18.sp,
                                                          fontWeight: FontWeight.bold,
                                                          color: _isEligible ? Colors.green : Colors.red,
                                                        ),
                                                      ),
                                                      if (_ineligibilityReason != null)
                                                        Padding(
                                                          padding: EdgeInsets.only(top: 8.h),
                                                          child: Text(
                                                            _ineligibilityReason!,
                                                            style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
                                                          ),
                                                        ),
                                                      SizedBox(height: 20.h),
                                                      if (FirebaseAuth.instance.currentUser?.uid == _selectedJob?['recruiterId']?.toString())
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                          children: [
                                                            AnimatedScaleButton(
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (context) => EditJobScreen(
                                                                      jobId: _selectedJob!['jobId']?.toString() ?? '',
                                                                      jobData: _jobData ?? _selectedJob!,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
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
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(Icons.edit, color: Colors.white),
                                                                    SizedBox(width: 8.w),
                                                                    const Text(
                                                                      'Edit',
                                                                      style: TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            AnimatedScaleButton(
                                                              onPressed: _deleteJob,
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [Colors.red.shade600, Colors.red.shade800],
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
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(Icons.delete, color: Colors.white),
                                                                    SizedBox(width: 8.w),
                                                                    const Text(
                                                                      'Delete',
                                                                      style: TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      if (FirebaseAuth.instance.currentUser?.uid == _selectedJob?['recruiterId']?.toString() && _applicantsStream != null)
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            SizedBox(height: 20.h),
                                                            Text(
                                                              'Applicants',
                                                              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                            ),
                                                            SizedBox(height: 10.h),
                                                            StreamBuilder<QuerySnapshot>(
                                                              stream: _applicantsStream,
                                                              builder: (context, snapshot) {
                                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                                  return const Center(
                                                                    child: CircularProgressIndicator(
                                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                                                    ),
                                                                  );
                                                                }
                                                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                                                  return const Text('No applicants yet.', style: TextStyle(fontSize: 16, color: Colors.grey));
                                                                }
                                                                return ListView.builder(
                                                                  shrinkWrap: true,
                                                                  physics: const NeverScrollableScrollPhysics(),
                                                                  itemCount: snapshot.data!.docs.length,
                                                                  itemBuilder: (context, index) {
                                                                    final applicant = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                                                    final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
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
                                                                              resume['name'] ?? 'Unknown Applicant',
                                                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                                                            ),
                                                                            subtitle: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                                                                Text('Skills: ${_formatSkillsForDisplay(applicant['skills'] ?? resume['skills'])}'),
                                                                                Text('Education: ${resume['education'] ?? 'N/A'}'),
                                                                                Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                                                                Text('Specialization: ${resume['specialization'] ?? 'N/A'}'),
                                                                                Text('Email: ${resume['email'] ?? 'N/A'}'),
                                                                                Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                                                              ],
                                                                            ),
                                                                            onTap: () {
                                                                              showDialog(
                                                                                context: context,
                                                                                builder: (context) => AlertDialog(
                                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                                                                  title: Container(
                                                                                    padding: EdgeInsets.all(16.w),
                                                                                    decoration: BoxDecoration(
                                                                                      gradient: LinearGradient(
                                                                                        colors: [Colors.blue.shade700, Colors.blue.shade900],
                                                                                        begin: Alignment.topLeft,
                                                                                        end: Alignment.bottomRight,
                                                                                      ),
                                                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                                                    ),
                                                                                    child: Text(
                                                                                      'Applicant: ${resume['name'] ?? 'Unknown'}',
                                                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                                                    ),
                                                                                  ),
                                                                                  content: SingleChildScrollView(
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                                                                        Text('Skills: ${_formatSkillsForDisplay(applicant['skills'] ?? resume['skills'])}'),
                                                                                        Text('Education: ${resume['education'] ?? 'N/A'}'),
                                                                                        Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                                                                        Text('Specialization: ${resume['specialization'] ?? 'N/A'}'),
                                                                                        Text('Email: ${resume['email'] ?? 'N/A'}'),
                                                                                        Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                                                                        Text('Current Company: ${resume['currentCompany'] ?? 'N/A'}'),
                                                                                        Text('Current CTC: ${resume['currentCtc'] ?? 'N/A'}'),
                                                                                        Text('Expected CTC: ${resume['expectedCtc'] ?? 'N/A'}'),
                                                                                        Text('Cover Letter: ${applicant['coverLetter'] ?? 'N/A'}'),
                                                                                        if (resume['photoUrl']?.isNotEmpty ?? false)
                                                                                          Padding(
                                                                                            padding: EdgeInsets.only(top: 8.h),
                                                                                            child: ClipRRect(
                                                                                              borderRadius: BorderRadius.circular(8.r),
                                                                                              child: Image.network(resume['photoUrl'], height: 100.h, fit: BoxFit.cover),
                                                                                            ),
                                                                                          ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                  actions: [
                                                                                    TextButton(
                                                                                      onPressed: () => Navigator.pop(context),
                                                                                      child: const Text('Close', style: TextStyle(color: Colors.teal)),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      if (FirebaseAuth.instance.currentUser?.uid != _selectedJob?['recruiterId']?.toString() && _isEligible)
                                                        AnimatedScaleButton(
                                                          onPressed: isApplied ? null : () => _applyToJob(_selectedJob!),
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: isApplied
                                                                    ? [Colors.red.shade700, Colors.green.shade400]
                                                                    : [Colors.blue.shade700, Colors.teal.shade400],
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
                                                            child: Text(
                                                              isApplied ? 'Applied' : 'Apply Now',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 16.sp,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                  ],
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
