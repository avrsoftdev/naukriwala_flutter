# Unread Message Badge - Testing Guide

## Quick Start Testing

### Prerequisites
- App is running on device/emulator
- You have at least 2 test accounts
- Firebase Firestore is accessible

## Test Scenarios

### Test 1: Badge Display on App Launch

**Steps:**
1. Make sure you have unread messages from multiple chats
2. Restart the app
3. Go to dashboard/main screen where the message icon is visible

**Expected Result:**
- Badge appears on message icon
- Badge displays total unread count (sum of all chats)
- If 2 chats with 2 unreads each → shows "4"

---

### Test 2: Badge Disappears When All Read

**Steps:**
1. Note current badge count (e.g., 4)
2. Tap message icon to go to chat list
3. Open each chat
4. Verify each chat's messages are marked as read

**Expected Result:**
- As you open chats, badge count decreases
- When all unreads are marked, badge disappears completely
- Badge animation/update should be smooth and immediate

---

### Test 3: Opening One Chat Doesn't Mark Another as Read

**Steps:**
1. Have unread messages in Chat A (2 unreads) and Chat B (3 unreads)
2. Badge shows "5"
3. Open and read Chat A
4. Close Chat A without opening Chat B

**Expected Result:**
- Badge updates from "5" → "3" (Chat A unreads removed)
- Chat B's unreads still show in badge
- When you open Chat B later, badge goes from "3" → "0"

---

### Test 4: New Messages While Viewing Chat

**Steps:**
1. Open Chat A with some unread messages
2. Verify they get marked as read (badge updates)
3. Have another user send a message to Chat A while you're viewing it
4. Stay in Chat A and watch the status

**Expected Result:**
- New message arrives in Chat A
- Badge count does NOT increase (you're viewing the active chat)
- When you close Chat A (without opening it again), badge stays at 0
- If you go back to dashboard after message, badge still 0 (new message auto-marked)

---

### Test 5: Multiple Sequential Opens

**Steps:**
1. Start with badge showing "5" (Chat A: 2, Chat B: 3)
2. Open Chat A → Badge → "3"
3. Close Chat A, open Chat B → Badge → "0"
4. Close Chat B, go back to dashboard
5. Badge should stay at "0"

**Expected Result:**
- Each chat marked as read when opened
- Badge decreases appropriately
- Final state shows "0" unread

---

### Test 6: Over 99 Unreads

**Steps:**
1. Manually create 150+ unread messages in Firestore across chats
2. Restart app

**Expected Result:**
- Badge displays "99+" instead of full number
- No overflow or UI issues

---

### Test 7: Receiving Message While App in Background

**Steps:**
1. Have app running with some unreads
2. Send a message through another user/account
3. FCM notification should appear in notification center

**Expected Result:**
- When you tap notification or open app
- New message is visible in chat
- Badge updates if needed
- No duplicate counts or stale data

---

### Test 8: Toggle Between Chats Rapidly

**Steps:**
1. Start with Messages: Chat A (2), Chat B (3), Chat C (1)
2. Badge shows "6"
3. Rapidly open/close Chat A, Chat B, Chat C
4. Monitor badge updates

**Expected Result:**
- Badge updates smoothly
- No jumpy or unexpected numbers
- Final state is consistent
- No crashes or errors

---

### Test 9: Delete Unread Messages

**Steps:**
1. Badge shows "4"
2. Manually delete unread messages from Firestore
3. Watch app

**Expected Result:**
- Badge updates within a few seconds
- Badge count decreases appropriately
- If all deleted, badge disappears

---

### Test 10: Mark as Read via Chat List

**Steps:**
1. In chat list, see multiple conversations with unread messages
2. Open each one

**Expected Result:**
- Each chat opened → unread messages marked as read
- Badge decreases with each chat opened
- After opening all, badge shows "0"

---

## Debug Logging

The implementation includes debug logging. Check Dart console for:

```
[ChatIconWithBadge] rebuild: totalUnread=5
[MessageStateService] Updated unread counts: total=5, perChat={chat1: 2, chat2: 3}
[MessageStateService] Active chat changed to: chat1
[ChatScreen] Marked messages as read for chat: chat1
```

### View Logs in Flutter

```bash
# Run with logging enabled
flutter run -v

# Filter for specific tag
flutter logs | grep "MessageStateService"
```

---

## Common Issues & Solutions

### Issue: Badge not updating

**Check:**
- Is `MessageStateProvider` wrapping the app in `main.dart`? ✓
- Are you using `ListenableBuilder` or rebuilding on `messageStateService` changes? ✓

**Fix:** Rebuild the app with `flutter clean && flutter pub get && flutter run`

---

### Issue: Badge shows wrong count

**Check:**
- Are Firestore messages have correct `recipientId`?
- Are messages status being updated to 'read'?
- Check logs for the actual Firestore snapshot

**Debug:**
```dart
// In message_state_service.dart, add before notifyListeners()
print('Unread map: $_unreadCountPerChat');
```

---

### Issue: Badge doesn't disappear for 0 unreads

**Check:**
- Message in `chat_icon_with_badge.dart`:
```dart
if (totalUnread > 0)  // This should hide badge when 0
```

**Fix:** Ensure this condition is present in the widget build method

---

### Issue: Unread badges in chat list not updating

**Hint:** You can optionally add `ChatUnreadBadge` to each list item:

```dart
ChatUnreadBadge(chatId: chatId, compact: true)
```

This is not required but helpful for UX.

---

## Performance Verification

### Memory Test
1. App running for 10+ minutes
2. Open/close multiple chats repeatedly
3. Check device memory usage in Android Studio/Xcode
4. Should not leak memory (stable usage)

### CPU Test
1. Monitor CPU in Android Profiler/Xcode
2. Should be low when idle
3. Spikes only during Firestore updates

### Firestore Query Efficiency
- **Listener created**: 1 (global)
- **Indexes needed**: None (using status != 'read' with recipientId)
- **Documents scanned**: Only unread messages

---

## Sign Off Checklist

After testing, verify:

- [ ] Badge displays correct unread count on app launch
- [ ] Badge updates immediately when chat opened
- [ ] Badge hides when unread count = 0
- [ ] Multiple chats sum correctly (e.g., 2+3=5)
- [ ] No memory leaks after extended use
- [ ] No crashes or errors in console
- [ ] Works with FCM notifications
- [ ] Works on both Android and iOS (if available)
- [ ] Badge handles "99+" case correctly
- [ ] Switching between chats works smoothly
