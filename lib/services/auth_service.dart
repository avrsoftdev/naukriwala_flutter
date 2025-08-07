import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:intl/intl.dart';
import 'auth_middleware.dart';

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

  // Specialization options (same as ProfileScreen)
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

  // Skills by specialization (same as ProfileScreen)
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

  Future<void> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      dev.log('Signing in with phone credential', name: 'AuthService');
      await _auth.signInWithCredential(credential);
      dev.log('Phone authentication successful for UID: ${_auth.currentUser?.uid}', name: 'AuthService');
    } catch (e) {
      dev.log('signInWithPhoneCredential ERROR: $e', name: 'AuthService', error: e);
      if (e is FirebaseAuthException) {
        throw AuthException('Phone authentication failed: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> storeSignupData({
    required bool isRecruiter,
    required Map<String, dynamic> data,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';

    try {
      dev.log("Writing to $collection/$uid", name: 'AuthService');

      // Normalize incoming data
      String mobileNumber = data['Mobile Number']?.toString().trim() ??
          data['mobileNumber']?.toString().trim() ??
          _auth.currentUser?.phoneNumber?.toString().trim() ??
          '';

      // Validate mobile number
      if (mobileNumber.isEmpty) {
        dev.log("Mobile number is missing for UID: $uid. Input data: $data, FirebaseAuth phoneNumber: ${_auth.currentUser?.phoneNumber}", name: 'AuthService');
        throw const AuthException("Mobile number is required");
      }

      // Basic mobile number format validation (e.g., starts with + and contains digits)
      final mobileNumberRegex = RegExp(r'^\+\d{10,15}$');
      if (!mobileNumberRegex.hasMatch(mobileNumber)) {
        dev.log("Invalid mobile number format for UID: $uid, mobileNumber: $mobileNumber", name: 'AuthService');
        throw const AuthException("Invalid mobile number format. Must start with '+' followed by 10-15 digits.");
      }

      final normalizedData = {
        'uid': uid,
        'email': data['Email Id']?.toString().trim() ?? data['email']?.toString().trim() ?? _auth.currentUser?.email?.toString().trim() ?? '',
        'mobileNumber': mobileNumber,
        'name': data['Name']?.toString().trim() ?? '',
        'role': isRecruiter ? 'recruiter' : 'seeker',
        ...data,
      };

      // Remove legacy or conflicting keys
      normalizedData.remove('UID');
      normalizedData.remove('Email Id');
      normalizedData.remove('Mobile Number');
      normalizedData.remove('Name');

      // For seekers: Validate specialization, skills, and education
      if (!isRecruiter) {
        // Normalize specialization
        final specialization = normalizedData['specialization'] as String?;
        if (specialization == null || !specializationOptions.contains(specialization)) {
          normalizedData['specialization'] = 'Others';
          dev.log("Invalid or missing specialization '$specialization', defaulting to 'Others'", name: 'AuthService');
        }

        // Normalize and validate skills
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
          dev.log("No valid skills provided for specialization '${normalizedData['specialization']}', skills set to empty list", name: 'AuthService');
        } else {
          dev.log("Validated skills: ${normalizedData['skills']}", name: 'AuthService');
        }

        // Ensure education is a string
        normalizedData['education'] = normalizedData['education']?.toString().trim() ?? '';
        if (normalizedData['education'].isEmpty) {
          dev.log("Missing or empty education for $uid, setting to empty string", name: 'AuthService');
        }
      } else {
        // For recruiters: Validate companyName
        normalizedData['companyName'] = normalizedData['companyName']?.toString().trim() ?? '';
        if (normalizedData['companyName'].isEmpty) {
          dev.log("Missing or empty companyName for $uid, setting to empty string", name: 'AuthService');
        }
      }

      dev.log("Final normalizedData: $normalizedData", name: 'AuthService');

      // Write to role-specific collection
      await _firestore.collection(collection).doc(uid).set(normalizedData, SetOptions(merge: true));
      dev.log("Write successful to $collection/$uid", name: 'AuthService');

      // Update index for global user lookup
      await _firestore.collection('UsersIndex').doc(uid).set({
        'email': normalizedData['email'],
        'mobileNumber': normalizedData['mobileNumber'],
        'name': normalizedData['name'],
        'role': normalizedData['role'],
      }, SetOptions(merge: true));
      dev.log("UsersIndex updated for $uid with mobileNumber: ${normalizedData['mobileNumber']}", name: 'AuthService');
    } catch (e) {
      dev.log("storeSignupData ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Firebase error: ${e.code} - ${e.message}. Check Firestore permissions or data format.");
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchProfileData({required bool isRecruiter}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final collection = isRecruiter ? 'Recruiters' : 'Seekers';
      final doc = await _firestore.collection(collection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        // For seekers: Ensure specialization is valid
        if (!isRecruiter) {
          final specialization = data['specialization'] as String?;
          if (specialization == null || !specializationOptions.contains(specialization)) {
            data['specialization'] = 'Others';
            dev.log("Invalid or missing specialization '$specialization' for $uid, defaulting to 'Others'", name: 'AuthService');
          }
          // Ensure skills is a list
          if (data['skills'] is String) {
            data['skills'] = (data['skills'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          final skills = data['skills'] as List<dynamic>? ?? [];
          final validSkills = skillsBySpecialization[data['specialization']] ?? skillsBySpecialization['Others']!;
          data['skills'] = skills
              .cast<String>()
              .where((skill) => validSkills.contains(skill))
              .toList();
          // Ensure education is a string
          data['education'] = data['education']?.toString().trim() ?? '';
          dev.log("Validated skills for $uid: ${data['skills']}, education: ${data['education']}", name: 'AuthService');
        }
        dev.log("Fetched profile data for $uid from $collection: $data", name: 'AuthService');
        return data;
      }
      dev.log("No profile found for $uid in $collection", name: 'AuthService');
      return null;
    } catch (e) {
      dev.log("fetchProfileData ERROR: $e", name: 'AuthService', error: e);
      return null;
    }
  }

  Future<String> uploadCompanyLogo(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final ref = _storage.ref("company_logos/$uid/logo.png");
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      dev.log("Company logo uploaded for $uid: $url", name: 'AuthService');
      return url;
    } catch (e) {
      dev.log("uploadCompanyLogo ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Upload failed: ${e.code} - ${e.message}. Check storage permissions or file format.");
      }
      rethrow;
    }
  }

  Future<String> uploadSeekerPhoto(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final ref = _storage.ref("seeker_photos/$uid/photo.png");
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      dev.log("Seeker photo uploaded for $uid: $url", name: 'AuthService');
      return url;
    } catch (e) {
      dev.log("uploadSeekerPhoto ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Upload failed: ${e.code} - ${e.message}. Check storage permissions or file format.");
      }
      rethrow;
    }
  }

  Future<void> postJob(Map<String, dynamic> jobData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      // Verify recruiter role
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (!recruiterDoc.exists) {
        dev.log('User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }

      final doc = _firestore.collection('Recruiters').doc(uid).collection('Jobs').doc();
      final normalizedJobData = Map<String, dynamic>.from(jobData)
        ..['jobId'] = doc.id
        ..['recruiterId'] = uid
        ..['status'] = 'open'
        ..['createdAt'] = FieldValue.serverTimestamp();
      if (normalizedJobData['skills'] is String) {
        normalizedJobData['skills'] = normalizedJobData['skills']
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      await doc.set(normalizedJobData);
      await _firestore.collection('Applications').doc(doc.id).set({
        'recruiterId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      dev.log("Job posted with ID ${doc.id} by $uid", name: 'AuthService');
    } catch (e) {
      dev.log("postJob ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Job posting failed: ${e.code} - ${e.message}. Check Firestore permissions or data format.");
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobsWithApplicationCounts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (!recruiterDoc.exists) {
        dev.log('User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }

      final jobsSnapshot = await _firestore
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (final job in jobsSnapshot.docs) {
        final jobId = job.id;
        final apps = await _firestore
            .collection('Applications')
            .doc(jobId)
            .collection('AppliedJobs')
            .get();

        result.add({
          ...job.data(),
          'jobId': jobId,
          'applicationCount': apps.size,
        });
      }

      dev.log("Fetched ${result.length} jobs for $uid", name: 'AuthService');
      return result;
    } catch (e) {
      dev.log("fetchJobsWithApplicationCounts ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Failed to fetch jobs: ${e.code} - ${e.message}. Check Firestore permissions or data.");
      }
      rethrow;
    }
  }

  Future<void> applyToJob(
    String jobId,
    String recruiterId,
    Map<String, dynamic> applicationData,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('No authenticated user', name: 'AuthService');
      throw const AuthException("User not logged in");
    }

    try {
      // Verify seeker role via UsersIndex
      final userDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (!userDoc.exists || userDoc.data()?['role'] != 'seeker') {
        dev.log('User $uid does not have seeker role, data: ${userDoc.data()}', name: 'AuthService');
        throw const AuthException('User does not have seeker role');
      }

      // Validate job and recruiter
      final jobSnapshot = await _firestore
          .collection('Recruiters')
          .doc(recruiterId)
          .collection('Jobs')
          .doc(jobId)
          .get();

      if (!jobSnapshot.exists) {
        dev.log('Job $jobId does not exist at Recruiters/$recruiterId/Jobs/$jobId', name: 'AuthService');
        throw const AuthException("Job not found");
      }
      final jobData = jobSnapshot.data()!;
      dev.log('Job $jobId data: $jobData', name: 'AuthService');
      final jobRecruiterId = jobData['recruiterId'] as String? ?? recruiterId;
      if (jobRecruiterId != recruiterId) {
        dev.log('Recruiter mismatch for job $jobId: expected $recruiterId, found $jobRecruiterId', name: 'AuthService');
        throw const AuthException("Recruiter mismatch");
      }
      if (jobData['status'] != 'open') {
        dev.log('Job $jobId is not open: status=${jobData['status']}', name: 'AuthService');
        throw const AuthException("Job is not open for applications");
      }

      // Check for duplicate application
      final indexDocId = '${uid}_$jobId';
      if ((await _firestore.collection('ApplicationsIndex').doc(indexDocId).get()).exists) {
        dev.log('Duplicate application detected for $indexDocId', name: 'AuthService');
        throw const AuthException('Already applied');
      }

      // Normalize application data
      final userIndex = await _firestore.collection('UsersIndex').doc(uid).get();
      final seekerName = userIndex.data()?['name']?.toString() ?? uid;

      final normalizedData = {
        ...applicationData,
        'seekerId': uid,
        'jobId': jobId,
        'recruiterId': recruiterId,
        'jobTitle': jobData['title'] ?? 'Untitled',
        'company': jobData['company'] ?? 'Unknown',
        'appliedAt': FieldValue.serverTimestamp(),
        'status': 'Applied'
      };

      // Batch all writes
      final batch = _firestore.batch();

      // Seeker-facing AppliedJobs
      final seekerAppRef = _firestore.collection('Applications').doc(uid).collection('AppliedJobs').doc(jobId);
      batch.set(seekerAppRef, normalizedData);
      dev.log('Writing seeker-facing application to Applications/$uid/AppliedJobs/$jobId', name: 'AuthService');

      // Recruiter-facing AppliedJobs
      final recruiterAppRef = _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(uid);
      batch.set(recruiterAppRef, {
        ...normalizedData,
        'seekerId': uid,
      });

      // ApplicationsIndex
      final indexRef = _firestore.collection('ApplicationsIndex').doc(indexDocId);
      batch.set(indexRef, {
        'seekerId': uid,
        'jobId': jobId,
        'recruiterId': recruiterId,
        'status': 'Applied',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Recruiter Notification
      final notifCollection = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications');
      final notificationId = notifCollection.doc().id;
      final notifRef = notifCollection.doc(notificationId);
      batch.set(notifRef, {
        'to': recruiterId,
        'from': uid,
        'message': 'New application for "${jobData['title']}" from $seekerName',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'application',
        'jobId': jobId,
        'read': false,
        'notificationId': notificationId,
      });

      // Commit batch
      await batch.commit();
      dev.log('Application submitted for job $jobId by $uid', name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log('applyToJob ERROR: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('Firebase error details: code=${e.code}, message=${e.message}, path=Applications/$jobId or Applications/$uid/AppliedJobs/$jobId or ApplicationsIndex/${uid}_$jobId or RecruiterNotifications/$recruiterId/Notifications', name: 'AuthService');
        throw AuthException('Application failed: ${e.code} - ${e.message}. Check Firestore rules or data.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('No authenticated user found', name: 'AuthService');
      throw const AuthException("User not logged in");
    }
    dev.log('Authenticated UID: $uid', name: 'AuthService');

    try {
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (!recruiterDoc.exists) {
        dev.log('User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }

      final appsSnapshot = await _firestore
          .collectionGroup('AppliedJobs')
          .where('recruiterId', isEqualTo: uid)
          .orderBy('appliedAt', descending: true)
          .get();
      dev.log('Found ${appsSnapshot.docs.length} applications in collectionGroup query for $uid', name: 'AuthService');

      final List<Map<String, dynamic>> seekers = [];
      final Set<String> processedApplications = {};

      for (final app in appsSnapshot.docs) {
        final data = app.data();
        final seekerId = app.id;
        final jobId = data['jobId'] as String? ?? '';
        final parentPath = app.reference.parent.parent!.path;
        final uniqueKey = '$jobId-$seekerId';

        // Skip seeker-facing data
        if (!parentPath.startsWith('Applications/$jobId')) {
          dev.log('Skipping seeker-facing application for job $jobId, seeker $seekerId at $parentPath', name: 'AuthService');
          continue;
        }

        if (jobId.isEmpty) {
          dev.log('Skipping application for seeker $seekerId: missing jobId', name: 'AuthService');
          continue;
        }

        if (processedApplications.contains(uniqueKey)) {
          dev.log('Skipping duplicate application for job $jobId, seeker $seekerId', name: 'AuthService');
          continue;
        }
        processedApplications.add(uniqueKey);
        dev.log('Processing application for job $jobId, seeker $seekerId at $parentPath', name: 'AuthService');

        final applicationParentDoc = await _firestore.collection('Applications').doc(jobId).get();
        if (!applicationParentDoc.exists) {
          dev.log('Creating missing /Applications/$jobId for recruiter $uid', name: 'AuthService');
          await _firestore.collection('Applications').doc(jobId).set({
            'recruiterId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        String jobTitle = data['jobTitle'] as String? ?? 'Untitled';
        final jobDoc = await _firestore.collection('Recruiters').doc(uid).collection('Jobs').doc(jobId).get();
        if (jobDoc.exists) {
          jobTitle = jobDoc.data()?['title'] as String? ?? jobTitle;
          dev.log('Job $jobId found in /Recruiters/$uid/Jobs, title: $jobTitle', name: 'AuthService');
        } else {
          dev.log('Job $jobId not found in /Recruiters/$uid/Jobs, using jobTitle from AppliedJobs: $jobTitle', name: 'AuthService');
        }

        final resume = data['resume'] as Map<String, dynamic>? ?? {};
        if (resume['name'] == null || resume['name'] == 'Unknown' || resume['email'] == null) {
          dev.log('Skipping application for seeker $seekerId: incomplete resume data', name: 'AuthService');
          continue;
        }

        final resumeUrl = resume['cvUrl']?.toString() ?? '';
        final resumeName = resume['name']?.toString() ?? 'Unnamed';
        final resumeVersion = resume['version']?.toString() ?? '';

        // Normalize specialization and skills
        final specialization = specializationOptions.contains(resume['specialization'] ?? data['specialization'])
            ? (resume['specialization'] ?? data['specialization'] ?? 'N/A')
            : 'N/A';
        final skillsList = (resume['skills'] as List<dynamic>?)?.cast<String>() ??
            (data['skills'] is String ? data['skills'].split(', ') : data['skills'] ?? []);
        final validSkills = skillsBySpecialization[specialization] ?? skillsBySpecialization['Others']!;
        final filteredSkills = skillsList.where((skill) => validSkills.contains(skill)).toList();

        seekers.add({
          'seekerId': seekerId,
          'jobId': jobId,
          'jobTitle': jobTitle,
          'appliedAt': data['appliedAt'],
          'resumeUrl': resumeUrl,
          'resumeName': resumeName,
          'resumeVersion': resumeVersion,
          'coverLetter': data['coverLetter']?.toString() ?? '',
          'status': data['status']?.toString() ?? 'Applied',
          'name': resume['name']?.toString().trim() ?? seekerId,
          'resume': resume,
          'specialization': specialization,
          'education': resume['education']?.toString().trim() ?? data['education']?.toString().trim() ?? 'N/A',
          'experience': resume['experience']?.toString() ?? data['experience']?.toString() ?? 'N/A',
          'email': resume['email']?.toString() ?? 'N/A',
          'skills': filteredSkills,
        });
        dev.log('Added seeker $seekerId for job $jobId to result', name: 'AuthService');
      }

      dev.log('Returning ${seekers.length} seekers for $uid', name: 'AuthService');
      return seekers;
    } catch (e, stackTrace) {
      dev.log('fetchAppliedSeekers ERROR for $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          throw AuthException(
              'Permission denied: ${e.message}. Ensure /Applications/{jobId}/AppliedJobs/{seekerId} has recruiterId=$uid and Firestore rules allow access.');
        } else if (e.code == 'failed-precondition') {
          throw AuthException(
              'Failed to fetch seekers: ${e.message}. Create index at: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes');
        }
        throw AuthException('Failed to fetch seekers: ${e.code} - ${e.message}.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekersAsync() async {
    return await compute((_) => fetchAppliedSeekers(), null);
  }

  Future<void> sendMessage(String recipientId, String jobId, String message) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final chatId = [uid, recipientId].join('_').split('_')..sort();
      final normalizedChatId = '${chatId[0]}_${chatId[1]}';
      dev.log('Initiating chat with ID $normalizedChatId for job $jobId', name: 'AuthService');

      // Create parent Messages document
      await _firestore.collection('Messages').doc(normalizedChatId).set({
        'senderId': uid,
        'recipientId': recipientId,
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add message
      final messageRef = _firestore.collection('Messages').doc(normalizedChatId).collection('Messages').doc();
      await messageRef.set({
        'senderId': uid,
        'recipientId': recipientId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'jobId': jobId,
      });
      dev.log('Message sent to $normalizedChatId for job $jobId', name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log('sendMessage ERROR for $uid to $recipientId: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException("Failed to send message: ${e.code} - ${e.message}. Check Firestore rules for Messages/$recipientId.");
      }
      rethrow;
    }
  }

  Future<void> handleAction({
    required String action,
    required String jobId,
    required String seekerId,
    Map<String, dynamic>? additionalData,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('No authenticated user found', name: 'AuthService');
      throw const AuthException("User not logged in");
    }

    try {
      // Verify recruiter role
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (!recruiterDoc.exists) {
        dev.log('User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }
      dev.log('Recruiter role verified for $uid', name: 'AuthService');

      // Validate job
      final jobRef = _firestore.collection('Recruiters').doc(uid).collection('Jobs').doc(jobId);
      final jobDoc = await jobRef.get();
      if (!jobDoc.exists || jobDoc.data()?['recruiterId'] != uid) {
        dev.log('Job $jobId not found or does not belong to recruiter $uid: ${jobDoc.data()}', name: 'AuthService');
        throw const AuthException('Unauthorized job access');
      }
      dev.log('Job data: ${jobDoc.data()}', name: 'AuthService');
      final jobData = jobDoc.data()!;
      final jobTitle = jobData['title'] as String? ?? 'Untitled';

      // Validate application
      final applicationRef = _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId);
      final applicationDoc = await applicationRef.get();
      if (!applicationDoc.exists) {
        dev.log('Application not found for job $jobId, seeker $seekerId: ${applicationDoc.data()}', name: 'AuthService');
        throw const AuthException('Application not found');
      }
      if (applicationDoc.data()!['recruiterId'] != uid) {
        dev.log('Recruiter $uid does not match application recruiterId ${applicationDoc.data()!['recruiterId']}', name: 'AuthService');
        throw const AuthException('Invalid application recruiter');
      }

      // Check if seeker-facing application exists, create if missing
      final seekerAppRef = _firestore.collection('Applications').doc(seekerId).collection('AppliedJobs').doc(jobId);
      final seekerAppDoc = await seekerAppRef.get();
      if (!seekerAppDoc.exists) {
        dev.log('Seeker-facing application not found for job $jobId, seeker $seekerId, creating it', name: 'AuthService');
        await seekerAppRef.set({
          'seekerId': seekerId,
          'jobId': jobId,
          'recruiterId': uid,
          'jobTitle': jobTitle,
          'company': jobData['company'] ?? 'Unknown',
          'status': 'Applied',
          'appliedAt': FieldValue.serverTimestamp(),
          'resume': applicationDoc.data()?['resume'] ?? {},
        });
        dev.log('Created seeker-facing application for job $jobId, seeker $seekerId', name: 'AuthService');
      }

      final batch = _firestore.batch();
      final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
      final notifRef = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc(notificationId);

      switch (action.toLowerCase()) {
        case 'shortlist':
          dev.log('Shortlisting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.set(_firestore.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId), {
            'seekerId': seekerId,
            'jobId': jobId,
            'recruiterId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          batch.update(applicationRef, {'status': 'Shortlisted', 'interviewDate': null});
          batch.update(seekerAppRef, {'status': 'Shortlisted', 'interviewDate': null});
          batch.set(notifRef, {
            'to': seekerId,
            'from': uid,
            'message': 'You have been shortlisted for "$jobTitle"!',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'status_update',
            'jobId': jobId,
            'jobTitle': jobTitle,
            'notificationId': notificationId,
          });
          break;

        case 'reject':
          dev.log('Rejecting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.update(applicationRef, {'status': 'Rejected', 'interviewDate': null});
          batch.update(seekerAppRef, {'status': 'Rejected', 'interviewDate': null});
          batch.set(notifRef, {
            'to': seekerId,
            'from': uid,
            'message': 'Your application for "$jobTitle" has been rejected.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'status_update',
            'jobId': jobId,
            'jobTitle': jobTitle,
            'notificationId': notificationId,
          });
          break;

        case 'schedule':
          dev.log('Scheduling interview for seeker $seekerId, job $jobId', name: 'AuthService');
          final interviewDate = additionalData?['interviewDate'] as Timestamp?;
          if (interviewDate == null) {
            dev.log('Missing interviewDate for schedule action', name: 'AuthService');
            throw const AuthException('Interview date is required for scheduling');
          }
          batch.update(applicationRef, {
            'status': 'Interview Scheduled',
            'interviewDate': interviewDate,
          });
          batch.update(seekerAppRef, {
            'status': 'Interview Scheduled',
            'interviewDate': interviewDate,
          });
          batch.set(notifRef, {
            'to': seekerId,
            'from': uid,
            'message': 'Interview for "$jobTitle" scheduled on ${DateFormat('dd MMM yyyy').format(interviewDate.toDate())}',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'interview_scheduled',
            'jobId': jobId,
            'jobTitle': jobTitle,
            'notificationId': notificationId,
          });
          break;

        case 'chat':
          dev.log('Initiating chat with seeker $seekerId for job $jobId', name: 'AuthService');
          final chatId = [uid, seekerId].join('_').split('_')..sort();
          final normalizedChatId = '${chatId[0]}_${chatId[1]}';
          batch.set(_firestore.collection('Messages').doc(normalizedChatId), {
            'senderId': uid,
            'recipientId': seekerId,
            'jobId': jobId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          batch.set(_firestore.collection('Messages').doc(normalizedChatId).collection('Messages').doc(), {
            'senderId': uid,
            'recipientId': seekerId,
            'message': 'Hello, let’s discuss your application for "$jobTitle"!',
            'timestamp': FieldValue.serverTimestamp(),
            'jobId': jobId,
          });
          batch.set(notifRef, {
            'to': seekerId,
            'from': uid,
            'message': 'New message regarding "$jobTitle" from recruiter',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'status_update',
            'jobId': jobId,
            'jobTitle': jobTitle,
            'notificationId': notificationId,
          });
          break;

        default:
          dev.log('Invalid action: $action', name: 'AuthService');
          throw const AuthException('Invalid action');
      }

      await batch.commit();
      dev.log('Action $action completed for seeker $seekerId, job $jobId', name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log('handleAction ERROR for action $action, job $jobId, seeker $seekerId: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('Firebase error details: code=${e.code}, message=${e.message}, path=Applications/$jobId/AppliedJobs/$seekerId or Shortlisted/$jobId/Seekers/$seekerId or Messages', name: 'AuthService');
        throw AuthException('Action failed: ${e.code} - ${e.message}. Check Firestore rules for Applications/$jobId/AppliedJobs/$seekerId or Shortlisted/$jobId/Seekers/$seekerId or Messages.');
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
        dev.log('User $uid is not a recruiter', name: 'AuthService');
        throw const AuthException('User is not a recruiter');
      }

      final callsSnapshot = await _firestore
          .collectionGroup('AppliedJobs')
          .where('recruiterId', isEqualTo: uid)
          .where('status', isEqualTo: 'Interview Scheduled')
          .orderBy('interviewDate', descending: false)
          .get();
      dev.log('Fetched ${callsSnapshot.docs.length} scheduled calls for $uid', name: 'AuthService');

      final List<Map<String, dynamic>> calls = [];
      for (final call in callsSnapshot.docs) {
        final data = call.data();
        final seekerId = call.id;
        final parentPath = call.reference.parent.parent!.path;
        if (!parentPath.startsWith('Applications/${data['jobId']}')) {
          dev.log('Skipping seeker-facing scheduled call for job ${data['jobId']}, seeker $seekerId at $parentPath', name: 'AuthService');
          continue;
        }

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
      dev.log('Returning ${calls.length} scheduled calls for $uid', name: 'AuthService');
      return calls;
    } catch (e, stackTrace) {
      dev.log('fetchScheduledCalls ERROR: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException("Failed to fetch scheduled calls: ${e.code} - ${e.message}. Check Firestore permissions.");
      }
      rethrow;
    }
  }

  Future<bool> isSignedIn() async => _auth.currentUser != null;

  User? getCurrentUser() => _auth.currentUser;

  Future<void> signOut() async => await _auth.signOut();

  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String?;
        dev.log("Role found for $uid: $role", name: 'AuthService');
        return role;
      }
      dev.log("No role found for $uid in UsersIndex", name: 'AuthService');
      return null;
    } catch (e) {
      dev.log("getUserRole ERROR: $e", name: 'AuthService', error: e);
      return null;
    }
  }
}
