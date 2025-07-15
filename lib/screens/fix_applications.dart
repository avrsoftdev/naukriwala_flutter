import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

void fixApplications() async {
  final recruiterId = 'GHcXU6zRRXTjmqiBU0lHlMlWKUm2';
  final jobId = 'DYTCQwJoGcZICKsnYstU';
  final seekerId = 'etXbP6PQzEgM3NKmXgyTHpuRRmi1';

  try {
    // Verify job exists
    final jobDoc = await FirebaseFirestore.instance
        .collection('Recruiters')
        .doc(recruiterId)
        .collection('Jobs')
        .doc(jobId)
        .get();
    if (!jobDoc.exists) {
      dev.log('ERROR: Recruiters/$recruiterId/Jobs/$jobId does not exist, cannot fix', name: 'FixScript');
      return;
    }
    dev.log('Verified Recruiters/$recruiterId/Jobs/$jobId exists', name: 'FixScript');

    // Create /Applications/{jobId}
    await FirebaseFirestore.instance
        .collection('Applications')
        .doc(jobId)
        .set({
          'recruiterId': recruiterId,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    dev.log('Fixed Applications/$jobId', name: 'FixScript');

    // Create /ApplicationsIndex/{recruiterId_seekerId}
    await FirebaseFirestore.instance
        .collection('ApplicationsIndex')
        .doc('${recruiterId}_$seekerId')
        .set({
          'status': 'active',
          'jobId': jobId,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    dev.log('Fixed ApplicationsIndex/${recruiterId}_$seekerId', name: 'FixScript');

    // Ensure /Applications/{jobId}/AppliedJobs/{seekerId} exists
    final seekerProfile = await FirebaseFirestore.instance
        .collection('Seekers')
        .doc(seekerId)
        .get();
    if (seekerProfile.exists) {
      final applicationData = {
        'jobId': jobId,
        'jobTitle': 'Account Handler',
        'seekerId': seekerId,
        'recruiterId': recruiterId,
        'coverLetter': 'Sample cover letter',
        'status': 'Applied',
        'appliedAt': FieldValue.serverTimestamp(),
        'resume': seekerProfile.data(),
      };
      await FirebaseFirestore.instance
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .doc(seekerId)
          .set(applicationData);
      await FirebaseFirestore.instance
          .collection('Applications')
          .doc(seekerId)
          .collection('AppliedJobs')
          .doc(jobId)
          .set(applicationData);
      dev.log('Fixed Applications/$jobId/AppliedJobs/$seekerId and Applications/$seekerId/AppliedJobs/$jobId', name: 'FixScript');
    } else {
      dev.log('ERROR: Seekers/$seekerId does not exist', name: 'FixScript');
      return;
    }

    // Create test notification
    final notificationId = FirebaseFirestore.instance
        .collection('RecruiterNotifications')
        .doc(recruiterId)
        .collection('Notifications')
        .doc()
        .id;
    await FirebaseFirestore.instance
        .collection('RecruiterNotifications')
        .doc(recruiterId)
        .collection('Notifications')
        .doc(notificationId)
        .set({
          'to': recruiterId,
          'from': seekerId,
          'message': 'New application for "Account Handler" from Arjun',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'application',
          'jobId': jobId,
          'read': false,
          'notificationId': notificationId,
        });
    dev.log('Created test notification $notificationId for $recruiterId', name: 'FixScript');
  } catch (e) {
    dev.log('Fix failed: $e', name: 'FixScript', error: e);
  }
}