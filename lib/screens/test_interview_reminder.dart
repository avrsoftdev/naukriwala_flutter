import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/interview_reminder_service.dart';
import '../services/auth_service.dart';

class InterviewReminderTestScreen extends StatefulWidget {
  const InterviewReminderTestScreen({super.key});

  @override
  State<InterviewReminderTestScreen> createState() => _InterviewReminderTestScreenState();
}

class _InterviewReminderTestScreenState extends State<InterviewReminderTestScreen> {
  final InterviewReminderService _reminderService = InterviewReminderService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _testResult = '';

  Future<void> _testScheduleReminder() async {
    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in. Please login first.';
          _isLoading = false;
        });
        return;
      }

      // Schedule a test interview for 2 minutes from now
      final testInterviewTime = DateTime.now().add(const Duration(minutes: 2));
      final reminderTime = testInterviewTime.subtract(const Duration(hours: 2));

      await _reminderService.scheduleInterviewReminder(
        interviewId: 'test_interview_${DateTime.now().millisecondsSinceEpoch}',
        jobTitle: 'Test Job Position',
        companyName: 'Test Company',
        interviewTime: testInterviewTime,
        seekerId: user.uid,
        recruiterId: user.uid, // Using same user for test
      );

      setState(() {
        _testResult = '✅ Test interview scheduled!\n'
            'Interview Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(testInterviewTime)}\n'
            'Reminder Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(reminderTime)}\n'
            'Note: Since reminder time is in the past, immediate notification will be sent.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testImmediateReminder() async {
    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in. Please login first.';
          _isLoading = false;
        });
        return;
      }

      // Test interview confirmation notification (creates both confirmation and schedules 2-hour reminder)
      await _reminderService.createInterviewConfirmationNotification(
        jobTitle: 'Test Job Position',
        companyName: 'Test Company',
        interviewTime: DateTime.now().add(const Duration(hours: 2)),
        seekerId: user.uid,
        recruiterId: user.uid,
        interviewId: 'test_interview_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _testResult = '✅ Interview confirmation notification created!\n'
            '• Confirmation notification sent to notification screen\n'
            '• 2-hour reminder scheduled\n'
            '• Check your notification screen for confirmation message';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPendingNotifications() async {
    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      final pendingNotifications = await _reminderService.getPendingNotifications();
      
      setState(() {
        if (pendingNotifications.isEmpty) {
          _testResult = '📭 No pending notifications found.';
        } else {
          _testResult = '📬 Pending notifications (${pendingNotifications.length}):\n';
          for (final notification in pendingNotifications) {
            _testResult += '- ${notification.title}\n';
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Reminder Test'),
        backgroundColor: const Color(0xFF0A8F7B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Interview Reminder Service',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A8F7B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testScheduleReminder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A8F7B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Schedule Test Interview'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testImmediateReminder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Interview Confirmation'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _checkPendingNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Check Pending Notifications'),
            ),
            
            const SizedBox(height: 20),
            
            if (_testResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _testResult,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            
            const Spacer(),
            
            const Text(
              'Note: This is a test screen for development purposes only.\n'
              'It helps verify that interview confirmation and reminder services are working correctly.\n'
              '• Test Interview Confirmation: Creates confirmation notification and schedules 2-hour reminder\n'
              '• Check Pending: Shows scheduled local notifications',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
