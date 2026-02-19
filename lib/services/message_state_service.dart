import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as dev;

/// Service to manage unread message state globally
/// Maintains per-chat unread counts and derives global unread count
class MessageStateService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Map of chatId -> unread count
  final Map<String, int> _unreadCountPerChat = {};
  
  // Track which chat is currently open (if any)
  String? _currentActiveChatId;

  // Stream subscription references for cleanup
  final Map<String, StreamSubscription> _streamSubscriptions = {};
  
  // Track if we're already listening to auth state
  bool _authListenerActive = false;
  
  // Track if tracking is initialized
  bool _trackingInitialized = false;

  /// Get total unread count across all chats
  int get totalUnreadCount {
    return _unreadCountPerChat.values.fold(0, (previous, element) => previous + element);
  }

  /// Get unread count for a specific chat
  int getUnreadCountForChat(String chatId) {
    return _unreadCountPerChat[chatId] ?? 0;
  }

  /// Set the currently active chat (opened by user)
  void setActiveChatId(String? chatId) {
    if (_currentActiveChatId != chatId) {
      _currentActiveChatId = chatId;
      dev.log('Active chat changed to: $chatId', name: 'MessageStateService');
      notifyListeners();
    }
  }

  /// Get the currently active chat
  String? getActiveChatId() => _currentActiveChatId;

  /// Start listening to auth state changes and initialize when user logs in
  void setupAuthListener() {
    if (_authListenerActive) return;
    _authListenerActive = true;
    
    dev.log('Setting up auth state listener', name: 'MessageStateService');
    
    // First, check if user is already logged in
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid.isNotEmpty) {
      dev.log('User already logged in: ${currentUser.uid}', name: 'MessageStateService');
      _initializeTrackingForUser(currentUser.uid);
    }
    
    // Then listen for future auth state changes
    _streamSubscriptions['auth_listener'] = _auth.authStateChanges().listen(
      (user) {
        if (user != null && user.uid.isNotEmpty) {
          // User logged in
          dev.log('Auth state changed: user logged in (${user.uid})', name: 'MessageStateService');
          _initializeTrackingForUser(user.uid);
        } else {
          // User logged out
          dev.log('Auth state changed: user logged out', name: 'MessageStateService');
          _cleanupTracking();
        }
      },
      onError: (error) {
        dev.log('Error in auth listener: $error', name: 'MessageStateService');
      },
    );
  }
  
  /// Initialize unread message tracking for a specific user
  void _initializeTrackingForUser(String uid) {
    if (_trackingInitialized && _auth.currentUser?.uid == uid) {
      dev.log('Tracking already initialized for user $uid', name: 'MessageStateService');
      return;
    }

    dev.log('Initializing unread tracking for user: $uid', name: 'MessageStateService');
    _trackingInitialized = true;

    // Cancel existing global listener if any
    _streamSubscriptions['global_unread']?.cancel();

    // Listen to all chats where this user is the recipient with 'sent' status
    final unreadStream = _firestore
        .collectionGroup('Chats')
        .where('recipientId', isEqualTo: uid)
        .where('status', isNotEqualTo: 'read')
        .snapshots();

    _streamSubscriptions['global_unread'] = unreadStream.listen(
      (snapshot) {
        _updateUnreadCountsFromSnapshot(snapshot, uid);
      },
      onError: (error) {
        dev.log('Error in unread tracking stream: $error', name: 'MessageStateService');
      },
    );
    
    // Notify listeners that tracking is now initialized
    notifyListeners();
  }

  /// Update unread counts based on a snapshot from Firestore
  /// Groups messages by chatId and counts unreads per chat
  void _updateUnreadCountsFromSnapshot(QuerySnapshot snapshot, String uid) {
    final newUnreadMap = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Extract chat metadata
      final senderId = data['senderId'] as String? ?? '';
      final recipientId = data['recipientId'] as String? ?? '';
      final messageStatus = data['status'] as String? ?? 'sent';
      
      // Only count messages that are not yet read and recipient is current user
      if (messageStatus != 'read' && recipientId == uid) {
        // Build a deterministic chat ID from sender and recipient
        final participants = [senderId, recipientId]..sort();
        final chatId = '${participants[0]}_${participants[1]}';

        if (chatId.trim().isNotEmpty) {
          newUnreadMap[chatId] = (newUnreadMap[chatId] ?? 0) + 1;
        }
      }
    }

    // Update internal state
    _unreadCountPerChat.clear();
    _unreadCountPerChat.addAll(newUnreadMap);

    dev.log(
      'Updated unread counts: total=$totalUnreadCount, perChat=$_unreadCountPerChat',
      name: 'MessageStateService',
    );

    // Notify listeners of the change
    notifyListeners();
  }

  /// Manually reset unread count for a specific chat (e.g., when user opens it)
  /// In practice, this is handled by Firebase Firestore bulk update in chat_screen.dart
  /// But we provide this for UI synchronization
  void resetUnreadCountForChat(String chatId) {
    if (_unreadCountPerChat.containsKey(chatId)) {
      _unreadCountPerChat[chatId] = 0;
      dev.log('Reset unread count for chat: $chatId', name: 'MessageStateService');
      notifyListeners();
    }
  }

  /// Listen to new messages in a specific chat
  /// Only increments unread count if the chat is not currently active
  Stream<int> listenToChatUnreadCount(String chatId, String userId) {
    return _firestore
        .collection('Messages')
        .doc(chatId)
        .collection('Chats')
        .where('recipientId', isEqualTo: userId)
        .where('status', isNotEqualTo: 'read')
        .snapshots()
        .map((snapshot) {
      final count = snapshot.docs.length;
      
      // Only update global state if this chat is not the currently active one
      if (_currentActiveChatId != chatId) {
        _unreadCountPerChat[chatId] = count;
        dev.log(
          'Updated unread for chat $chatId: $count (active: $_currentActiveChatId)',
          name: 'MessageStateService',
        );
        notifyListeners();
      }
      
      return count;
    });
  }

  /// Check if should increment unread count for new message
  /// Returns true if chat is NOT currently active
  bool shouldCountMessageAsUnread(String chatId) {
    return _currentActiveChatId != chatId;
  }
  
  /// Cleanup tracking state (called on logout)
  void _cleanupTracking() {
    _unreadCountPerChat.clear();
    _trackingInitialized = false;
    _streamSubscriptions['global_unread']?.cancel();
    _streamSubscriptions.remove('global_unread');
    dev.log('Cleaned up unread tracking state', name: 'MessageStateService');
    notifyListeners();
  }
  
  /// Public method to initialize tracking (for backward compatibility)
  void initializeUnreadTracking() {
    setupAuthListener();
  }

  /// Cleanup: cancel all stream subscriptions
  @override
  void dispose() {
    for (final subscription in _streamSubscriptions.values) {
      subscription.cancel();
    }
    _streamSubscriptions.clear();
    _authListenerActive = false;
    _trackingInitialized = false;
    super.dispose();
  }
}