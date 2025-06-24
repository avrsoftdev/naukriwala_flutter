import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  final List<Map<String, String>> notifications;
  final bool isRecruiter;

  const NotificationsScreen({
    Key? key,
    required this.notifications,
    required this.isRecruiter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final title = notification['title'] ?? 'Notification';
                final subtitle = isRecruiter
                    ? 'Seeker: ${notification['seekerName'] ?? "N/A"}  •  Job: ${notification['jobTitle'] ?? "-"}'
                    : 'Recruiter: ${notification['recruiterName'] ?? "N/A"}  •  Job: ${notification['jobTitle'] ?? "-"}';

                return ListTile(
                  leading: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subtitle),
                );
              },
            ),
    );
  }
}
