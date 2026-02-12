// Reusable notification bell with unread count badge
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationBell extends StatelessWidget {
  final bool isRecruiter;
  final VoidCallback? onTap;

  const NotificationBell({this.isRecruiter = false, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications, color: Colors.black87, size: 28),
        onPressed: onTap,
      );
    }

    final collectionPath = isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications';
    final query = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(uid)
        .collection('Notifications')
        .where('to', isEqualTo: uid)
        .where('read', isEqualTo: false);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int unread = 0;
        if (snapshot.hasData) {
          unread = snapshot.data!.docs.length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black87, size: 28),
              onPressed: onTap,
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
