import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;

void verifyApplications() async {
  final recruiterId = 'GHcXU6zRRXTjmqiBU0lHlMlWKUm2';
  final jobId = 'DYTCQwJoGcZICKsnYstU';
  final seekerId = 'etXbP6PQzEgM3NKmXgyTHpuRRmi1';

  try {
    // Check current user and role
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idTokenResult = await user.getIdTokenResult();
      dev.log('Current user ${user.uid} role: ${idTokenResult.claims?['role']}', name: 'VerifyScript');
      if (user.uid == seekerId && idTokenResult.claims?['role'] != 'seeker') {
        dev.log('ERROR: Seeker $seekerId does not have seeker role', name: 'VerifyScript');
      }
      if (user.uid == recruiterId && idTokenResult.claims?['role'] != 'recruiter') {
        dev.log('ERROR: Recruiter $recruiterId does not have recruiter role', name: 'VerifyScript');
      }
    } else {
      dev.log('ERROR: No authenticated user', name: 'VerifyScript');
    }

    // Check /Recruiters/{recruiterId}/Jobs/{jobId}
    final jobDoc = await FirebaseFirestore.instance
        .collection('Recruiters')
        .doc(recruiterId)
        .collection('Jobs')
        .doc(jobId)
        .get();
    if (!jobDoc.exists) {
      dev.log('ERROR: Recruiters/$recruiterId/Jobs/$jobId does not exist', name: 'VerifyScript');
    } else {
      final jobData = jobDoc.data()!;
      dev.log('Recruiters/$recruiterId/Jobs/$jobId: $jobData', name: 'VerifyScript');
      if (jobData['recruiterId'] != recruiterId) {
        dev.log('ERROR: Job $jobId has incorrect recruiterId: ${jobData['recruiterId']}', name: 'VerifyScript');
      }
    }

    // Check /Applications/{jobId}
    final appDoc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(jobId)
        .get();
    if (!appDoc.exists) {
      dev.log('ERROR: Applications/$jobId does not exist', name: 'VerifyScript');
    } else {
      final appData = appDoc.data()!;
      dev.log('Applications/$jobId: $appData', name: 'VerifyScript');
      if (appData['recruiterId'] != recruiterId) {
        dev.log('ERROR: Applications/$jobId has incorrect recruiterId: ${appData['recruiterId']}', name: 'VerifyScript');
      }
    }

    // Check /Applications/{jobId}/AppliedJobs/{seekerId}
    final appliedJobDoc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(jobId)
        .collection('AppliedJobs')
        .doc(seekerId)
        .get();
    if (!appliedJobDoc.exists) {
      dev.log('ERROR: Applications/$jobId/AppliedJobs/$seekerId does not exist', name: 'VerifyScript');
    } else {
      dev.log('Applications/$jobId/AppliedJobs/$seekerId: ${appliedJobDoc.data()}', name: 'VerifyScript');
    }

    // Check /Applications/{seekerId}/AppliedJobs/{jobId}
    final seekerAppliedJobDoc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(seekerId)
        .collection('AppliedJobs')
        .doc(jobId)
        .get();
    if (!seekerAppliedJobDoc.exists) {
      dev.log('ERROR: Applications/$seekerId/AppliedJobs/$jobId does not exist', name: 'VerifyScript');
    } else {
      dev.log('Applications/$seekerId/AppliedJobs/$jobId: ${seekerAppliedJobDoc.data()}', name: 'VerifyScript');
    }

    // Check /ApplicationsIndex/{recruiterId_seekerId}
    final indexDoc = await FirebaseFirestore.instance
        .collection('ApplicationsIndex')
        .doc('${recruiterId}_$seekerId')
        .get();
    if (!indexDoc.exists) {
      dev.log('ERROR: ApplicationsIndex/${recruiterId}_$seekerId does not exist', name: 'VerifyScript');
    } else {
      final indexData = indexDoc.data()!;
      dev.log('ApplicationsIndex/${recruiterId}_$seekerId: $indexData', name: 'VerifyScript');
      if (indexData['jobId'] != jobId || indexData['status'] != 'active') {
        dev.log('ERROR: ApplicationsIndex/${recruiterId}_$seekerId has incorrect data: jobId=${indexData['jobId']}, status=${indexData['status']}', name: 'VerifyScript');
      }
      if (indexData['recruiterId'] != recruiterId) {
        dev.log('ERROR: ApplicationsIndex/${recruiterId}_$seekerId has incorrect recruiterId: ${indexData['recruiterId']}', name: 'VerifyScript');
      }
    }

    // Check /Seekers/{seekerId} with recruiter context
    await FirebaseAuth.instance.signInAnonymously(); // Simulate recruiter login if needed
    await FirebaseAuth.instance.currentUser!.updateProfile(displayName: recruiterId);
    await FirebaseAuth.instance.currentUser!.getIdToken(true);
    try {
      final seekerProfile = await FirebaseFirestore.instance
          .collection('Seekers')
          .doc(seekerId)
          .get();
      if (!seekerProfile.exists) {
        dev.log('ERROR: Seekers/$seekerId does not exist', name: 'VerifyScript');
      } else {
        dev.log('Seekers/$seekerId: ${seekerProfile.data()}', name: 'VerifyScript');
      }
    } catch (e) {
      dev.log('ERROR: Failed to read Seekers/$seekerId as recruiter $recruiterId: $e', name: 'VerifyScript', error: e);
    }

    // Check /UsersIndex/{recruiterId}
    final userIndexDoc = await FirebaseFirestore.instance
        .collection('UsersIndex')
        .doc(recruiterId)
        .get();
    if (!userIndexDoc.exists) {
      dev.log('ERROR: UsersIndex/$recruiterId does not exist', name: 'VerifyScript');
    } else {
      dev.log('UsersIndex/$recruiterId: ${userIndexDoc.data()}', name: 'VerifyScript');
    }

    // Check /RecruiterNotifications/{recruiterId}/Notifications
    final notifSnapshot = await FirebaseFirestore.instance
        .collection('RecruiterNotifications')
        .doc(recruiterId)
        .collection('Notifications')
        .where('jobId', isEqualTo: jobId)
        .get();
    if (notifSnapshot.docs.isEmpty) {
      dev.log('ERROR: No notifications found for job $jobId in RecruiterNotifications/$recruiterId', name: 'VerifyScript');
    } else {
      for (var doc in notifSnapshot.docs) {
        dev.log('RecruiterNotifications/$recruiterId/Notifications/${doc.id}: ${doc.data()}', name: 'VerifyScript');
      }
    }

    dev.log('Verification complete', name: 'VerifyScript');
  } catch (e) {
    dev.log('Verification failed: $e', name: 'VerifyScript', error: e);
  } finally {
    await FirebaseAuth.instance.signOut(); // Clean up anonymous login
  }
}