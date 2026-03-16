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
    final seekerProfileFuture = firestore.collection('Seekers').doc(seekerId).get();

    final results = await Future.wait([userIndexFuture, applicationFuture, seekerProfileFuture]);
    final userIndexDoc = results[0];
    final applicationDoc = results[1];
    final seekerProfileDoc = results[2];

    final details = <String, dynamic>{};

    // Fetch from UsersIndex (basic info)
    if (userIndexDoc.exists) {
      final userData = userIndexDoc.data() ?? <String, dynamic>{};
      details['name'] = (details['name'] ?? userData['name'] ?? userData['fullName'] ?? '').toString();
      details['email'] = (details['email'] ?? userData['email'] ?? '').toString();
      details['mobileNumber'] = (details['mobileNumber'] ?? userData['mobileNumber'] ?? '').toString();
      details['photoUrl'] = (details['photoUrl'] ?? userData['photoUrl'] ?? userData['profilePhotoUrl'] ?? '').toString();
    }

    // Fetch from Seekers collection (complete profile data)
    if (seekerProfileDoc.exists) {
      final seekerData = seekerProfileDoc.data() ?? <String, dynamic>{};
      
      // Basic profile fields
      details['name'] = (seekerData['name'] ?? details['name'] ?? '').toString();
      details['email'] = (details['email'] ?? seekerData['email'] ?? '').toString();
      details['mobileNumber'] = (details['mobileNumber'] ?? seekerData['mobileNumber'] ?? '').toString();
      details['photoUrl'] = (details['photoUrl'] ?? seekerData['photoUrl'] ?? seekerData['profilePhotoUrl'] ?? '').toString();
      details['education'] = (seekerData['education'] ?? details['education'] ?? '').toString();
      details['experience'] = (seekerData['experience'] ?? details['experience'] ?? '').toString();
      details['specialization'] = (seekerData['specialization'] ?? details['specialization'] ?? '').toString();
      details['currentCompany'] = (seekerData['currentCompany'] ?? details['currentCompany'] ?? '').toString();
      details['currentCtc'] = (seekerData['currentCtc'] ?? details['currentCtc'] ?? '').toString();
      details['expectedCtc'] = (seekerData['expectedCtc'] ?? details['expectedCtc'] ?? '').toString();
      details['resumeUrl'] = (seekerData['resumeUrl'] ?? details['resumeUrl'] ?? '').toString();
      details['city'] = (seekerData['city'] ?? details['city'] ?? '').toString();
      details['linkedinUrl'] = (seekerData['linkedinUrl'] ?? details['linkedinUrl'] ?? '').toString();
      
      // Skills
      final seekerSkills = seekerData['skills'];
      if (seekerSkills != null && seekerSkills is List) {
        details['skills'] = seekerSkills;
      }
      
      // Onboarding details
      details['currentStatus'] = (seekerData['currentStatus'] ?? details['currentStatus'] ?? '').toString();
      details['jobTitle'] = (seekerData['jobTitle'] ?? details['jobTitle'] ?? '').toString();
      details['industry'] = (seekerData['industry'] ?? details['industry'] ?? '').toString();
      details['employmentType'] = (seekerData['employmentType'] ?? details['employmentType'] ?? '').toString();
      details['totalExperienceYears'] = (seekerData['totalExperienceYears'] ?? details['totalExperienceYears'] ?? '').toString();
      details['currentJobStartDate'] = (seekerData['currentJobStartDate'] ?? details['currentJobStartDate'] ?? '').toString();
      details['currentJobEndDate'] = (seekerData['currentJobEndDate'] ?? details['currentJobEndDate'] ?? '').toString();
      details['previousCompanies'] = (seekerData['previousCompanies'] ?? details['previousCompanies'] ?? '').toString();
      details['achievements'] = (seekerData['achievements'] ?? details['achievements'] ?? '').toString();
      details['projects'] = (seekerData['projects'] ?? details['projects'] ?? '').toString();
      details['internships'] = (seekerData['internships'] ?? details['internships'] ?? '').toString();
      details['softSkills'] = (seekerData['softSkills'] ?? details['softSkills'] ?? '').toString();
      details['githubUrl'] = (seekerData['githubUrl'] ?? details['githubUrl'] ?? '').toString();
      details['portfolioUrl'] = (seekerData['portfolioUrl'] ?? details['portfolioUrl'] ?? '').toString();
      
      // Store education details and previous experiences for display
      details['educationDetails'] = seekerData['educationDetails'];
      details['previousExperiences'] = seekerData['previousExperiences'];
    }

    // Fetch from Applications (application-specific data)
    if (applicationDoc.exists) {
      final applicationData = applicationDoc.data() ?? <String, dynamic>{};
      final resume = applicationData['resume'] as Map<String, dynamic>? ?? <String, dynamic>{};

      // Only use application data if seeker profile data is not available
      details['name'] = (resume['name'] ?? details['name'] ?? '').toString();
      details['email'] = (resume['email'] ?? details['email'] ?? '').toString();
      details['mobileNumber'] = (resume['mobileNumber'] ?? details['mobileNumber'] ?? '').toString();
      details['education'] = (details['education'] ?? resume['education'] ?? '').toString();
      details['experience'] = (details['experience'] ?? resume['experience'] ?? '').toString();
      details['specialization'] = (details['specialization'] ?? resume['specialization'] ?? '').toString();
      details['currentCompany'] = (details['currentCompany'] ?? resume['currentCompany'] ?? '').toString();
      details['currentCtc'] = (details['currentCtc'] ?? resume['currentCtc'] ?? '').toString();
      details['expectedCtc'] = (details['expectedCtc'] ?? resume['expectedCtc'] ?? '').toString();
      details['resumeUrl'] = (details['resumeUrl'] ?? resume['cvUrl'] ?? '').toString();
      details['photoUrl'] = (details['photoUrl'] ?? resume['photoUrl'] ?? resume['profilePhotoUrl'] ?? '').toString();
      details['jobTitle'] = (applicationData['jobTitle'] ?? details['jobTitle'] ?? '').toString();
      details['company'] = (applicationData['company'] ?? details['company'] ?? '').toString();

      // Use application skills only if seeker profile skills are not available
      if (details['skills'] == null) {
        final resumeSkills = resume['skills'];
        if (resumeSkills != null) {
          details['skills'] = resumeSkills;
        }
      }
    }

    return details;
  }

  Widget _buildOnboardingDetailsCard(BuildContext context, Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    Widget row(String label, dynamic value) {
      final text = _displayValue(value);
      if (text == 'N/A') return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.sp, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    Widget chips(String label, List<dynamic>? values) {
      final list = values
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: list
                  .map(
                    (t) => Chip(
                      label: Text(t, style: TextStyle(fontSize: 11.sp)),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide(color: Colors.teal.shade100),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    }

    final educationDetails = data['educationDetails'];
    final previousExps = data['previousExperiences'];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(top: 10.h),
          title: Text(
            'Complete Profile Details',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            'Full profile information including onboarding details',
            style: TextStyle(fontSize: 11.sp, color: Colors.blueGrey.shade500),
          ),
          children: [
            row('Current Status', data['currentStatus']),
            row('Job Title', data['jobTitle']),
            row('Industry', data['industry']),
            row('Current Company', data['currentCompany']),
            row('Employment Type', data['employmentType']),
            row('Total Experience (years)', data['totalExperienceYears']),
            row('Current Job Start', data['currentJobStartDate']),
            row('Current Job End', data['currentJobEndDate']),
            row('Previous Companies', data['previousCompanies']),
            row('Achievements', data['achievements']),
            row('Projects', data['projects']),
            row('Internships', data['internships']),
            row('Soft Skills', data['softSkills']),
            row('GitHub URL', data['githubUrl']),
            row('Portfolio URL', data['portfolioUrl']),
            row('Resume URL', data['resumeUrl']),
            chips('Skills', (data['skills'] as List?)?.cast<dynamic>()),
            if (educationDetails is Map) ...[
              SizedBox(height: 6.h),
              Text(
                'Education Details',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4.h),
              row(
                '10th - Passing Year',
                (educationDetails['tenth'] as Map?)?['passingYear'],
              ),
              row('10th - Score', (educationDetails['tenth'] as Map?)?['score']),
              row(
                '10th - Score Type',
                (educationDetails['tenth'] as Map?)?['scoreType'],
              ),
              row('After 10th', educationDetails['afterTenth']),
              row(
                '12th - Stream',
                (educationDetails['twelfth'] as Map?)?['stream'],
              ),
              row(
                '12th - Stream Other',
                (educationDetails['twelfth'] as Map?)?['streamOther'],
              ),
              row(
                '12th - Passing Year',
                (educationDetails['twelfth'] as Map?)?['passingYear'],
              ),
              row(
                '12th - Score',
                (educationDetails['twelfth'] as Map?)?['score'],
              ),
              row(
                '12th - Score Type',
                (educationDetails['twelfth'] as Map?)?['scoreType'],
              ),
              row('After 12th', educationDetails['afterTwelfth']),
              row(
                'Diploma - Branch',
                (educationDetails['diploma'] as Map?)?['branch'],
              ),
              row(
                'Diploma - University',
                (educationDetails['diploma'] as Map?)?['university'],
              ),
              row(
                'Diploma - Start Year',
                (educationDetails['diploma'] as Map?)?['startYear'],
              ),
              row(
                'Diploma - End Year',
                (educationDetails['diploma'] as Map?)?['endYear'],
              ),
              row(
                'Diploma - Score',
                (educationDetails['diploma'] as Map?)?['score'],
              ),
              row(
                'Diploma - Score Type',
                (educationDetails['diploma'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation After Diploma',
                educationDetails['graduationAfterDiploma'],
              ),
              row(
                'Graduation - Degree',
                (educationDetails['graduation'] as Map?)?['degree'],
              ),
              row(
                'Graduation - Major',
                (educationDetails['graduation'] as Map?)?['major'],
              ),
              row(
                'Graduation - University',
                (educationDetails['graduation'] as Map?)?['university'],
              ),
              row(
                'Graduation - Start Year',
                (educationDetails['graduation'] as Map?)?['startYear'],
              ),
              row(
                'Graduation - End Year',
                (educationDetails['graduation'] as Map?)?['endYear'],
              ),
              row(
                'Graduation - Score',
                (educationDetails['graduation'] as Map?)?['score'],
              ),
              row(
                'Graduation - Score Type',
                (educationDetails['graduation'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation - Currently Studying',
                (educationDetails['graduation'] as Map?)?['currentlyStudying'],
              ),
              // Post-Graduation details
              if (educationDetails['postGraduation'] is Map) ...[
                SizedBox(height: 6.h),
                Text(
                  'Post-Graduation',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                row(
                  'Post-Graduation - Degree',
                  (educationDetails['postGraduation'] as Map?)?['degree'],
                ),
                row(
                  'Post-Graduation - Major',
                  (educationDetails['postGraduation'] as Map?)?['major'],
                ),
                row(
                  'Post-Graduation - University',
                  (educationDetails['postGraduation'] as Map?)?['university'],
                ),
                row(
                  'Post-Graduation - Start Year',
                  (educationDetails['postGraduation'] as Map?)?['startYear'],
                ),
                row(
                  'Post-Graduation - End Year',
                  (educationDetails['postGraduation'] as Map?)?['endYear'],
                ),
                row(
                  'Post-Graduation - Currently Studying',
                  (educationDetails['postGraduation'] as Map?)?['currentlyStudying'],
                ),
              ],
            ],
            if (previousExps is List && previousExps.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                'Previous Experiences',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4.h),
              ...previousExps.take(10).whereType<Map>().map((e) {
                final company = e['companyName'] ?? e['company'] ?? '';
                final title = e['jobTitle'] ?? e['role'] ?? '';
                final from = e['startDate'] ?? e['from'] ?? '';
                final to = e['endDate'] ?? e['to'] ?? '';
                final line =
                    '${_displayValue(company)} • ${_displayValue(title)} • ${_displayValue(from)} - ${_displayValue(to)}';
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Text(
                    line,
                    style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                  ),
                );
              }),
              if (previousExps.length > 10)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    'Showing first 10 experiences',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayValue(dynamic v) {
    if (v == null) return 'N/A';
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? 'N/A' : t;
    }
    if (v is num || v is bool) return v.toString();
    if (v is Timestamp) return v.toDate().toIso8601String();
    return v.toString();
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
                _detailTile(Icons.location_city_outlined, 'City', data['city']?.toString() ?? ''),
                _detailTile(Icons.school_outlined, 'Education', data['education']?.toString() ?? ''),
                _detailTile(Icons.work_outline, 'Experience', data['experience']?.toString() ?? ''),
                _detailTile(Icons.category_outlined, 'Specialization', data['specialization']?.toString() ?? ''),
                _detailTile(Icons.handyman_outlined, 'Skills', _stringList(data['skills'])),
                _detailTile(Icons.business_outlined, 'Current Company', data['currentCompany']?.toString() ?? ''),
                _detailTile(Icons.currency_rupee_outlined, 'Current CTC', data['currentCtc']?.toString() ?? ''),
                _detailTile(Icons.currency_rupee, 'Expected CTC', data['expectedCtc']?.toString() ?? ''),
                _detailTile(Icons.link_outlined, 'LinkedIn URL', data['linkedinUrl']?.toString() ?? ''),
                _detailTile(Icons.description_outlined, 'Resume URL', data['resumeUrl']?.toString() ?? ''),
                _detailTile(Icons.work_history_outlined, 'Applied Job', data['jobTitle']?.toString() ?? ''),
                _detailTile(Icons.apartment_outlined, 'Company', data['company']?.toString() ?? ''),
                _buildOnboardingDetailsCard(context, data),
              ],
            ),
          );
        },
      ),
    );
  }
}
