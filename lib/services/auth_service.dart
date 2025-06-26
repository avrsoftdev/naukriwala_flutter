import 'dart:io';
import 'dart:developer' as dev; // Changed to avoid conflict with global log
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
        ..['mobileNumber'] = data['Mobile Number'] ?? '';
      await _firestore.collection(collection).doc(uid).set(normalizedData, SetOptions(merge: true));

      dev.log("Write successful", name: 'AuthService');
      await _firestore.collection('UsersIndex').doc(uid).set({
        'email': data['Email Id'],
        'mobileNumber': data['Mobile Number'] ?? '',
      }, SetOptions(merge: true));
      dev.log("UsersIndex updated", name: 'AuthService');

      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('setUserRole')
          .call({
            'uid': uid,
            'role': isRecruiter ? 'recruiter' : 'seeker',
          });

      dev.log("storeSignupData completed", name: 'AuthService');
    } catch (e) {
      dev.log("storeSignupData ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchProfileData({required bool isRecruiter}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final collection = isRecruiter ? 'Recruiters' : 'Seekers';
    final doc = await _firestore.collection(collection).doc(uid).get();
    return doc.data();
  }

  Future<String> uploadCompanyLogo(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      final ref = _storage.ref("company_logos/$uid/logo.png");
      await ref.putFile(file);
      return await ref.getDownloadURL();
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
      return await ref.getDownloadURL();
    } catch (e) {
      dev.log("uploadSeekerPhoto ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<void> postJob(Map<String, dynamic> jobData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final doc = _firestore.collection('Recruiters').doc(uid).collection('Jobs').doc();
    jobData['jobId'] = doc.id;
    jobData['recruiterId'] = uid;
    jobData['status'] = 'open';
    jobData['createdAt'] = FieldValue.serverTimestamp();

    await doc.set(jobData);
  }

  Future<List<Map<String, dynamic>>> fetchJobsWithApplicationCounts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

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
          .collectionGroup('AppliedJobs')
          .where('jobId', isEqualTo: jobId)
          .get();

      result.add({
        ...job.data(),
        'jobId': jobId,
        'applicationCount': apps.size,
      });
    }

    return result;
  }

  Future<void> applyToJob(
    String jobId,
    Map<String, dynamic> applicationData,
    File? resumeFile,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      // Fetch recruiterId from the job document
      final jobSnapshot = await _firestore
          .collectionGroup('Jobs')
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();
      if (jobSnapshot.docs.isEmpty) throw Exception("Job not found");
      final recruiterId = jobSnapshot.docs.first.data()['recruiterId'];

      // Optionally create Applications/{jobId} with recruiterId if not exists
      await _firestore.collection('Applications').doc(jobId).set({'recruiterId': recruiterId}, SetOptions(merge: true));

      if (resumeFile != null) {
        final fileName = "${DateTime.now().millisecondsSinceEpoch}.pdf";
        final ref = _storage.ref("resumes/$jobId/$uid/$fileName");
        await ref.putFile(resumeFile);
        final resumeUrl = await ref.getDownloadURL();
        applicationData['resumeUrl'] = resumeUrl;
      }

      applicationData['seekerId'] = uid;
      applicationData['jobId'] = jobId;
      applicationData['appliedAt'] = FieldValue.serverTimestamp();
      applicationData['recruiterId'] = recruiterId;

      await _firestore
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .doc(uid)
          .set(applicationData);

      await sendApplicationNotification(recruiterId, 'New application for job $jobId from $uid');
    } catch (e) {
      dev.log("applyToJob ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppliedSeekers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final List<Map<String, dynamic>> seekers = [];
    final appsSnapshot = await FirebaseFirestore.instance
        .collectionGroup('AppliedJobs')
        .where('recruiterId', isEqualTo: uid)
        .orderBy('appliedAt', descending: true)
        .get();

    for (final app in appsSnapshot.docs) {
      final data = app.data();
      seekers.add({
        'seekerId': app.id,
        'jobId': data['jobId'],
        'appliedAt': data['appliedAt'],
        'resumeUrl': data['resumeUrl'],
        ...data,
      });
    }

    return seekers;
  }

  Future<void> sendApplicationNotification(String recipientId, String message) async {
    try {
      final tokenSnapshot = await _firestore.collection('UsersIndex').doc(recipientId).get();
      final token = tokenSnapshot.data()?['fcmToken'];

      if (token != null) {
        await _firestore.collection('Notifications').add({
          'to': token,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
        dev.log("Notification sent to $recipientId", name: 'AuthService');
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

    final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
    if (recruiterDoc.exists) return 'recruiter';

    final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
    if (seekerDoc.exists) return 'seeker';

    return null;
  }
}