// ignore_for_file: unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'dart:io';

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
    'Vocational/Domestic Services',
    'Others',
  ];

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
    'Vocational/Domestic Services': [
      'Driving', 'Housekeeping', 'Cooking', 'Childcare', 'Elderly Care', 'Gardening',
      'Basic Maintenance', 'Customer Service', 'Inventory Management', 'Event Assistance',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation', 'Driving', 'Housekeeping', 'Cooking', 'Childcare', 'Gardening',
      'Basic Maintenance',
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
      dev.log("Writing to $collection/$uid", name: 'AuthService');

      String mobileNumber = data['Mobile Number']?.toString().trim() ??
          data['mobileNumber']?.toString().trim() ??
          _auth.currentUser?.phoneNumber?.toString().trim() ??
          '';

      if (mobileNumber.isEmpty) {
        dev.log("Mobile number is missing for UID: $uid. Input data: $data, FirebaseAuth phoneNumber: ${_auth.currentUser?.phoneNumber}", name: 'AuthService');
        throw const AuthException("Mobile number is required");
      }

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

      normalizedData.remove('UID');
      normalizedData.remove('Email Id');
      normalizedData.remove('Mobile Number');
      normalizedData.remove('Name');

      if (!isRecruiter) {
        final specialization = normalizedData['specialization'] as String?;
        if (specialization == null || !specializationOptions.contains(specialization)) {
          normalizedData['specialization'] = 'Others';
          dev.log("Invalid or missing specialization '$specialization', defaulting to 'Others'", name: 'AuthService');
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
          dev.log("No valid skills provided for UID: $uid, specialization: ${normalizedData['specialization']}", name: 'AuthService');
        }

        if (normalizedData['education'] == null || normalizedData['education'] is! String) {
          normalizedData['education'] = '';
          dev.log("Invalid or missing education for UID: $uid, defaulting to empty", name: 'AuthService');
        }
      }

      if (isRecruiter && normalizedData['companyName'] == null) {
        dev.log("Missing company field for recruiter UID: $uid", name: 'AuthService');
        throw const AuthException("Company name is required for recruiters");
      }

      await _firestore.collection(collection).doc(uid).set(normalizedData, SetOptions(merge: true));

      await _firestore.collection('UsersIndex').doc(uid).set({
        'uid': uid,
        'role': isRecruiter ? 'recruiter' : 'seeker',
        'mobileNumber': mobileNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      dev.log("Successfully stored signup data for $collection/$uid", name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log("storeSignupData ERROR for UID: $uid, isRecruiter: $isRecruiter: $e", name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to store signup data: ${e.code} - ${e.message}. Check Firestore permissions for $collection/$uid.');
      }
      rethrow;
    }
  }

  Future<String> uploadCompanyLogo(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      dev.log('Uploading company logo for recruiter $uid', name: 'AuthService');
      final ref = _storage.ref().child('recruiters/$uid/logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await _firestore.collection('Recruiters').doc(uid).set(
        {'companyLogo': downloadUrl},
        SetOptions(merge: true),
      );

      dev.log('Company logo uploaded and saved for recruiter $uid: $downloadUrl', name: 'AuthService');
      return downloadUrl;
    } catch (e, stackTrace) {
      dev.log('uploadCompanyLogo ERROR for UID: $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to upload company logo: ${e.code} - ${e.message}');
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

  Future<String> uploadSeekerResume(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      dev.log('Uploading resume for seeker $uid', name: 'AuthService');
      final ref = _storage.ref().child('seekers/$uid/resume_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await _firestore.collection('Seekers').doc(uid).set(
        {'resumeUrl': downloadUrl},
        SetOptions(merge: true),
      );

      dev.log('Resume uploaded and saved for seeker $uid: $downloadUrl', name: 'AuthService');
      return downloadUrl;
    } catch (e, stackTrace) {
      dev.log('uploadSeekerResume ERROR for UID: $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException('Failed to upload resume: ${e.code} - ${e.message}');
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
        dev.log("Fetched profile data for $collection/$uid", name: 'AuthService');
        return doc.data();
      }
      dev.log("No profile found for $collection/$uid", name: 'AuthService');
      return null;
    } catch (e, stackTrace) {
      dev.log("fetchProfileData ERROR for $collection/$uid: $e", name: 'AuthService', error: e, stackTrace: stackTrace);
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
        : (seekerProfile['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
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
    dev.log('[2025-08-13 23:25 IST] Applied to job $jobId by seeker $uid', name: 'AuthService');
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
        'notificationId': notificationId,
        'type': 'application',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Interview scheduled for ${appData['jobTitle']} on ${DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate)}',
      },
    );

    await batch.commit();
    dev.log('[2025-08-09 01:05 IST] Scheduled interview for job $jobId, seeker $seekerId by recruiter $uid', name: 'AuthService');
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[2025-08-09 00:33 IST] No authenticated user in fetchAppliedSeekers', name: 'AuthService');
      throw const AuthException('User not logged in');
    }

    try {
      final snapshot = await _firestore
          .collection('Applications')
          .where('recruiterId', isEqualTo: uid)
          .get();
      dev.log('[2025-08-09 00:33 IST] Fetched ${snapshot.docs.length} applicants for recruiter piqued', name: 'AuthService');
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      dev.log('[2025-08-09 00:33 IST] Error fetching applied seekers for $uid: $e', name: 'AuthService', error: e);
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
    dev.log('[2025-08-09 01:15 IST] Generated chatId $chatId for seeker $seekerId, job $jobId', name: 'AuthService');
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

    try {
      final applicationId = '${seekerId}_$jobId';
      final applicationRef = _firestore.collection('Applications').doc(applicationId);
      final appDoc = await applicationRef.get();
      if (!appDoc.exists) {
        dev.log('Application $applicationId not found', name: 'AuthService');
        throw const AuthException('Application not found');
      }
      final jobTitle = appDoc.data()!['jobTitle']?.toString() ?? 'Untitled';
      dev.log('Processing action $action for application $applicationId', name: 'AuthService');

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
          batch.update(applicationRef, {'status': 'Shortlisted', 'interviewDate': null, 'updatedAt': FieldValue.serverTimestamp()});
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
          batch.update(applicationRef, {'status': 'Rejected', 'interviewDate': null, 'updatedAt': FieldValue.serverTimestamp()});
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
            dev.log('Missing interviewDate for schedule action for application $applicationId', name: 'AuthService');
            throw const AuthException('Interview date is required for scheduling');
          }
          batch.update(applicationRef, {
            'status': 'Interview Scheduled',
            'interviewDate': interviewDate,
            'updatedAt': FieldValue.serverTimestamp(),
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

        default:
          dev.log('Invalid action: $action for application $applicationId', name: 'AuthService');
          throw const AuthException('Invalid action');
      }

      await batch.commit();
      dev.log('Action $action completed for application $applicationId', name: 'AuthService');
    } catch (e, stackTrace) {
      dev.log('handleAction ERROR for action $action, job $jobId, seeker $seekerId: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        final applicationId = '${seekerId}_$jobId';
        dev.log('Firebase error details: code=${e.code}, message=${e.message}, path=Applications/$applicationId or Shortlisted/$jobId/Seekers/$seekerId or Messages', name: 'AuthService');
        throw AuthException('Action failed: ${e.code} - ${e.message}. Check Firestore rules for Applications/$applicationId or Shortlisted/$jobId/Seekers/$seekerId or Messages.');
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

 Future<void> sendMessage(String recipientId, String jobId, String message, {String status = 'sent'}) async {
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
          dev.log('[2025-08-28 15:31 IST] Application ${recipientId}_$jobId not found', name: 'AuthService');
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
        dev.log('[2025-08-28 15:31 IST] Application $applicationId not found', name: 'AuthService');
        throw Exception('Application does not exist');
      }
      final appData = appDoc.data()!;
      if (appData['jobId'] != jobId || appData['seekerId'] != seekerId || appData['recruiterId'] is! String) {
        dev.log('[2025-08-28 15:31 IST] Invalid application data for $applicationId: $appData', name: 'AuthService');
        throw Exception('Invalid application data');
      }

      final participants = [senderId, recipientId];
      participants.sort();
      final chatId = '${participants[0]}_${participants[1]}';
      final messageDocRef = _firestore
          .collection('Messages')
          .doc(chatId)
          .collection('Chats')
          .doc(); // Generate doc ID for message
      await messageDocRef.set({
        'senderId': senderId,
        'recipientId': recipientId,
        'jobId': jobId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': status,
      });
      dev.log('[2025-08-28 15:31 IST] Message sent from $senderId to $recipientId for job $jobId with chatId $chatId, status: $status', name: 'AuthService');
    } catch (e) {
      dev.log('[2025-08-28 15:31 IST] Error sending message from $senderId to $recipientId for job $jobId: $e', name: 'AuthService', error: e);
      throw AuthException('Failed to send message: $e');
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