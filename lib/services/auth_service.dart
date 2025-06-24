import 'dart:io';
import 'dart:developer';
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
      log("Writing to $collection/$uid", name: 'AuthService');
      await _firestore.collection(collection).doc(uid).set(data, SetOptions(merge: true));

      log("Write successful", name: 'AuthService');
      await _firestore.collection('UsersIndex').doc(uid).set({
        'email': data['Email Id'],
        'mobile': data['Mobile Number'],
      }, SetOptions(merge: true));
      log("UsersIndex updated", name: 'AuthService');

      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('setUserRole')
          .call({
            'uid': uid,
            'role': isRecruiter ? 'recruiter' : 'seeker',
          });

      log("storeSignupData completed", name: 'AuthService');
    } catch (e) {
      log("storeSignupData ERROR: $e", name: 'AuthService', error: e);
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
      log("uploadCompanyLogo ERROR: $e", name: 'AuthService', error: e);
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
      log("uploadSeekerPhoto ERROR: $e", name: 'AuthService', error: e);
      rethrow;
    }
  }

  Future<void> postJob(Map<String, dynamic> jobData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final doc = _firestore.collection('Jobs').doc();
    jobData['jobId'] = doc.id;
    jobData['recruiterId'] = uid;
    jobData['status'] = 'open';
    jobData['timestamp'] = FieldValue.serverTimestamp();

    await doc.set(jobData);
  }

  Future<List<Map<String, dynamic>>> fetchJobsWithApplicationCounts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final jobsSnapshot = await _firestore
        .collection('Jobs')
        .where('recruiterId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
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
      if (resumeFile != null) {
        final fileName = "${DateTime.now().millisecondsSinceEpoch}.pdf";
        final ref = _storage.ref("resumes/$jobId/$uid/$fileName");
        await ref.putFile(resumeFile);
        final resumeUrl = await ref.getDownloadURL();
        applicationData['resumeUrl'] = resumeUrl;
      }

      applicationData['seekerId'] = uid;
      applicationData['appliedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('Applications')
          .doc(uid)
          .collection('AppliedJobs')
          .doc(jobId)

          .set(applicationData);
    } catch (e) {
      log("applyToJob ERROR: $e", name: 'AuthService', error: e);
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