# Unread Message Badge Implementation Guide

## Overview

This implementation provides a reactive, real-time unread message count badge on the message icon. The system automatically:

1. **Tracks unread counts** - Maintains per-chat and global unread message counts
2. **Updates reactively** - The badge updates immediately when messages are marked as read
3. **Prevents false counts** - Does not increment unread count for messages in currently open chats
4. **Handles cleanup** - Automatically resets counts when chats are opened

## Architecture

### State Management Hierarchy

```
MessageStateService (Singleton)
├── Global unread count (derived)
├── Per-chat unread counts (Map<chatId, count>)
├── Current active chat tracking
└── Stream subscriptions for Firestore updates

MessageStateProvider (App Wrapper)
├── Initializes MessageStateService
├── Provides ListenableBuilder for reactive updates
└── Cleans up on app lifecycle

ChatIconWithBadge (UI Widget)
├── Listens to MessageStateService
├── Displays dynamic badge with total unread count
└── Hides when unread count is 0

ChatUnreadBadge (Optional per-chat widget)
├── Shows per-chat unread count
├── Compact or standard size variants
└── Syncs with global state
```

## Components Created

### 1. **MessageStateService** (`lib/services/message_state_service.dart`)

Core state management service that:

- Extends `ChangeNotifier` for reactive updates
- Maintains `_unreadCountPerChat: Map<String, int>` - per-chat unread counts
- Maintains `_currentActiveChatId: String?` - currently open chat
- Provides `totalUnreadCount` - computed derived state
- Listens to Firestore `collectionGroup('Chats')` with status != 'read' filters
- Groups messages by chat ID and counts unreads per chat

**Key Methods:**
- `initializeUnreadTracking()` - Start listening to unread messages
- `setActiveChatId(String? chatId)` - Mark which chat is currently open
- `resetUnreadCountForChat(String chatId)` - Reset count after marking as read
- `getUnreadCountForChat(String chatId)` - Get per-chat unread count
- `dispose()` - Clean up all Firestore subscriptions

### 2. **MessageStateProvider** (`lib/providers/message_state_provider.dart`)

App-level provider widget that:

- Creates a global singleton `messageStateService`
- Wraps the MaterialApp to initialize state on startup
- Uses `ListenableBuilder` for efficient reactive updates
- Handles cleanup on app disposal

### 3. **ChatIconWithBadge** (`lib/widgets/chat_icon_with_badge.dart`) - UPDATED

Modernized to use the new MessageStateService:

- Replaced Firestore StreamBuilder with `ListenableBuilder` on `messageStateService`
- Much simpler - just displays badge based on `totalUnreadCount`
- Badge displays number or "99+" if > 99 unread messages
- Badge hidden when count is 0

### 4. **ChatUnreadBadge** (`lib/widgets/chat_unread_badge.dart`)

Optional utility widget for showing per-chat unread counts:

- Takes `chatId` parameter to show unread count for specific chat
- Supports compact and standard badge sizes
- Automatically syncs with global state changes

## Integration Points

### In `main.dart`

```dart
class NaukariwalaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MessageStateProvider(
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, child) => MaterialApp(
          // ... rest of app config
          home: const UnifiedScreen(),
        ),
      ),
    );
  }
}
```

### In `chat_screen.dart`

```dart
@override
void initState() {
  super.initState();
  // ... other init code
  
  // Set this chat as active - new messages won't increment unread
  messageStateService.setActiveChatId(widget.chatId);
  
  _initialize();
}

@override
void dispose() {
  // ... other cleanup
  
  // Clear active chat when screen is disposed
  messageStateService.setActiveChatId(null);
  
  super.dispose();
}

Future<void> _markAsRead() async {
  // ... existing Firestore batch update code
  
  // Reset the unread count in the service
  messageStateService.resetUnreadCountForChat(widget.chatId);
  dev.log('Marked messages as read for chat: ${widget.chatId}');
}
```

## How It Works

### Initialization Flow

1. App starts → `MessageStateProvider` initializes
2. `messageStateService.initializeUnreadTracking()` is called
3. Establishes real-time Firestore listener on `collectionGroup('Chats')`
4. Listener filters for messages where:
   - `recipientId` = current user
   - `status` != 'read'
5. Snapshot handler groups messages by chat ID and counts unreads per chat
6. `ListenableBuilder` on `messageStateService` triggers rebuilds on count changes

### When User Opens a Chat

