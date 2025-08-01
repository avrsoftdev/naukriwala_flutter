
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as dev;
import 'dart:io';
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

  Future<void> storeSignupData({
    required bool isRecruiter,
    required Map<String, dynamic> data,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';

    try {
      dev.log("Writing to $collection/$uid", name: 'AuthService');

      // 🔄 Normalize incoming data
      final normalizedData = {
        'uid': uid,
        'email': data['Email Id'] ?? data['email'] ?? _auth.currentUser?.email ?? '',
        'mobileNumber': data['Mobile Number'] ?? data['mobileNumber'] ?? '',
        'role': isRecruiter ? 'recruiter' : 'seeker',
        ...data,
      };

      // 🧼 Remove legacy or conflicting keys
      normalizedData.remove('UID');
      normalizedData.remove('Email Id');
      normalizedData.remove('Mobile Number');

      // 🧠 Parse skills if string
      if (!isRecruiter && normalizedData['skills'] is String) {
        normalizedData['skills'] = (normalizedData['skills'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      dev.log("Final normalizedData: $normalizedData", name: 'AuthService');

      // 📝 Write to role-specific collection
      await _firestore.collection(collection).doc(uid).set(normalizedData, SetOptions(merge: true));
      dev.log("Write successful to $collection/$uid", name: 'AuthService');

      // 📁 Update index for global user lookup
      await _firestore.collection('UsersIndex').doc(uid).set({
        'email': normalizedData['email'],
        'mobileNumber': normalizedData['mobileNumber'],
        'role': normalizedData['role'],
      }, SetOptions(merge: true));
      dev.log("UsersIndex updated for $uid", name: 'AuthService');
    } catch (e) {
      dev.log("storeSignupData ERROR: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw const AuthException("Firebase error: Check Firestore permissions or data format");
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
        throw const AuthException("Upload failed: Check storage permissions or file format");
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
        throw const AuthException("Upload failed: Check storage permissions or file format");
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
        throw const AuthException("Job posting failed: Check Firestore permissions or data format");
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
        throw const AuthException("Failed to fetch jobs: Check Firestore permissions or data");
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
      // 🔒 Verify seeker role early
      final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
      if (!seekerDoc.exists || seekerDoc.data()?['role'] != 'seeker') {
        dev.log('User $uid does not have seeker role, data: ${seekerDoc.data()}', name: 'AuthService');
        throw const AuthException('User does not have seeker role');
      }

      // 📄 Validate job and recruiter
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

      // 🔍 Check for duplicate application
      final indexDocId = '${uid}_$jobId';
      if ((await _firestore.collection('ApplicationsIndex').doc(indexDocId).get()).exists) {
        dev.log('Duplicate application detected for $indexDocId', name: 'AuthService');
        throw const AuthException('Already applied');
      }

      // 🧪 Normalize application data
      final seekerProfile = await fetchProfileData(isRecruiter: false);
      final seekerName = seekerProfile?['name'] as String? ?? uid;

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

      // ✅ Seeker-facing AppliedJobs
      dev.log('Writing seeker-facing application to Applications/$uid/AppliedJobs/$jobId', name: 'AuthService');
      await _firestore
          .collection('Applications')
          .doc(uid)
          .collection('AppliedJobs')
          .doc(jobId)
          .set(normalizedData)
          .catchError((e) {
        dev.log('Error writing Applications/$uid/AppliedJobs/$jobId: $e', name: 'AuthService', error: e);
        throw AuthException('Failed to write seeker-facing application: $e');
      });

      // 📦 Batch recruiter-facing AppliedJobs + Index + Notification
      final batch = _firestore.batch();

      // 💬 Recruiter-facing AppliedJobs with seekerId as document ID
      final recruiterAppsCollection = _firestore.collection('Applications').doc(jobId).collection('AppliedJobs');
      final recruiterAppRef = recruiterAppsCollection.doc(uid);
      batch.set(recruiterAppRef, {
        ...normalizedData,
        'seekerId': uid,
      });

      // 📁 ApplicationsIndex
      final indexRef = _firestore.collection('ApplicationsIndex').doc(indexDocId);
      batch.set(indexRef, {
        'seekerId': uid,
        'jobId': jobId,
        'company' : jobData['company'],
        'recruiterId': recruiterId,
        'status': 'Applied',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔔 Recruiter Notification
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

      // 📝 Commit batch
      await batch.commit().catchError((e) {
        dev.log('Batch commit failed for job $jobId, seeker $uid: $e', name: 'AuthService', error: e);
        throw AuthException('Batch commit failed: $e');
      });
      dev.log('Application submitted for job $jobId by $uid', name: 'AuthService');
    } catch (e) {
      dev.log('applyToJob ERROR: $e', name: 'AuthService', error: e);
      if (e is FirebaseException) {
        dev.log('Firebase error details: code=${e.code}, message=${e.message}, path=Applications/$jobId or Applications/$uid/AppliedJobs/$jobId or ApplicationsIndex/${uid}_$jobId or RecruiterNotifications/$recruiterId/Notifications', name: 'AuthService');
        throw AuthException('Application failed: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
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
          .get();
      dev.log('Fetched ${jobsSnapshot.docs.length} jobs for $uid', name: 'AuthService');

      final List<Map<String, dynamic>> seekers = [];
      final Map<String, Map<String, dynamic>> seekerProfileCache = {};

      for (final job in jobsSnapshot.docs) {
        final jobId = job.id;
        final jobTitle = job.data()['title'] as String? ?? 'Untitled';
        dev.log('Fetching applicants for job $jobId (title: $jobTitle)', name: 'AuthService');

        final appDoc = await _firestore.collection('Applications').doc(jobId).get();
        if (!appDoc.exists || appDoc.data()?['recruiterId'] != uid) {
          dev.log('Skipping Applications/$jobId due to missing or mismatched recruiterId', name: 'AuthService');
          continue;
        }

        final appsSnapshot = await _firestore
            .collection('Applications')
            .doc(jobId)
            .collection('AppliedJobs')
            .orderBy('appliedAt', descending: true)
            .get();
        dev.log('Found ${appsSnapshot.docs.length} applications for job $jobId', name: 'AuthService');

        for (final app in appsSnapshot.docs) {
          final data = app.data();
          final seekerId = data['seekerId'] as String? ?? app.id;

          String name;
          if (!seekerProfileCache.containsKey(seekerId)) {
            try {
              final seekerDoc = await _firestore.collection('Seekers').doc(seekerId).get();
              if (seekerDoc.exists) {
                seekerProfileCache[seekerId] = seekerDoc.data() ?? {};
              } else {
                dev.log('Seeker/$seekerId profile missing', name: 'AuthService');
                seekerProfileCache[seekerId] = {};
              }
            } catch (e) {
              dev.log('Error reading Seeker/$seekerId: $e', name: 'AuthService', error: e);
              seekerProfileCache[seekerId] = {};
            }
          }

          name = seekerProfileCache[seekerId]?['name']?.toString().trim() ?? seekerId;

          final resume = data['resume'] as Map<String, dynamic>? ?? {};
          final resumeUrl = resume['url'] ?? '';
          final resumeName = resume['name'] ?? 'Unnamed';
          final resumeVersion = resume['version'] ?? '';

          seekers.add({
            'seekerId': seekerId,
            'jobId': jobId,
            'jobTitle': data['jobTitle'] as String? ?? jobTitle,
            'appliedAt': data['appliedAt'],
            'resumeUrl': resumeUrl,
            'resumeName': resumeName,
            'resumeVersion': resumeVersion,
            'coverLetter': data['coverLetter'] as String? ?? '',
            'status': data['status'] as String? ?? 'Applied',
            'name': name,
          });
        }
      }

      dev.log('Returning ${seekers.length} seekers for $uid', name: 'AuthService');
      return seekers;
    } catch (e, stackTrace) {
      dev.log('fetchAppliedSeekers ERROR for $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        throw AuthException("Failed to fetch seekers: ${e.code} - ${e.message}");
      }
      rethrow;
    }
  }

  Future<void> sendMessage(String recipientId, String jobId, String message) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final chatId = [uid, recipientId].join('_').split('_')..sort();
      final normalizedChatId = '${chatId[0]}_${chatId[1]}';
      final messageRef = _firestore.collection('Messages').doc(normalizedChatId).collection('Messages').doc();
      await messageRef.set({
        'senderId': uid,
        'recipientId': recipientId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'jobId': jobId,
      });
      dev.log('Message sent to $normalizedChatId for job $jobId', name: 'AuthService');
    } catch (e) {
      dev.log('sendMessage ERROR: $e', name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw const AuthException("Failed to send message: Check permissions");
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
    if (uid == null) throw const AuthException("User not logged in");

    try {
      await AuthMiddleware.requireRole('recruiter');
      dev.log('Recruiter role verified for $uid', name: 'AuthService');

      final jobDoc = await _firestore.collection('Recruiters').doc(uid).collection('Jobs').doc(jobId).get();
      if (!jobDoc.exists || jobDoc.data()?['recruiterId'] != uid) {
        dev.log('Job $jobId not found or does not belong to recruiter $uid', name: 'AuthService');
        throw const AuthException('Unauthorized job access');
      }

      final applicationDoc = await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).get();
      if (!applicationDoc.exists) {
        dev.log('Application not found for job $jobId, seeker $seekerId', name: 'AuthService');
        throw const AuthException('Application not found');
      }

      final jobTitle = jobDoc.data()?['title'] as String? ?? 'Untitled';
      final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;

      final batch = _firestore.batch();
      final applicationRef = _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId);

      switch (action.toLowerCase()) {
        case 'shortlist':
          dev.log('Shortlisting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.set(_firestore.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId), {
            'timestamp': FieldValue.serverTimestamp(),
          });
          batch.update(applicationRef, {'status': 'Shortlisted'});
          await _sendNotification(seekerId, 'You have been shortlisted for "$jobTitle"!', jobId, jobTitle, notificationId);
          dev.log('Seeker $seekerId shortlisted for job $jobId', name: 'AuthService');
          break;

        case 'reject':
          dev.log('Rejecting seeker $seekerId for job $jobId', name: 'AuthService');
          batch.update(applicationRef, {'status': 'Rejected'});
          await _sendNotification(seekerId, 'Your application for "$jobTitle" has been rejected.', jobId, jobTitle, notificationId);
          dev.log('Seeker $seekerId rejected for job $jobId', name: 'AuthService');
          break;

        case 'schedule':
          dev.log('Scheduling interview for seeker $seekerId, job $jobId', name: 'AuthService');
          final interviewDate = additionalData?['interviewDate'] as Timestamp?;
          if (interviewDate == null) {
            throw const AuthException('Interview date is required for scheduling');
          }
          batch.update(applicationRef, {
            'status': 'Interview Scheduled',
            'interviewDate': interviewDate,
          });
          await _sendNotification(seekerId, 'Interview for "$jobTitle" scheduled on ${interviewDate.toDate()}', jobId, jobTitle, notificationId);
          dev.log('Interview scheduled for seeker $seekerId, job $jobId', name: 'AuthService');
          break;

        case 'chat':
          dev.log('Initiating chat with seeker $seekerId for job $jobId', name: 'AuthService');
          await sendMessage(seekerId, jobId, 'Hello, let’s discuss your application for "$jobTitle"!');
          dev.log('Chat initiated with seeker $seekerId for job $jobId', name: 'AuthService');
          break;

        default:
          throw const AuthException('Invalid action');
      }

      await batch.commit();
      dev.log('Action $action completed for seeker $seekerId, job $jobId', name: 'AuthService');
    } catch (e) {
      dev.log('handleAction ERROR for action $action, job $jobId, seeker $seekerId: $e', name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Action failed: ${e.code} - ${e.message}");
      }
      rethrow;
    }
  }

  Future<void> _sendNotification(String seekerId, String message, String jobId, String jobTitle, String notificationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final notifRef = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc(notificationId);

      await notifRef.set({
        'to': seekerId,
        'from': uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'application',
        'jobId': jobId,
        'jobTitle': jobTitle,
      });
      dev.log('Notification $notificationId sent to $seekerId for job $jobId: $message', name: 'AuthService');

      final tokenSnapshot = await _firestore.collection('UsersIndex').doc(seekerId).get();
      final token = tokenSnapshot.data()?['fcmToken'] as String?;
      if (token != null) {
        dev.log('FCM token found for $seekerId: $token', name: 'AuthService');
        // Add FCM logic here if implemented
      } else {
        dev.log('No FCM token found for $seekerId, notification stored in Firestore only', name: 'AuthService');
      }
    } catch (e) {
      dev.log('Error sending notification to $seekerId for job $jobId: $e', name: 'AuthService', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied writing to SeekerNotifications/$seekerId/Notifications/$notificationId. Check Firestore rules.', name: 'AuthService');
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
        String? name;
        try {
          final seekerProfile = await _firestore.collection('Seekers').doc(seekerId).get();
          name = seekerProfile.exists ? (seekerProfile.data()?['name'] ?? seekerId) : seekerId;
        } catch (e) {
          dev.log('Failed to read Seeker/$seekerId for scheduled call: $e', name: 'AuthService', error: e);
          if (e is FirebaseException && e.code == 'permission-denied') {
            dev.log('Permission denied for Seeker/$seekerId in fetchScheduledCalls', name: 'AuthService');
          }
          name = seekerId;
        }

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
    } catch (e) {
      dev.log('fetchScheduledCalls ERROR: $e', name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw const AuthException("Failed to fetch scheduled calls: Check Firestore permissions");
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
      final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
      if (seekerDoc.exists) {
        dev.log("Role found for $uid: seeker", name: 'AuthService');
        return 'seeker';
      }
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (recruiterDoc.exists) {
        dev.log("Role found for $uid: recruiter", name: 'AuthService');
        return 'recruiter';
      }
      dev.log("No role found for $uid", name: 'AuthService');
      return null;
    } catch (e) {
      dev.log("getUserRole ERROR: $e", name: 'AuthService', error: e);
      return null;
    }
  }
}