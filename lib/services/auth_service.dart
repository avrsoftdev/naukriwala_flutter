import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'auth_middleware.dart';
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
      final normalizedData = Map<String, dynamic>.from(data)
        ..remove('UID')
        ..['mobileNumber'] = data['Mobile Number'] ?? data['mobileNumber'] ?? ''
        ..['email'] = data['Email Id'] ?? data['email'] ?? _auth.currentUser?.email ?? '';
      if (!isRecruiter && normalizedData['skills'] is String) {
        normalizedData['skills'] = normalizedData['skills']
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      await _firestore.collection(collection).doc(uid).set(normalizedData, SetOptions(merge: true));

      dev.log("Write successful to $collection/$uid", name: 'AuthService');
      await _firestore.collection('UsersIndex').doc(uid).set({
        'email': normalizedData['email'],
        'mobileNumber': normalizedData['mobileNumber'],
        'role': isRecruiter ? 'recruiter' : 'seeker',
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
  if (uid == null) throw const AuthException("User not logged in");

  try {
    // Verify seeker role
    final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
    if (!seekerDoc.exists) {
      dev.log('User $uid is not a seeker', name: 'AuthService');
      throw const AuthException('User is not a seeker');
    }
    dev.log('Seeker role verified for $uid', name: 'AuthService');

    // Fetch job data
    dev.log('Checking job existence: Recruiters/$recruiterId/Jobs/$jobId', name: 'AuthService');
    final jobSnapshot = await _firestore
        .collection('Recruiters')
        .doc(recruiterId)
        .collection('Jobs')
        .doc(jobId)
        .get();
    if (!jobSnapshot.exists) {
      dev.log('Job $jobId does not exist', name: 'AuthService');
      throw const AuthException("Job not found");
    }
    final jobData = jobSnapshot.data()!;
    final jobTitle = jobData['title'] as String? ?? 'Untitled';
    final company = jobData['company'] as String? ?? 'Unknown';
    dev.log('Job $jobId found: title=$jobTitle, status=${jobData['status']}, company=$company', name: 'AuthService');

    // Fetch recruiter profile for company name
    final recruiterDoc = await _firestore.collection('Recruiters').doc(recruiterId).get();
    if (!recruiterDoc.exists) {
      dev.log('Recruiter $recruiterId does not exist', name: 'AuthService');
      throw const AuthException("Recruiter not found");
    }
    final companyName = recruiterDoc.data()?['company'] as String? ?? 'Unknown';
    dev.log('Recruiter $recruiterId found: company=$companyName', name: 'AuthService');

    // Check for existing application to prevent duplicates
    final indexDocId = '${uid}_${jobId}';
    final indexDoc = await _firestore.collection('ApplicationsIndex').doc(indexDocId).get();
    if (indexDoc.exists) {
      dev.log('Application already exists for seeker $uid and job $jobId', name: 'AuthService');
      throw const AuthException('You have already applied to this job');
    }

    // Normalize application data
    final normalizedApplicationData = Map<String, dynamic>.from(applicationData)
      ..['seekerId'] = uid
      ..['jobId'] = jobId
      ..['recruiterId'] = recruiterId
      ..['jobTitle'] = jobTitle
      ..['company'] = companyName
      ..['appliedAt'] = FieldValue.serverTimestamp()
      ..['status'] = 'Applied';
    dev.log('Normalized application data: $normalizedApplicationData', name: 'AuthService');

    // Use batched write for atomicity
    final batch = _firestore.batch();

    // Create /Applications/{jobId}
    final appRef = _firestore.collection('Applications').doc(jobId);
    batch.set(appRef, {
      'recruiterId': recruiterId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    dev.log('Batched write to Applications/$jobId', name: 'AuthService');

    // Write to recruiter-centric path
    final recruiterAppRef = appRef.collection('AppliedJobs').doc(uid);
    batch.set(recruiterAppRef, normalizedApplicationData);
    dev.log('Batched write to Applications/$jobId/AppliedJobs/$uid', name: 'AuthService');

    // Write to seeker-centric path
    final seekerAppRef = _firestore.collection('Applications').doc(uid).collection('AppliedJobs').doc(jobId);
    batch.set(seekerAppRef, normalizedApplicationData);
    dev.log('Batched write to Applications/$uid/AppliedJobs/$jobId', name: 'AuthService');

    // Create ApplicationsIndex document with unique seekerId_jobId
    final indexRef = _firestore.collection('ApplicationsIndex').doc(indexDocId);
    batch.set(indexRef, {
      'seekerId': uid,
      'jobId': jobId,
      'recruiterId': recruiterId,
      'status': 'Applied',
      'createdAt': FieldValue.serverTimestamp(),
    });
    dev.log('Batched write to ApplicationsIndex/$indexDocId', name: 'AuthService');

    // Create notification
    final notificationId = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc().id;
    final notifRef = _firestore.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc(notificationId);
    final seekerProfile = await fetchProfileData(isRecruiter: false);
    final seekerName = seekerProfile?['name'] as String? ?? uid;
    batch.set(notifRef, {
      'to': recruiterId,
      'from': uid,
      'message': 'New application for "$jobTitle" from $seekerName',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'application',
      'jobId': jobId,
      'read': false,
      'notificationId': notificationId,
    });
    dev.log('Batched notification $notificationId to RecruiterNotifications/$recruiterId: $jobTitle from $seekerName', name: 'AuthService');

    // Commit batch
    try {
      await batch.commit();
      dev.log('Batch commit successful for job $jobId by $uid', name: 'AuthService');
    } catch (e) {
      dev.log('Batch commit failed for job $jobId: $e', name: 'AuthService', error: e);
      if (e is FirebaseException) {
        dev.log('Batch paths: Applications/$jobId, Applications/$jobId/AppliedJobs/$uid, Applications/$uid/AppliedJobs/$jobId, ApplicationsIndex/$indexDocId, RecruiterNotifications/$recruiterId/Notifications/$notificationId', name: 'AuthService');
        dev.log('Application data: $normalizedApplicationData', name: 'AuthService');
        dev.log('Index data: {seekerId: $uid, jobId: $jobId, recruiterId: $recruiterId, status: Applied}', name: 'AuthService');
        dev.log('Notification data: {to: $recruiterId, from: $uid, message: New application for "$jobTitle" from $seekerName}', name: 'AuthService');
      }
      throw AuthException('Application failed: ${e.toString()}');
    }

    dev.log("Application submitted for job $jobId by $uid", name: 'AuthService');
  } catch (e) {
    dev.log("applyToJob ERROR for job $jobId: $e", name: 'AuthService', error: e);
    if (e is FirebaseException) {
      throw AuthException("Application failed: ${e.code} - ${e.message}");
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
      for (final job in jobsSnapshot.docs) {
        final jobId = job.id;
        final jobTitle = job.data()['title'] as String? ?? 'Untitled';
        dev.log('Fetching applicants for job $jobId (title: $jobTitle)', name: 'AuthService');

        final appDoc = await _firestore.collection('Applications').doc(jobId).get();
        if (!appDoc.exists) {
          dev.log('Applications/$jobId does not exist, skipping', name: 'AuthService');
          continue;
        }
        final appData = appDoc.data()!;
        dev.log('Applications/$jobId data: $appData', name: 'AuthService');
        if (appData['recruiterId'] != uid) {
          dev.log('Applications/$jobId has incorrect recruiterId: ${appData['recruiterId']}, expected: $uid', name: 'AuthService');
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
          final seekerId = app.id;
          dev.log('Processing application for seeker $seekerId in job $jobId', name: 'AuthService');

          // Check ApplicationsIndex
          final indexDoc = await _firestore
              .collection('ApplicationsIndex')
              .doc('${uid}_$seekerId')
              .get();
          if (!indexDoc.exists) {
            dev.log('ApplicationsIndex/${uid}_$seekerId missing for job $jobId', name: 'AuthService');
            // Still include application with fallback name
            seekers.add({
              'seekerId': seekerId,
              'jobId': jobId,
              'jobTitle': data['jobTitle'] as String? ?? jobTitle,
              'appliedAt': data['appliedAt'],
              'resume': data['resume'] as Map<String, dynamic>? ?? {},
              'coverLetter': data['coverLetter'] as String? ?? '',
              'status': data['status'] as String? ?? 'Applied',
              'name': seekerId, // Fallback to seekerId
            });
            continue;
          }
          dev.log('ApplicationsIndex/${uid}_$seekerId data: ${indexDoc.data()}', name: 'AuthService');

          String? name;
          try {
            final seekerProfile = await _firestore.collection('Seekers').doc(seekerId).get();
            if (!seekerProfile.exists) {
              dev.log('Seeker/$seekerId profile missing for job $jobId, using seekerId as name', name: 'AuthService');
              name = seekerId;
            } else {
              name = seekerProfile.data()?['name'] ?? seekerId;
              dev.log('Seeker $seekerId name: $name', name: 'AuthService');
            }
          } catch (e) {
            dev.log('Failed to read Seeker/$seekerId for job $jobId: $e', name: 'AuthService', error: e);
            if (e is FirebaseException && e.code == 'permission-denied') {
              dev.log('Permission denied for Seeker/$seekerId. Checking ApplicationsIndex and AppliedJobs', name: 'AuthService');
              dev.log('ApplicationsIndex/${uid}_$seekerId exists: ${indexDoc.exists}', name: 'AuthService');
              final appliedJobDoc = await _firestore
                  .collection('Applications')
                  .doc(jobId)
                  .collection('AppliedJobs')
                  .doc(seekerId)
                  .get();
              dev.log('Applications/$jobId/AppliedJobs/$seekerId exists: ${appliedJobDoc.exists}, data: ${jsonEncode(appliedJobDoc.data() ?? {})}', name: 'AuthService');
            }
            name = seekerId; // Fallback to seekerId
          }

          seekers.add({
            'seekerId': seekerId,
            'jobId': jobId,
            'jobTitle': data['jobTitle'] as String? ?? jobTitle,
            'appliedAt': data['appliedAt'],
            'resume': data['resume'] as Map<String, dynamic>? ?? {},
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

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}