1. `ChatScreen.initState()` calls `messageStateService.setActiveChatId(widget.chatId)`
2. Service tracks that this chat is now active
3. `_initializeChat()` calls `_markAsRead()`
4. `_markAsRead()` updates all messages to status='read' in Firestore batch
5. Firestore listener detects the change and updates `_unreadCountPerChat`
6. `messageStateService.resetUnreadCountForChat(widget.chatId)` sets count to 0
7. `notifyListeners()` triggers rebuilds in `ChatIconWithBadge`
8. Badge updates immediately from (for example) 4 → 2 if one chat had 2 unreads

### When New Message Arrives

1. FCM notification is received (or Firestore listener detects new message)
2. New message has `status='sent'` and `recipientId=currentUser`
3. Firestore listener snapshot includes the new message
4. If `_currentActiveChatId != messageFromChatId`:
   - Message is counted in `_unreadCountPerChat[chatId]`
   - `totalUnreadCount` increases
   - `notifyListeners()` triggers badge update
5. If the chat is currently active (`_currentActiveChatId == chatId`):
   - Message is NOT counted (prevents false counts)
   - Badge remains unchanged until user opens another chat/reopens app

### When User Marks Chat as Read

1. User opens chat → `_markAsRead()` is called
2. All unread messages in that chat are updated to `status='read'` in Firestore
3. Firestore listener receives update event
4. Messages filtering out `status='read'` items automatically
5. New local unread count for that chat = 0
6. `resetUnreadCountForChat(widget.chatId)` ensures state is synced
7. `totalUnreadCount` decreases
8. Badge updates reactively

## State Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  Firestore Listener                         │
│                                                             │
│  collectionGroup('Chats')                                  │
│  .where('recipientId', =, currentUser)                     │
│  .where('status', !=, 'read')                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │  _updateUnreadCounts    │
         │  from Snapshot          │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │  _unreadCountPerChat    │
         │  Map<chatId, count>     │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │  totalUnreadCount       │
         │  (derived property)     │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │  notifyListeners()      │
         │  triggers rebuilds      │
         └──────────┬──────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌──────────────────┐  ┌──────────────────┐
│ChatIconWithBadge │  │ChatUnreadBadge   │
│  displays total  │  │per-chat badges   │
│  in badge        │  │(optional)        │
└──────────────────┘  └──────────────────┘
```

## Usage Examples

### Access global unread count anywhere

```dart
import 'package:naukariwala/providers/message_state_provider.dart';

// Get current total unread count
final count = messageStateService.totalUnreadCount;

// Or listen to changes
ListenableBuilder(
  listenable: messageStateService,
  builder: (context, _) {
    return Text('${messageStateService.totalUnreadCount} unread');
  },
);
```

### Get per-chat unread count

```dart
final chatUnreadCount = messageStateService.getUnreadCountForChat(chatId);
```

### Manually set active chat (done automatically in ChatScreen)

```dart
messageStateService.setActiveChatId(chatId);
// ... later when leaving chat
messageStateService.setActiveChatId(null);
```

## Testing Checklist

- [ ] **App startup**: Badge shows correct total on app launch
- [ ] **Open chat**: Badge count decreases when chat is opened
- [ ] **Mark as read**: Messages marked as read, unread count updates
- [ ] **Multiple chats**: Badge shows sum of all chat unreads (e.g., 4 from 2 chats)
- [ ] **While viewing**: New messages in active chat don't increment count
- [ ] **Switch chats**: Opens Chat A (count 0), Chat B shows count 2
- [ ] **No badge**: Badge hidden when total unread = 0
- [ ] **Large numbers**: Shows "99+" when unread > 99
- [ ] **Message deletion**: If unread deleted, count updates
- [ ] **Background**: Works with FCM notifications

## Performance Considerations

- **Single Firestore listener**: Only one global listener, not per chat
- **Efficient updates**: Only rebuilds widgets listening to `messageStateService`
- **Stream cleanup**: All subscriptions cancelled in `dispose()`
- **No memory leaks**: Service disposed when provider is removed
- **Batch operations**: Mark as read uses Firestore batch for efficiency

## Edge Cases Handled

1. **No user logged in**: Service checks `uid` before operations
2. **Rapid chat switches**: `setActiveChatId()` handles overlapping calls
3. **Stale snapshots**: Filters by status, handles updates correctly
4. **App backgrounding**: Lifecycle observer existing in ChatScreen
5. **Disposed widgets**: All services have proper cleanup
6. **Null safety**: All operations null-safe with `??` operators

## Future Enhancements

1. Add per-chat unread badges in chat list
2. Add unread count to app notification badge (native)
3. Add sound/vibration for unread messages
4. Add "mark all as read" functionality
5. Add filter by unread status in chat list
6. Sync with web/desktop clients
