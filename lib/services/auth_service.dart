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
    if (uid == null) throw Exception("User not logged in");

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

      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('setUserRole')
          .call({
            'uid': uid,
            'role': isRecruiter ? 'recruiter' : 'seeker',
          });

      dev.log("storeSignupData completed for $uid", name: 'AuthService');
    } catch (e) {
      dev.log("storeSignupData ERROR: $e", name: 'AuthService', error: e);
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
    if (uid == null) throw Exception("User not logged in");

    try {
      final ref = _storage.ref("company_logos/$uid/logo.png");
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      dev.log("Company logo uploaded for $uid: $url", name: 'AuthService');
      return url;
    } catch (e) {
      dev.log("uploadCompanyLogo ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<String> uploadSeekerPhoto(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      final ref = _storage.ref("seeker_photos/$uid/photo.png");
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      dev.log("Seeker photo uploaded for $uid: $url", name: 'AuthService');
      return url;
    } catch (e) {
      dev.log("uploadSeekerPhoto ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<void> postJob(Map<String, dynamic> jobData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

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
      dev.log("Job posted with ID ${doc.id} by $uid", name: 'AuthService');
    } catch (e) {
      dev.log("postJob ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobsWithApplicationCounts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

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
      rethrow;
    }
  }

  Future<void> applyToJob(
    String jobId,
    Map<String, dynamic> applicationData,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      // Fetch job data directly from the recruiter's Jobs collection
      final jobSnapshot = await _firestore
          .collection('Recruiters')
          .where('Jobs', arrayContains: {'jobId': jobId}) // Adjust based on structure
          .limit(1)
          .get();
      if (jobSnapshot.docs.isEmpty) throw Exception("Job not found");
      final jobData = jobSnapshot.docs.first.data();
      final recruiterId = jobData['recruiterId'] as String?;
      if (recruiterId == null) throw Exception("Recruiter ID not found for job $jobId");
      final jobTitle = jobData['title'] as String? ?? 'Untitled';

      // Ensure parent document exists
      await _firestore.collection('Applications').doc(jobId).set({'recruiterId': recruiterId}, SetOptions(merge: true));

      // Normalize application data
      final normalizedApplicationData = Map<String, dynamic>.from(applicationData)
        ..['seekerId'] = uid
        ..['jobId'] = jobId
        ..['recruiterId'] = recruiterId
        ..['appliedAt'] = FieldValue.serverTimestamp()
        ..['status'] = 'Applied';

      await _firestore
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .doc(uid)
          .set(normalizedApplicationData);

      // Fetch seeker profile for notification
      final seekerProfile = await fetchProfileData(isRecruiter: false);
      final seekerName = seekerProfile?['name'] as String? ?? uid;

      await sendApplicationNotification(recruiterId, jobId, jobTitle, seekerName);
      dev.log("Application submitted for job $jobId by $uid", name: 'AuthService');
    } catch (e) {
      dev.log("applyToJob ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      final appsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('AppliedJobs')
          .where('recruiterId', isEqualTo: uid)
          .orderBy('appliedAt', descending: true)
          .get();
      dev.log('Fetched ${appsSnapshot.docs.length} applications for $uid with query: recruiterId=$uid, orderBy=appliedAt', name: 'AuthService');

      final List<Map<String, dynamic>> seekers = [];
      for (final app in appsSnapshot.docs) {
        final data = app.data();
        // Fetch seeker name from Seekers collection
        final seekerId = app.id;
        final seekerProfile = await _firestore.collection('Seekers').doc(seekerId).get();
        final name = seekerProfile.exists ? (seekerProfile.data()?['name'] ?? seekerId) : seekerId;

        seekers.add({
          'seekerId': seekerId,
          'jobId': data['jobId'] as String? ?? '',
          'jobTitle': data['jobTitle'] as String? ?? '',
          'appliedAt': data['appliedAt'],
          'resume': data['resume'] as Map<String, dynamic>? ?? {},
          'coverLetter': data['coverLetter'] as String? ?? '',
          'status': data['status'] as String? ?? 'Applied',
          'name': name,
        });
      }
      return seekers;
    } catch (e) {
      dev.log('fetchAppliedSeekers ERROR: $e', name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<void> sendApplicationNotification(String recipientId, String jobId, String jobTitle, String seekerName) async {
    try {
      final tokenSnapshot = await _firestore.collection('UsersIndex').doc(recipientId).get();
      final token = tokenSnapshot.data()?['fcmToken'] as String?;

      if (token != null) {
        await _firestore.collection('SeekerNotifications').doc(recipientId).collection('Notifications').add({
          'to': recipientId,
          'from': _auth.currentUser?.uid,
          'message': 'New application for "$jobTitle" from $seekerName',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'application',
          'jobId': jobId,
          'read': false,
        });
        dev.log("Notification sent to $recipientId for job $jobId", name: 'AuthService');
      } else {
        dev.log("No FCM token found for $recipientId", name: 'AuthService');
      }
    } catch (e) {
      dev.log("sendApplicationNotification ERROR: $e", name: 'AuthService', error: e);
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