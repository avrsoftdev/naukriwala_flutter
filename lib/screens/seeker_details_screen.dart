import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SeekerDetailsScreen extends StatelessWidget {
  final String seekerId;
  final String jobId;

  const SeekerDetailsScreen({
    super.key,
    required this.seekerId,
    required this.jobId,
  });

  Future<Map<String, dynamic>> _fetchSeekerDetails() async {
    final firestore = FirebaseFirestore.instance;

    final userIndexFuture = firestore.collection('UsersIndex').doc(seekerId).get();
    final applicationFuture = firestore.collection('Applications').doc('${seekerId}_$jobId').get();

    final results = await Future.wait([userIndexFuture, applicationFuture]);
    final userIndexDoc = results[0];
    final applicationDoc = results[1];

    final details = <String, dynamic>{};

    if (userIndexDoc.exists) {
      final userData = userIndexDoc.data() ?? <String, dynamic>{};
      details['name'] = (details['name'] ?? userData['name'] ?? userData['fullName'] ?? '').toString();
      details['email'] = (details['email'] ?? userData['email'] ?? '').toString();
      details['mobileNumber'] = (details['mobileNumber'] ?? userData['mobileNumber'] ?? '').toString();
      details['photoUrl'] = (details['photoUrl'] ?? userData['photoUrl'] ?? userData['profilePhotoUrl'] ?? '').toString();
    }

    if (applicationDoc.exists) {
      final applicationData = applicationDoc.data() ?? <String, dynamic>{};
      final resume = applicationData['resume'] as Map<String, dynamic>? ?? <String, dynamic>{};

      details['name'] = (resume['name'] ?? details['name'] ?? '').toString();
      details['email'] = (resume['email'] ?? details['email'] ?? '').toString();
      details['mobileNumber'] = (resume['mobileNumber'] ?? details['mobileNumber'] ?? '').toString();
      details['education'] = (resume['education'] ?? details['education'] ?? '').toString();
      details['experience'] = (resume['experience'] ?? details['experience'] ?? '').toString();
      details['specialization'] = (resume['specialization'] ?? details['specialization'] ?? '').toString();
      details['currentCompany'] = (resume['currentCompany'] ?? details['currentCompany'] ?? '').toString();
      details['currentCtc'] = (resume['currentCtc'] ?? details['currentCtc'] ?? '').toString();
      details['expectedCtc'] = (resume['expectedCtc'] ?? details['expectedCtc'] ?? '').toString();
      details['resumeUrl'] = (resume['cvUrl'] ?? details['resumeUrl'] ?? '').toString();
      details['photoUrl'] = (resume['photoUrl'] ?? resume['profilePhotoUrl'] ?? details['photoUrl'] ?? '').toString();
      details['jobTitle'] = (applicationData['jobTitle'] ?? '').toString();
      details['company'] = (applicationData['company'] ?? '').toString();

      final resumeSkills = resume['skills'];
      if (resumeSkills != null) {
        details['skills'] = resumeSkills;
      }
    }

    return details;
  }

  String _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join(', ');
    }
    return value?.toString() ?? '';
  }

  Widget _detailTile(IconData icon, String label, String value) {
    final safeValue = value.trim().isEmpty ? 'N/A' : value;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: Colors.blueGrey),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                SelectableText(
                  safeValue,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seeker Details'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchSeekerDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load seeker details'));
          }

          final data = snapshot.data ?? <String, dynamic>{};
          final name = (data['name']?.toString() ?? '').trim();
          final photoUrl = (data['photoUrl']?.toString() ?? '').trim();

          return SingleChildScrollView(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42.r,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 30.sp, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        name.isEmpty ? 'Unknown Seeker' : name,
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),
                _detailTile(Icons.mail_outline, 'Email', data['email']?.toString() ?? ''),
                _detailTile(Icons.phone_outlined, 'Mobile Number', data['mobileNumber']?.toString() ?? ''),
                _detailTile(Icons.school_outlined, 'Education', data['education']?.toString() ?? ''),
                _detailTile(Icons.work_outline, 'Experience', data['experience']?.toString() ?? ''),
                _detailTile(Icons.category_outlined, 'Specialization', data['specialization']?.toString() ?? ''),
                _detailTile(Icons.handyman_outlined, 'Skills', _stringList(data['skills'])),
                _detailTile(Icons.business_outlined, 'Current Company', data['currentCompany']?.toString() ?? ''),
                _detailTile(Icons.currency_rupee_outlined, 'Current CTC', data['currentCtc']?.toString() ?? ''),
                _detailTile(Icons.currency_rupee, 'Expected CTC', data['expectedCtc']?.toString() ?? ''),
                _detailTile(Icons.description_outlined, 'Resume URL', data['resumeUrl']?.toString() ?? ''),
                _detailTile(Icons.work_history_outlined, 'Applied Job', data['jobTitle']?.toString() ?? ''),
                _detailTile(Icons.apartment_outlined, 'Company', data['company']?.toString() ?? ''),
              ],
            ),
          );
        },
      ),
    );
  }
}
