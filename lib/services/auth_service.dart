import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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

      // Ensure role claim is set via Cloud Function
      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('setUserRole')
          .call({'uid': uid, 'role': isRecruiter ? 'recruiter' : 'seeker'});
      await _auth.currentUser!.getIdToken(true); // Refresh token to include new claim
      dev.log("Role claim set and token refreshed for $uid", name: 'AuthService');

      dev.log("storeSignupData completed for $uid", name: 'AuthService');
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
      // Create Applications/{jobId} document
      await _firestore.collection('Applications').doc(doc.id).set({
        'recruiterId': uid,
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
      // Fetch job data from Recruiters/{recruiterId}/Jobs/{jobId}
      final jobSnapshot = await _firestore
          .collection('Recruiters')
          .doc(recruiterId)
          .collection('Jobs')
          .doc(jobId)
          .get();
      if (!jobSnapshot.exists) throw const AuthException("Job not found");
      final jobData = jobSnapshot.data()!;
      final jobTitle = jobData['title'] as String? ?? 'Untitled';

      // Ensure parent document exists
      await _firestore.collection('Applications').doc(jobId).set({'recruiterId': recruiterId}, SetOptions(merge: true));

      // Normalize application data
      final normalizedApplicationData = Map<String, dynamic>.from(applicationData)
        ..['seekerId'] = uid
        ..['jobId'] = jobId
        ..['recruiterId'] = recruiterId
        ..['jobTitle'] = jobTitle
        ..['appliedAt'] = FieldValue.serverTimestamp()
        ..['status'] = 'Applied';

      // Write to both recruiter-centric and seeker-centric paths
      await _firestore
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .doc(uid)
          .set(normalizedApplicationData);
      await _firestore
          .collection('Applications')
          .doc(uid)
          .collection('AppliedJobs')
          .doc(jobId)
          .set(normalizedApplicationData);

      // Create ApplicationsIndex document to allow recruiter to view seeker profile
      await _firestore
          .collection('ApplicationsIndex')
          .doc('${recruiterId}_${uid}')
          .set({'status': 'active'}, SetOptions(merge: true));

      // Fetch seeker profile for notification
      final seekerProfile = await fetchProfileData(isRecruiter: false);
      final seekerName = seekerProfile?['name'] as String? ?? uid;

      await sendApplicationNotification(recruiterId, jobId, jobTitle, seekerName);
      dev.log("Application submitted for job $jobId by $uid", name: 'AuthService');
    } catch (e) {
      dev.log("applyToJob ERROR: $e", name: 'AuthService', error: e);
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
      // Verify role claim
      final idTokenResult = await _auth.currentUser!.getIdTokenResult();
      final role = idTokenResult.claims?['role'];
      dev.log('User $uid role claim: $role', name: 'AuthService');
      if (role != 'recruiter') {
        throw const AuthException('User is not a recruiter');
      }

      // Fetch recruiter's jobs
      final jobsSnapshot = await _firestore
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs')
          .get();

      final List<Map<String, dynamic>> seekers = [];
      for (final job in jobsSnapshot.docs) {
        final jobId = job.id;
        final jobTitle = job.data()['title'] as String? ?? 'Untitled';
        dev.log('Fetching applicants for job $jobId', name: 'AuthService');

        // Ensure Applications/{jobId} exists
        final appDoc = await _firestore.collection('Applications').doc(jobId).get();
        if (!appDoc.exists) {
          dev.log('Applications/$jobId does not exist', name: 'AuthService');
          continue;
        }
        if (appDoc.data()?['recruiterId'] != uid) {
          dev.log('Applications/$jobId has incorrect recruiterId: ${appDoc.data()?['recruiterId']}', name: 'AuthService');
          continue;
        }

        final appsSnapshot = await _firestore
            .collection('Applications')
            .doc(jobId)
            .collection('AppliedJobs')
            .orderBy('appliedAt', descending: true)
            .get();

        for (final app in appsSnapshot.docs) {
          final data = app.data();
          final seekerId = app.id;
          final seekerProfile = await _firestore.collection('Seekers').doc(seekerId).get();
          final name = seekerProfile.exists ? (seekerProfile.data()?['name'] ?? seekerId) : seekerId;

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
        dev.log('Fetched ${appsSnapshot.docs.length} applicants for job $jobId', name: 'AuthService');
      }
      dev.log('Returning ${seekers.length} seekers for $uid', name: 'AuthService');
      return seekers;
    } catch (e, stackTrace) {
      dev.log('fetchAppliedSeekers ERROR for $uid: $e', name: 'AuthService', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('Firebase error details: ${e.code} - ${e.message}', name: 'AuthService');
        throw AuthException("Failed to fetch seekers: ${e.code} - ${e.message}");
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchScheduledCalls() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException("User not logged in");

    try {
      final callsSnapshot = await _firestore
          .collectionGroup('AppliedJobs')
          .where('recruiterId', isEqualTo: uid)
          .where('status', isEqualTo: 'Interview Scheduled')
          .orderBy('interviewDate', descending: false)
          .get();
      dev.log('Fetched ${callsSnapshot.docs.length} scheduled calls for $uid with query: recruiterId=$uid, status=Interview Scheduled, orderBy=interviewDate', name: 'AuthService');

      final List<Map<String, dynamic>> calls = [];
      for (final call in callsSnapshot.docs) {
        final data = call.data();
        final seekerId = call.id;
        final seekerProfile = await _firestore.collection('Seekers').doc(seekerId).get();
        final name = seekerProfile.exists ? (seekerProfile.data()?['name'] ?? seekerId) : seekerId;

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
        throw const AuthException("Failed to fetch scheduled calls: Check role claim or Firestore rules");
      }
      rethrow;
    }
  }

  Future<void> sendApplicationNotification(String recipientId, String jobId, String jobTitle, String seekerName) async {
    try {
      final tokenSnapshot = await _firestore.collection('UsersIndex').doc(recipientId).get();
      final token = tokenSnapshot.data()?['fcmToken'] as String?;
      if (token == null) {
        dev.log("No FCM token found for recipient $recipientId", name: 'AuthService');
      }

      final notificationId = _firestore.collection('SeekerNotifications').doc(recipientId).collection('Notifications').doc().id;
      await _firestore
          .collection('SeekerNotifications')
          .doc(recipientId)
          .collection('Notifications')
          .doc(notificationId)
          .set({
            'to': recipientId,
            'from': _auth.currentUser?.uid,
            'message': 'New application for "$jobTitle" from $seekerName',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'application',
            'jobId': jobId,
            'read': false,
            'notificationId': notificationId,
          });
      dev.log("Notification $notificationId sent to $recipientId for job $jobId", name: 'AuthService');
    } catch (e) {
      dev.log("sendApplicationNotification ERROR for recipient $recipientId: $e", name: 'AuthService', error: e);
      if (e is FirebaseException) {
        throw AuthException("Notification failed: ${e.code} - ${e.message}");
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
      final userIndexDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (userIndexDoc.exists) {
        final role = userIndexDoc.data()?['role'] as String?;
        if (role != null) {
          dev.log("Role found for $uid: $role", name: 'AuthService');
          return role;
        }
      }
      dev.log("No role found in UsersIndex for $uid, falling back to collections", name: 'AuthService');
      final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
      if (recruiterDoc.exists) return 'recruiter';

      final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
      if (seekerDoc.exists) return 'seeker';

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