// ignore_for_file: unnecessary_cast, deprecated_member_use, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:math';
import 'package:flutter/services.dart'; // Added for MethodChannel
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:naukariwala/main.dart'; // For exponential backoff

class AccountInfo {
  final String email;
  final String? role;
  final String? name;
  String? password; // Made non-final to allow setting after loading

  AccountInfo({
    required this.email,
    this.role,
    this.name,
    this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'role': role,
    'name': name,
  };

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
    email: json['email'],
    role: json['role'],
    name: json['name'],
  );
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<User> _getFreshAuthenticatedUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Session expired. Please login again and retry.',
      );
    }
    await user.getIdToken(true);
    return user;
  }

  // Helper method to get Play Integrity token
  Future<String?> getPlayIntegrityToken() async {
    const platform = MethodChannel('play_integrity_channel');
    try {
      final String? token = await platform.invokeMethod('getPlayIntegrityToken');
      print('✅ Play Integrity Token: $token');
      return token;
    } catch (e) {
      print('❌ Error getting Play Integrity token: $e');
      return null;
    }
  }

  Future<String?> _getFcmToken(String recipientId) async {
    try {
      final doc = await _firestore.collection('UsersIndex').doc(recipientId).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token == null) {
        dev.log('[2025-10-10 00:35 IST] No FCM token for recipient $recipientId', name: 'AuthService');
      }
      return token;
    } catch (e) {
      dev.log('[2025-10-10 00:35 IST] Error fetching FCM token for $recipientId: $e', name: 'AuthService', error: e);
      return null;
    }
  }

  Future<void> _sendFcmNotification({
    required String recipientFcmToken,
    required String title,
    required String body,
    required Map<String, String> data,
    String? integrityToken,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        dev.log('[2025-10-10 00:35 IST] No authenticated user for FCM notification', name: 'AuthService');
        return;
      }
      await user.getIdToken(); // Ensure token is refreshed

      // Fetch Play Integrity token with development mode bypass
      String? integrityToken;
      if (kDebugMode) {
        print('⚠️ Using placeholder Play Integrity token for development');
        integrityToken = 'DEVELOPMENT_PLACEHOLDER_TOKEN';
      } else {
        integrityToken = await getPlayIntegrityToken();
      }

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable(
        'sendNotification',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );
      final response = await callable.call({
        'integrityToken': integrityToken, // Added Play Integrity token
        'token': recipientFcmToken,
        'title': title,
        'body': body,
        'data': {
          ...data,
          'notificationId': data['notificationId'] ?? '', // Ensure notificationId is included
          'message': data['message'] ?? '', // Include message for custom handling
        },
      });

      if (response.data['success'] == true) {
        dev.log('[2025-10-10 00:35 IST] FCM notification sent via Cloud Function to $recipientFcmToken', name: 'AuthService');
      } else {
        dev.log('[2025-10-10 00:35 IST] Cloud Function response: ${response.data}', name: 'AuthService');
      }
    } catch (e, stackTrace) {
      dev.log('[2025-10-10 00:35 IST] Error sending FCM notification via Cloud Function: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
    }
  }

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

  Future<void> storeSignupData({
    required bool isRecruiter,
    required Map<String, dynamic> data,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';

    try {
      dev.log("[2025-10-10 00:35 IST] Writing to $collection/$uid", name: 'AuthService');

      String mobileNumber = data['Mobile Number']?.toString().trim() ??
          data['mobileNumber']?.toString().trim() ??
          _auth.currentUser?.phoneNumber?.toString().trim() ??
          '';

      if (mobileNumber.isEmpty) {
        dev.log("[2025-10-10 00:35 IST] Mobile number is missing for UID: $uid. Input data: $data, FirebaseAuth phoneNumber: ${_auth.currentUser?.phoneNumber}", name: 'AuthService');
        throw const AuthException("Mobile number is required");
      }

      final mobileNumberRegex = RegExp(r'^\+\d{10,15}$');
      if (!mobileNumberRegex.hasMatch(mobileNumber)) {
        dev.log("[2025-10-10 00:35 IST] Invalid mobile number format for UID: $uid, mobileNumber: $mobileNumber", name: 'AuthService');
        throw const AuthException("Invalid mobile number format. Must start with '+' followed by 10-15 digits.");
      }

      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
        dev.log("[2025-10-10 00:35 IST] Fetched FCM token for $uid: $fcmToken", name: 'AuthService');
      } catch (e) {
        dev.log("[2025-10-10 00:35 IST] Error fetching FCM token for $uid: $e", name: 'AuthService', error: e);
      }

      final normalizedData = {
        'uid': uid,
        'email': data['Email Id']?.toString().trim() ?? data['email']?.toString().trim() ?? _auth.currentUser?.email?.toString().trim() ?? '',
        'mobileNumber': mobileNumber,
        'name': data['Name']?.toString().trim() ?? '',
        'role': isRecruiter ? 'recruiter' : 'seeker',
        'fcmToken': fcmToken,
        ...data,
      };

      normalizedData.remove('UID');
      normalizedData.remove('Email Id');
      normalizedData.remove('Mobile Number');
      normalizedData.remove('Name');

      if (!isRecruiter) {
        final specialization = normalizedData['specialization'] as String?;
        if (specialization == null || !specializationOptions.contains(specialization)) {
          normalizedData['specialization'] = 'Others';
          dev.log("[2025-10-10 00:35 IST] Invalid or missing specialization '$specialization', defaulting to 'Others'", name: 'AuthService');
        }

        final skills = normalizedData['skills'] is String
            ? (normalizedData['skills'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
            : normalizedData['skills'] as List<dynamic>? ?? [];
        final validSkills = skillsBySpecialization[normalizedData['specialization']] ?? skillsBySpecialization['Others']!;
        normalizedData['skills'] = skills
            .cast<String>()
            .where((skill) => validSkills.contains(skill))
            .toList();
        if (normalizedData['skills'].isEmpty) {
          dev.log("[2025-10-10 00:35 IST] No valid skills provided for UID: $uid, specialization: ${normalizedData['specialization']}", name: 'AuthService');
        }

        if (normalizedData['education'] == null || normalizedData['education'] is! String) {
          normalizedData['education'] = '';
          dev.log("[2025-10-10 00:35 IST] Invalid or missing education for UID: $uid, defaulting to empty", name: 'AuthService');
        }
      }

      if (isRecruiter && normalizedData['companyName'] == null) {
        dev.log("[2025-10-10 00:35 IST] Missing company field for recruiter UID: $uid", name: 'AuthService');
        throw const AuthException("Company name is required for recruiters");
      }

      final batch = _firestore.batch();
      batch.set(_firestore.collection(collection).doc(uid), normalizedData, SetOptions(merge: true));
      batch.set(
        _firestore.collection('UsersIndex').doc(uid),
        {
          'uid': uid,
          'role': isRecruiter ? 'recruiter' : 'seeker',
          'mobileNumber': mobileNumber,
          'name': normalizedData['name'],
          'fcmToken': fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      dev.log("[2025-10-10 00:35 IST] Successfully stored signup data for $collection/$uid", name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log("[2025-10-10 00:35 IST] storeSignupData ERROR for UID: $uid, isRecruiter: $isRecruiter: $e", name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to store signup data: ${e.code} - ${e.message}. Check Firestore permissions for $collection/$uid.');
      }
      rethrow;
    }
  }

  Future<void> setupFcmTokenRefresh() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        dev.log('[2025-10-10 00:35 IST] No user logged in, skipping FCM token refresh', name: 'AuthService');
        return;
      }

      String? currentToken = await _messaging.getToken();
      if (currentToken != null) {
        await _firestore.collection('UsersIndex').doc(uid).set(
          {'fcmToken': currentToken},
          SetOptions(merge: true),
        );
        dev.log('[2025-10-10 00:35 IST] Initial FCM token saved for $uid: $currentToken', name: 'AuthService');
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        if (newToken != currentToken) {
          await _firestore.collection('UsersIndex').doc(uid).set(
            {'fcmToken': newToken},
            SetOptions(merge: true),
          );
          dev.log('[2025-10-10 00:35 IST] FCM token refreshed for $uid: $newToken', name: 'AuthService');
          currentToken = newToken;
        }
      }, onError: (error) {
        dev.log('[2025-10-10 00:35 IST] FCM token refresh error for $uid: $error', name: 'AuthService', error: error);
      });
    } catch (e) {
      dev.log('[2025-10-10 00:35 IST] Error setting up FCM token refresh: $e', name: 'AuthService', error: e);
    }
  }

  Future<String> uploadSeekerResume(File file) async {
    final user = await _getFreshAuthenticatedUser();
    final uid = user.uid;

    try {
      dev.log('[2025-10-10 00:35 IST] Uploading resume for seeker $uid', name: 'AuthService');
      final ref = _storage.ref().child('seeker_resumes/$uid/resume.pdf');
      TaskSnapshot uploadTask;
      try {
        uploadTask = await ref.putFile(
          file,
          SettableMetadata(contentType: 'application/pdf'),
        );
      } on FirebaseException catch (e) {
        if (e.code == 'unauthenticated') {
          await user.getIdToken(true);
          uploadTask = await ref.putFile(
            file,
            SettableMetadata(contentType: 'application/pdf'),
          );
        } else {
          rethrow;
        }
      }
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await _firestore.collection('Seekers').doc(uid).set(
        {'resumeUrl': downloadUrl},
        SetOptions(merge: true),
      );

      dev.log('[2025-10-10 00:35 IST] Resume uploaded and saved for seeker $uid: $downloadUrl', name: 'AuthService');
      return downloadUrl;
    } catch (e, stackTrace) {
      dev.log('[2025-10-10 00:35 IST] uploadSeekerResume ERROR for UID: $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to upload resume: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<String> uploadProfilePhoto({
    required File file,
    required bool isRecruiter,
  }) async {
    final user = await _getFreshAuthenticatedUser();
    final uid = user.uid;

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';
    final storagePath = isRecruiter
        ? 'company_logos/$uid/logo.png'
        : 'seeker_photos/$uid/photo.png';
    final extension = file.path.split('.').last.toLowerCase();
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

    try {
      dev.log(
        '[2026-02-21 14:30 IST] Uploading profile photo for $collection/$uid',
        name: 'AuthService',
      );
      final ref = _storage.ref().child(storagePath);
      TaskSnapshot uploadTask;
      try {
        uploadTask = await ref.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
      } on FirebaseException catch (e) {
        if (e.code == 'unauthenticated') {
          await user.getIdToken(true);
          uploadTask = await ref.putFile(
            file,
            SettableMetadata(contentType: contentType),
          );
        } else {
          rethrow;
        }
      }
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(collection).doc(uid),
        {'photoUrl': downloadUrl},
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('UsersIndex').doc(uid),
        {'photoUrl': downloadUrl, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      dev.log(
        '[2026-02-21 14:30 IST] Profile photo uploaded for $collection/$uid: $downloadUrl',
        name: 'AuthService',
      );
      return downloadUrl;
    } catch (e, stackTrace) {
      dev.log(
        '[2026-02-21 14:30 IST] uploadProfilePhoto ERROR for UID: $uid: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is FirebaseException) {
        if (e.code == 'unauthenticated') {
          throw const AuthException(
            'Session expired. Please login again and retry.',
          );
        }
        throw AuthException(
          'Failed to upload profile photo: ${e.code} - ${e.message}',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchProfileData({required bool isRecruiter}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';
    try {
      final doc = await _firestore.collection(collection).doc(uid).get();
      if (doc.exists) {
        dev.log("[2025-10-10 00:35 IST] Fetched profile data for $collection/$uid", name: 'AuthService');
        return doc.data();
      }
      dev.log("[2025-10-10 00:35 IST] No profile found for $collection/$uid", name: 'AuthService');
      return null;
    } catch (e, stackTrace) {
      dev.log("[2025-10-10 00:35 IST] fetchProfileData ERROR for $collection/$uid: $e", name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to fetch profile: ${e.code} - ${e.message}. Check Firestore permissions for $collection/$uid.');
      }
      rethrow;
    }
  }

  Future<void> applyToJob({
    required String jobId,
    required String jobTitle,
    required String recruiterId,
    required String coverLetter,
    required Map<String, dynamic> seekerProfile,
    required String fcmToken,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('User not logged in');

    final applicationId = '${uid}_$jobId';
    final batch = _firestore.batch();
    final applicationRef = _firestore.collection('Applications').doc(applicationId);

    final jobDoc = await _firestore
        .collection('Recruiters')
        .doc(recruiterId)
        .collection('Jobs')
        .doc(jobId)
        .get();

    if (!jobDoc.exists) {
      throw const AuthException('Job does not exist');
    }
    final jobData = jobDoc.data()!;
    if (jobData['status'] != 'open') {
      throw const AuthException('This job is no longer accepting applications');
    }

    final requiredSkills = (jobData['requiredSkills'] as List<dynamic>?)?.cast<String>() ?? [];
    final minExperience = (jobData['minExperience'] as num?)?.toDouble() ?? 0.0;
    final requiredEducation = (jobData['requiredEducation'] as String?)?.toLowerCase() ?? '';
    final requiredSpecialization = (jobData['requiredSpecialization'] as String?)?.toLowerCase() ?? '';

    final seekerSkills = seekerProfile['skills'] is String
        ? seekerProfile['skills'].split(',').map((s) => s.trim().toLowerCase()).toList()
        : (seekerProfile['skills'] as List?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final seekerExperience = double.tryParse(seekerProfile['experience']?.toString() ?? '0') ?? 0.0;
    final seekerEducation = (seekerProfile['education'] as String?)?.toLowerCase() ?? '';
    final seekerSpecialization = (seekerProfile['specialization'] as String?)?.toLowerCase() ?? '';

    if (requiredSkills.isNotEmpty) {
      final matchingSkills = requiredSkills.where((skill) => seekerSkills.contains(skill.toLowerCase())).length;
      final skillMatchPercentage = (matchingSkills / requiredSkills.length) * 100;
      if (skillMatchPercentage < 30) {
        throw AuthException('Insufficient skills match. Required: ${requiredSkills.join(', ')}');
      }
    }

    if (seekerExperience < minExperience) {
      throw AuthException('Insufficient experience. Required: $minExperience years');
    }

    if (requiredEducation.isNotEmpty && seekerEducation != requiredEducation) {
      throw AuthException('Education does not match. Required: $requiredEducation');
    }

    if (requiredSpecialization.isNotEmpty && seekerSpecialization != requiredSpecialization) {
      throw AuthException('Specialization does not match. Required: $requiredSpecialization');
    }

    final applicationData = {
      'seekerId': uid,
      'jobId': jobId,
      'recruiterId': recruiterId,
      'status': 'Applied',
      'appliedAt': FieldValue.serverTimestamp(),
      'jobTitle': jobTitle,
      'company': jobData['company']?.toString() ?? 'Unknown',
      'coverLetter': coverLetter,
      'photoUrl': seekerProfile['photoUrl']?.toString() ?? seekerProfile['profilePhotoUrl']?.toString() ?? '',
      'resume': {
        'name': seekerProfile['name']?.toString() ?? '',
        'email': seekerProfile['email']?.toString() ?? '',
        'mobileNumber': seekerProfile['mobileNumber']?.toString() ?? '',
        'skills': seekerSkills,
        'education': seekerProfile['education']?.toString() ?? '',
        'experience': seekerProfile['experience']?.toString() ?? '',
        'specialization': seekerProfile['specialization']?.toString() ?? 'Others',
        'currentCompany': seekerProfile['currentCompany']?.toString() ?? '',
        'currentCtc': seekerProfile['currentCtc']?.toString() ?? '',
        'expectedCtc': seekerProfile['expectedCtc']?.toString() ?? '',
        'cvUrl': seekerProfile['resumeUrl']?.toString() ?? '',
        'photoUrl': seekerProfile['photoUrl']?.toString() ?? seekerProfile['profilePhotoUrl']?.toString() ?? '',
      },
      'fcmToken': fcmToken,
    };

    batch.set(applicationRef, applicationData);
    final notificationId = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc().id;
    batch.set(
      _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc(notificationId),
      {
        'to': recruiterId,
        'recipientId': recruiterId,
        'from': uid,
        'jobId': jobId,
        'notificationId': notificationId,
        'type': 'application',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'New application for $jobTitle from ${seekerProfile['name'] ?? 'a seeker'}',
      },
    );

    await batch.commit();
    dev.log('[2025-10-10 00:35 IST] Applied to job $jobId by seeker $uid', name: 'AuthService');

    final recruiterFcmToken = await _getFcmToken(recruiterId);
    if (recruiterFcmToken != null) {
      await _sendFcmNotification(
        recipientFcmToken: recruiterFcmToken,
        title: 'New Job Application',
        body: 'New application for $jobTitle from ${seekerProfile['name'] ?? 'a seeker'}',
        data: {
          'notificationId': notificationId,
          'jobId': jobId,
          'seekerId': uid,
          'from': uid,
          'type': 'application',
        },
      );
    }
  }

  Future<void> scheduleInterview({
    required String jobId,
    required String seekerId,
    required DateTime interviewDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('User not logged in');

    final applicationId = '${seekerId}_$jobId';
    final batch = _firestore.batch();
    final applicationRef = _firestore.collection('Applications').doc(applicationId);

    final appDoc = await applicationRef.get();
    if (!appDoc.exists) {
      throw const AuthException('Application does not exist');
    }
    final appData = appDoc.data()!;
    if (appData['recruiterId'] != uid) {
      throw const AuthException('Not authorized to schedule interview for this job');
    }

    batch.update(applicationRef, {
      'status': 'Interview Scheduled',
      'interviewDate': Timestamp.fromDate(interviewDate),
      'interviewConfirmationStatus': 'pending',
      'interviewConfirmationAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
    batch.set(
      _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc(notificationId),
      {
        'to': seekerId,
        'recipientId': seekerId,
        'from': uid,
        'jobId': jobId,
        'jobTitle': appData['jobTitle']?.toString() ?? 'Untitled',
        'seekerId': seekerId,
        'notificationId': notificationId,
        'type': 'interview_confirmation_request',
        'interviewDate': Timestamp.fromDate(interviewDate),
        'actionStatus': 'pending',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Interview scheduled on ${DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate)}. Please confirm your availability.',
      },
    );

    await batch.commit();
    dev.log('[2025-10-10 00:35 IST] Scheduled interview for job $jobId, seeker $seekerId by recruiter $uid', name: 'AuthService');

    final seekerFcmToken = await _getFcmToken(seekerId);
    if (seekerFcmToken != null) {
      await _sendFcmNotification(
        recipientFcmToken: seekerFcmToken,
        title: 'Interview Confirmation',
        body: 'Interview scheduled on ${DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate)}. Confirm availability.',
        data: {
          'notificationId': notificationId,
          'jobId': jobId,
          'seekerId': seekerId,
          'from': uid,
          'type': 'interview_confirmation_request',
        },
      );
    }
  }

  Future<void> respondToInterviewConfirmation({
    required String jobId,
    required String seekerId,
    required String notificationId,
    required bool isAvailable,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('User not logged in');
    if (uid != seekerId) throw const AuthException('Not authorized to respond for this seeker');

    final applicationId = '${seekerId}_$jobId';
    final applicationRef = _firestore.collection('Applications').doc(applicationId);
    final notificationRef = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc(notificationId);

    final appDoc = await applicationRef.get();
    if (!appDoc.exists) {
      throw const AuthException('Application does not exist');
    }
    final appData = appDoc.data()!;
    final recruiterId = appData['recruiterId']?.toString();
    if (recruiterId == null || recruiterId.isEmpty) {
      throw const AuthException('Invalid recruiter for this application');
    }

    final interviewDate = appData['interviewDate'] as Timestamp?;
    final jobTitle = appData['jobTitle']?.toString() ?? 'Untitled';
    final newStatus = isAvailable ? 'accepted' : 'declined';

    final batch = _firestore.batch();

    batch.update(applicationRef, {
      'interviewConfirmationStatus': newStatus,
      'interviewConfirmationAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mark the original notification as actioned so the UI can disable buttons.
    batch.set(notificationRef, {
      'actionStatus': newStatus,
      'actionedAt': FieldValue.serverTimestamp(),
      'read': true,
    }, SetOptions(merge: true));

    final recruiterNotificationId = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc().id;
    final recruiterNotifRef = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc(recruiterNotificationId);
    final interviewStr = interviewDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate()) : 'N/A';
    final recruiterMessage = isAvailable
        ? 'Seeker confirmed availability for "$jobTitle" interview on $interviewStr.'
        : 'Seeker is not available for "$jobTitle" interview on $interviewStr.';

    batch.set(recruiterNotifRef, {
      'to': recruiterId,
      'recipientId': recruiterId,
      'from': seekerId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'seekerId': seekerId,
      'notificationId': recruiterNotificationId,
      'type': 'interview_confirmation_response',
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'message': recruiterMessage,
      'interviewDate': interviewDate,
      'response': newStatus,
    });

    await batch.commit();

    final recruiterFcmToken = await _getFcmToken(recruiterId);
    if (recruiterFcmToken != null) {
      await _sendFcmNotification(
        recipientFcmToken: recruiterFcmToken,
        title: 'Interview Confirmation',
        body: recruiterMessage,
        data: {
          'notificationId': recruiterNotificationId,
          'jobId': jobId,
          'seekerId': seekerId,
          'from': seekerId,
          'type': 'interview_confirmation_response',
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[2025-10-10 00:35 IST] No authenticated user in fetchAppliedSeekers', name: 'AuthService');
      throw const AuthException('User not logged in');
    }

    try {
      final snapshot = await _firestore
          .collection('Applications')
          .where('recruiterId', isEqualTo: uid)
          .get();
      dev.log('[2025-10-10 00:35 IST] Fetched ${snapshot.docs.length} applicants for recruiter $uid', name: 'AuthService');
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      dev.log('[2025-10-10 00:35 IST] Error fetching applied seekers for $uid: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<String> getChatId({
    required String seekerId,
    required String jobId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('User not logged in');

    final appDoc = await _firestore.collection('Applications').doc('${seekerId}_$jobId').get();
    if (!appDoc.exists) {
      throw const AuthException('Application does not exist');
    }
    final appData = appDoc.data()!;
    final recruiterId = appData['recruiterId'] as String;

    final participants = [uid, recruiterId == uid ? seekerId : recruiterId];
    participants.sort();
    final chatId = '${participants[0]}_${participants[1]}';
    dev.log('[2025-10-10 00:35 IST] Generated chatId $chatId for seeker $seekerId, job $jobId', name: 'AuthService');
    return chatId;
  }

  Future<void> handleAction({
    required String action,
    required String jobId,
    required String seekerId,
    Map<String, dynamic>? additionalData,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    final applicationId = '${seekerId}_$jobId';
    try {
      final applicationRef = _firestore.collection('Applications').doc(applicationId);
      final appDoc = await applicationRef.get();
      if (!appDoc.exists) {
        dev.log('[2025-10-10 00:35 IST] Application $applicationId not found', name: 'AuthService');
        throw const AuthException('Application not found');
      }
      final jobTitle = appDoc.data()!['jobTitle']?.toString() ?? 'Untitled';
      dev.log('[2025-10-10 00:35 IST] Processing action $action for application $applicationId', name: 'AuthService');

      final batch = _firestore.batch();
      final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
      final notifRef = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc(notificationId);

      String notificationMessage = '';
      String notificationType = 'status_update';

      switch (action.toLowerCase()) {
        case 'shortlist':
          dev.log('[2025-10-10 00:35 IST] Shortlisting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.set(_firestore.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId), {
            'seekerId': seekerId,
            'jobId': jobId,
            'recruiterId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          batch.update(applicationRef, {'status': 'Shortlisted', 'interviewDate': null, 'updatedAt': FieldValue.serverTimestamp()});
          notificationMessage = 'You have been shortlisted for "$jobTitle"!';
          break;

        case 'reject':
          dev.log('[2025-10-10 00:35 IST] Rejecting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.update(applicationRef, {'status': 'Rejected', 'interviewDate': null, 'updatedAt': FieldValue.serverTimestamp()});
          notificationMessage = 'Your application for "$jobTitle" has been rejected.';
          break;

        case 'schedule':
          dev.log('[2025-10-10 00:35 IST] Scheduling interview for seeker $seekerId, job $jobId', name: 'AuthService');
          final interviewDate = additionalData?['interviewDate'] as Timestamp?;
          if (interviewDate == null) {
            dev.log('[2025-10-10 00:35 IST] Missing interviewDate for schedule action for application $applicationId', name: 'AuthService');
            throw const AuthException('Interview date is required for scheduling');
          }
          batch.update(applicationRef, {
            'status': 'Interview Scheduled',
            'interviewDate': interviewDate,
            'interviewConfirmationStatus': 'pending',
            'interviewConfirmationAt': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          notificationMessage = 'Interview scheduled on ${DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate())}. Please confirm your availability.';
          notificationType = 'interview_confirmation_request';
          break;

        default:
          dev.log('[2025-10-10 00:35 IST] Invalid action: $action for application $applicationId', name: 'AuthService');
          throw const AuthException('Invalid action');
      }

      batch.set(notifRef, {
        'to': seekerId,
        'from': uid,
        'message': notificationMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': notificationType,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'notificationId': notificationId,
        if (notificationType == 'interview_confirmation_request') ...{
          'seekerId': seekerId,
          'interviewDate': additionalData?['interviewDate'],
          'actionStatus': 'pending',
        },
      });

      await batch.commit();
      dev.log('[2025-10-10 00:35 IST] Action $action completed for application $applicationId', name: 'AuthService');

      final seekerFcmToken = await _getFcmToken(seekerId);
      if (seekerFcmToken != null) {
        await _sendFcmNotification(
          recipientFcmToken: seekerFcmToken,
          title: notificationType == 'interview_confirmation_request' ? 'Interview Confirmation' : 'Application Update',
          body: notificationMessage,
          data: {
            'notificationId': notificationId,
            'jobId': jobId,
            'seekerId': seekerId,
            'from': uid,
            'type': notificationType,
          },
        );
      }
    } catch (e, stackTrace) {
      dev.log('[2025-10-10 00:35 IST] handleAction ERROR for action $action, job $jobId, seeker $seekerId: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('[2025-10-10 00:35 IST] Firebase error details: code=${e.code}, message=${e.message}, path=Applications/$applicationId or Shortlisted/$jobId/Seekers/$seekerId or Notifications', name: 'AuthService');
        throw AuthException('Action failed: ${e.code} - ${e.message}. Check Firestore rules.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchScheduledCalls() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (!recruiterDoc.exists) {
        dev.log('[2025-10-10 00:35 IST] User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }

      final callsSnapshot = await _firestore
          .collection('Applications')
          .where('recruiterId', isEqualTo: uid)
          .where('status', isEqualTo: 'Interview Scheduled')
          .orderBy('interviewDate', descending: false)
          .get();

      final List<Map<String, dynamic>> calls = [];
      for (final call in callsSnapshot.docs) {
        final data = call.data();
        final seekerId = data['seekerId'] as String? ?? '';
        String? name = data['resume']?['name']?.toString() ?? seekerId;
        calls.add({
          'seekerId': seekerId,
          'jobId': data['jobId'] as String? ?? '',
          'jobTitle': data['jobTitle'] as String? ?? '',
          'interviewDate': data['interviewDate'],
          'resume': data['resume'] as Map<String, dynamic>? ?? {},
          'status': data['status'] as String? ?? 'Interview Scheduled',
          'name': name,
        });
      }
      dev.log('[2025-10-10 00:35 IST] Returning ${calls.length} scheduled calls for $uid', name: 'AuthService');
      return calls;
    } catch (e, stackTrace) {
      dev.log('[2025-10-10 00:35 IST] fetchScheduledCalls ERROR: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException("Failed to fetch scheduled calls: ${e.code} - ${e.message}. Check Firestore permissions.");
      }
      rethrow;
    }
  }
Future<void> sendMessage(
  String recipientId,
  String jobId,
  String message, {
  String status = 'sent',
}) async {
  final senderId = FirebaseAuth.instance.currentUser!.uid;
  try {
    String seekerId;
    String applicationId;
    if (senderId == recipientId) {
      throw Exception('Cannot send message to self');
    }
    final senderAppDoc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc('${senderId}_$jobId')
        .get();
    if (senderAppDoc.exists && senderAppDoc.data()?['seekerId'] == senderId) {
      seekerId = senderId;
      applicationId = '${senderId}_$jobId';
    } else {
      final recipientAppDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc('${recipientId}_$jobId')
          .get();
      if (!recipientAppDoc.exists) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Application ${recipientId}_$jobId not found', name: 'AuthService');
        throw Exception('Application does not exist');
      }
      seekerId = recipientId;
      applicationId = '${recipientId}_$jobId';
    }

    final appDoc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(applicationId)
        .get();
    if (!appDoc.exists) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Application $applicationId not found', name: 'AuthService');
      throw Exception('Application does not exist');
    }
    final appData = appDoc.data()!;
    if (appData['jobId'] != jobId || appData['seekerId'] != seekerId || appData['recruiterId'] is! String) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Invalid application data for $applicationId: $appData', name: 'AuthService');
      throw Exception('Invalid application data');
    }

    final participants = [senderId, recipientId];
    participants.sort();
    final chatId = '${participants[0]}_${participants[1]}';
    final messageDocRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc(chatId)
        .collection('Chats')
        .doc();
    await messageDocRef.set({
      'senderId': senderId,
      'recipientId': recipientId,
      'jobId': jobId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
    });

    final notificationId = FirebaseFirestore.instance.collection('SeekerNotifications').doc(recipientId).collection('Notifications').doc().id;
    await FirebaseFirestore.instance.collection(recipientId == seekerId ? 'SeekerNotifications' : 'RecruiterNotifications')
        .doc(recipientId)
        .collection('Notifications')
        .doc(notificationId)
        .set({
      'to': recipientId,
      'recipientId': recipientId,
      'from': senderId,
      'jobId': jobId,
      'jobTitle': appData['jobTitle']?.toString() ?? 'Untitled',
      'notificationId': notificationId,
      'type': 'message',
      'chatId': chatId,
      'seekerId': seekerId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'message': 'New message: $message',
    });

    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Message sent from $senderId to $recipientId for job $jobId with chatId $chatId, status: $status', name: 'AuthService');

    final recipientFcmToken = await _getFcmToken(recipientId);
    if (recipientFcmToken != null) {
      try {
        // Fetch Play Integrity token with development mode bypass
        String? integrityToken;
        if (kDebugMode) {
          print('⚠️ Using placeholder Play Integrity token for development');
          integrityToken = 'DEVELOPMENT_PLACEHOLDER_TOKEN';
        } else {
          integrityToken = await getPlayIntegrityToken();
        }

        await _sendFcmNotification(
          recipientFcmToken: recipientFcmToken,
          title: 'New Message',
          body: message,
          data: {
            'notificationId': notificationId,
            'chatId': chatId,
            'jobId': jobId,
            'seekerId': seekerId,
            'from': senderId,
            'type': 'message',
          },
          integrityToken: integrityToken, // Pass the integrity token
        );
      } catch (fcmError) {
        // Log FCM error but don't fail the message send - notification is secondary
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] FCM notification failed (message still sent): $fcmError', name: 'AuthService', error: fcmError);
      }
    }
  } catch (e) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error sending message from $senderId to $recipientId for job $jobId: $e', name: 'AuthService', error: e);
    throw AuthException('Failed to send message: $e');
  }
}

  Future<bool> isSignedIn() async => _auth.currentUser != null;

  User? getCurrentUser() => _auth.currentUser;

  Future<void> signOut() async => await _auth.signOut();

  /// Save account information after successful login
  Future<void> saveAccountInfo(String email, String password, {String? role, String? name}) async {
    try {
      // Get existing accounts
      final accounts = await getSavedAccounts();

      // Remove if already exists
      accounts.removeWhere((acc) => acc.email == email);

      // Add new account
      final newAccount = AccountInfo(
        email: email,
        role: role,
        name: name,
        password: password,
      );
      accounts.insert(0, newAccount); // Add to beginning

      // Keep only last 5 accounts
      if (accounts.length > 5) {
        accounts.removeRange(5, accounts.length);
      }

      // Save to secure storage
      final accountsJson = accounts.map((acc) => acc.toJson()).toList();
      await _secureStorage.write(key: 'saved_accounts', value: jsonEncode(accountsJson));

      // Save passwords securely
      for (final acc in accounts) {
        if (acc.password != null) {
          await _secureStorage.write(key: 'password_${acc.email}', value: acc.password);
        }
      }

      dev.log('Account info saved for: $email', name: 'AuthService');
    } catch (e) {
      dev.log('Error saving account info: $e', name: 'AuthService', error: e);
    }
  }

  /// Retrieve saved accounts
  Future<List<AccountInfo>> getSavedAccounts() async {
    try {
      final accountsJson = await _secureStorage.read(key: 'saved_accounts');
      if (accountsJson == null) return [];

      final accountsData = jsonDecode(accountsJson) as List;
      final accounts = accountsData.map((data) => AccountInfo.fromJson(data)).toList();

      // Load passwords
      for (final acc in accounts) {
        acc.password = await _secureStorage.read(key: 'password_${acc.email}');
      }

      dev.log('Retrieved ${accounts.length} saved accounts', name: 'AuthService');
      return accounts;
    } catch (e) {
      dev.log('Error retrieving saved accounts: $e', name: 'AuthService', error: e);
      return [];
    }
  }

  /// Clear all saved accounts
  Future<void> clearSavedAccounts() async {
    try {
      final accounts = await getSavedAccounts();
      for (final acc in accounts) {
        await _secureStorage.delete(key: 'password_${acc.email}');
      }
      await _secureStorage.delete(key: 'saved_accounts');
      dev.log('All saved accounts cleared', name: 'AuthService');
    } catch (e) {
      dev.log('Error clearing saved accounts: $e', name: 'AuthService', error: e);
    }
  }

  /// Legacy methods for backward compatibility
  Future<void> saveUserEmail(String email) async {
    // Keep for backward compatibility, but don't use
  }

  Future<String?> getSavedEmail() async {
    final accounts = await getSavedAccounts();
    return accounts.isNotEmpty ? accounts.first.email : null;
  }

  Future<void> clearSavedEmail() async {
    // Keep for backward compatibility
  }

  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String?;
        dev.log("[2025-10-10 00:35 IST] Role found for $uid: $role", name: 'AuthService');
        return role;
      }
      dev.log("[2025-10-10 00:35 IST] No role found for $uid in UsersIndex", name: 'AuthService');
      return null;
    } catch (e) {
      dev.log("[2025-10-10 00:35 IST] getUserRole ERROR: $e", name: 'AuthService', error: e);
      return null;
    }
  }
}

// Main function to initialize App Check (call before AuthService usage)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Activate App Check with Play Integrity for production
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest, // Optional, for iOS if needed
  );

  // Add retry logic for App Check token retrieval
  await _initializeAppCheckWithRetry();

  runApp(const NaukariwalaApp()); // Replace with your app's widget
}

Future<void> _initializeAppCheckWithRetry() async {
  int attempts = 0;
  const maxAttempts = 5;
  while (attempts < maxAttempts) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      dev.log('[2025-10-10 00:35 IST] App Check token retrieved successfully: $token', name: 'AuthService');
      return;
    } catch (e) {
      if (e.toString().contains('Too many attempts')) {
        attempts++;
        final delay = pow(2, attempts).toInt() * 1000; // Exponential backoff (2^attempts seconds)
        dev.log('[2025-10-10 00:35 IST] App Check retry $attempts after $delay ms due to: $e', name: 'AuthService');
        await Future.delayed(Duration(milliseconds: delay));
      } else {
        dev.log('[2025-10-10 00:35 IST] App Check error (non-rate-limit): $e', name: 'AuthService', error: e);
        rethrow;
      }
    }
  }
  dev.log('[2025-10-10 00:35 IST] App Check failed after max retries', name: 'AuthService');
  throw Exception('App Check initialization failed after max retries');
}
