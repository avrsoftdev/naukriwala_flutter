import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyApplicationsScreen extends StatefulWidget {
  final String seekerId; // or use email or uid

  const MyApplicationsScreen({required this.seekerId});

  @override
  _MyApplicationsScreenState createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late final Stream<QuerySnapshot> _applicationsStream;

  @override
  void initState() {
    super.initState();
    _applicationsStream = FirebaseFirestore.instance
        .collection('JobApplications')
        .where('seekerId', isEqualTo: widget.seekerId)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Applications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _applicationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading applications.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('No applications found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final jobTitle = data['jobTitle'] ?? 'N/A';
              final company = data['companyName'] ?? 'Company'; // store company name in application data if possible
              final appliedAt = data['appliedAt'] as Timestamp?;
              final status = data['applicationStatus'] ?? 'Pending';
              final resumeUrl = data['resumeUrl'] ?? '';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(jobTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company: $company'),
                      if (appliedAt != null) Text('Applied on: ${_formatTimestamp(appliedAt)}'),
                      Text('Status: $status'),
                    ],
                  ),
                  trailing: resumeUrl.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.picture_as_pdf),
                          tooltip: 'View Resume',
                          onPressed: () {
                            // open resume URL in browser or PDF viewer
                            // you can use url_launcher package for that
                            _openResume(resumeUrl);
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openResume(String url) async {
    // Use url_launcher package to open URL
    // Add url_launcher to pubspec.yaml
    // import 'package:url_launcher/url_launcher.dart';

    // Uncomment below after adding url_launcher package:
    // if (await canLaunch(url)) {
    //   await launch(url);
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open resume')));
    // }
  }
}
