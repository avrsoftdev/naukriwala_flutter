# Unread Message Badge System - Visual Diagrams

## System Architecture Diagram

```
┌────────────────────────────────────────────────────┐
│                    Flutter App                     │
│                   (main.dart)                      │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │ MessageStateProvider   │
        │   (Initialize state    │
        │    track lifecycle)    │
        └───────────┬────────────┘
                    │
                    ▼
        ┌───────────────────────────────────────┐
        │   MessageStateService (Singleton)     │
        │   ├─ Firestore Listener               │
        │   ├─ _unreadCountPerChat (Map)        │
        │   ├─ _currentActiveChatId             │
        │   └─ notifyListeners()                │
        └───────────┬───────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
   ┌─────────────┐      ┌───────────────┐
   │Firestore    │      │UI Widgets     │
   │Listener     │      │               │
   │             │      ├─ ChatIcon     │
   │• Messages   │      │  WithBadge    │
   │• Chats      │      ├─ ChatUnread   │
   │• Status     │      │  Badge        │
   │• Timestamp  │      └───────────────┘
   └─────────────┘
```

## Data Flow Diagram

```
App Startup
    │
    ▼
┌──────────────────────────────────┐
│ MessageStateProvider.initState() │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ initializeUnreadTracking()               │
│ • Get current user ID                    │
│ • Create Firestore listener              │
│ • Start monitoring collectionGroup        │
└──────────────┬───────────────────────────┘
               │
               ▼
Firestore collectionGroup('Chats')
    .where('recipientId' == userId)
    .where('status' != 'read')
    .snapshots()
       │
       ▼
┌──────────────────────────────────────┐
│ _updateUnreadCountsFromSnapshot      │
│ • Parse each document                │
│ • Calculate chat ID                  │
│ • Count unread per chat              │
│ • Update _unreadCountPerChat map     │
└──────────────┬──────────────────────┘
               │
               ▼
        notifyListeners()
               │
               ▼
    ┌──────────────────┐
    │ All Listeners    │
    │ get rebuilt      │
    └──────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ ChatIconWithBadge    │
    │ • Reads totalUnread  │
    │ • Updates badge UI   │
    └──────────────────────┘
```

## User Interaction Flow

```
User Opens App
    │
    ▼
Badge shows "5" (Chat A: 2, Chat B: 3)
    │
    ├─────────────────┬─────────────────┐
    ▼                 ▼                   ▼
 Chat List        Chat List          Chat List
 [Chat A]         [Chat B]           [Chat C]
 2 unread         3 unread           0 unread
    │                 │                   │
    ▼                 ▼                   ▼
User taps         User taps          User taps
Chat A            Chat B             Chat C
    │                 │                   │
    ▼                 ▼                   ▼
ChatScreen      ChatScreen          ChatScreen
.initState() sets .initState() sets .initState() sets
activeChat=A    activeChat=B       activeChat=C
    │                 │                   │
    ▼                 ▼                   ▼
_markAsRead()    _markAsRead()      _markAsRead()
updates to       updates to        updates to
status='read'    status='read'     status='read'
    │                 │                   │
    ▼                 ▼                   ▼
Firestore       Firestore         Firestore
batch update    batch update      batch update
committed       committed         committed
    │                 │                   │
    ▼                 ▼                   ▼
Listener         Listener          Listener
detects          detects           detects
changes          changes           changes
    │                 │                   │
    ▼                 ▼                   ▼
Update count     Update count      Update count
Chat A: 0        Chat B: 0         Chat C: 0
    │                 │                   │
    ▼                 ▼                   ▼
Badge: 5 → 3     Badge: 3 → 0      Badge: 0 → 0
(Chat B unread)  (No unread left)   (Already 0)
```

## Message Lifecycle

```
Sender sends message
        │
        ▼
Message stored in Firestore
{
  senderId: "user1",
  recipientId: "user2",
  message: "Hello",
  status: "sent",           ◄── KEY: Not read yet
  timestamp: "2025-02-18..."
}
        │
        ▼
┌─────────────────────────────────┐
│ Firestore Listener detects      │
│ status='sent' (not 'read')       │
└────────────┬────────────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
Is Chat A      Is Chat B
active?        active?
(user viewing)  (user not viewing)
    │               │
    ▼               ▼
  NO → Don't      YES → Count it!
       count it!   Add to unread map
                   notifyListeners()
                        │
                        ▼
                   Badge updates
                   e.g., 3 → 4
```

## State Transitions

```
┌─────────────────────────────────────────────────────┐
│      MessageStateService State Machine              │
└─────────────────────────────────────────────────────┘

Initial State
┌─────────────────┐
│ Uninitialized   │
│ No listeners    │
│ Empty maps      │
└────────┬────────┘
         │ initializeUnreadTracking()
         ▼
┌─────────────────────────────────────────┐
│ Listening                               │
│ • Firestore listener active             │
│ • Monitoring unread messages            │
│ • notifyListeners() on changes          │
│ • activeChat = null                     │
└────────┬────────────────────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
User opens  No unread  
chat(A)     messages
    │           │
    ▼           ▼
┌──────────┐ ┌──────────┐
│ Active   │ │ Empty    │
│ Chat: A  │ │ Badge    │
│ Count: 0 │ │ Hidden   │
└──────────┘ └──────────┘
    │
    │ User switches
    │ to Chat B
    │ (has unreads)
    ▼
┌──────────────┐
│ Active       │
│ Chat: B      │
│ Badge: "3"   │
└──────────────┘
    │
    │ User closes app
    │ or navigates away
    ▼
┌──────────────┐
│ Active       │
│ Chat: null   │
│ Badge: "3"   │
└──────────────┘
```

## Per-Chat Unread Tracking

```
Incoming Messages:
┌──────────────────────────────────────┐
│ Chat A: M1(sent), M2(sent), M3(sent) │
│ Chat B: M1(sent), M2(sent)           │
│ Chat C: M1(sent)                     │
└──────────────────────────────────────┘

Firestore Listener Processes:
    │
    ├─ Chat A: 3 unread
    ├─ Chat B: 2 unread
    └─ Chat C: 1 unread
    
Service State:
_unreadCountPerChat = {
  'user1_user2': 3,  // Chat A
  'user1_user3': 2,  // Chat B
  'user1_user4': 1   // Chat C
}

totalUnreadCount = 3 + 2 + 1 = 6

Badge Display: "6"

User opens Chat A:
    ├─ activeChat = 'user1_user2'
    ├─ _markAsRead() called
    ├─ All Chat A messages → status='read'
    └─ Listener detects change

Update State:
_unreadCountPerChat = {
  'user1_user2': 0,   // Chat A - MARKED READ
  'user1_user3': 2,   // Chat B - unchanged
  'user1_user4': 1    // Chat C - unchanged
}

totalUnreadCount = 0 + 2 + 1 = 3

Badge Display: "3" (updated from "6")
```

## Reactive Update Pipeline

```
                    ┌─────────────────┐
                    │  Firestore      │
                    │  Database       │
                    └────────┬────────┘
                             │ Change
                             │ detected
                             ▼
                    ┌────────────────────┐
                    │ Listener           │
                    │ emits QuerySnapshot│
                    └────────┬───────────┘
                             │
                             ▼
                    ┌────────────────────────┐
                    │ _updateUnreadCounts    │
                    │ FromSnapshot()         │
                    └────────┬───────────────┘
                             │
                             ▼
                    ┌────────────────────────┐
                    │ Update                 │
                    │ _unreadCountPerChat    │
                    │ Map                    │
                    └────────┬───────────────┘
                             │
                             ▼
                    ┌────────────────────────┐
                    │ notifyListeners()      │
                    │ called                 │
                    └────────┬───────────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ChatIcon      │  │ChatUnread    │  │Custom        │
    │WithBadge     │  │Badge         │  │Listeners     │
    │rebuild()     │  │rebuild()     │  │rebuild()     │
    └──────┬───────┘  └───────┬──────┘  └──────┬───────┘
           │                  │                │
           ▼                  ▼                ▼
    ┌─────────────────────────────────────────────┐
    │            UI Updated                       │
    │                                             │
    │  Badge shows new                            │
    │  unread count                               │
    │  in real-time!                              │
    └─────────────────────────────────────────────┘
```

## Event Timeline Example

```
Timeline for "Chat A opens and is marked as read"

T0 ──────────────────┐
                     │
T1 User taps Chat A  ├─ User action
                     │
T2 ChatScreen        ├─ initState() called
   initializes       ├─ setActiveChatId('chat_A')
   itself            │
                     │
T3 _initialize()     ├─ Setup begins
   calls             │
   _markAsRead()     │
                     │
T4 Firestore         ├─ Batch update sent
   batch.update()    ├─ Messages status → 'read'
   batch.commit()    │
                     │
T5 Firestore         ├─ Listener receives
   listener          │  snapshot
   triggered         │  (Chat A messages now
                     │   status='read')
                     │
T6 _updateUnread     ├─ Parse snapshot
   CountsFromSnap()  ├─ Remove Chat A items
                     │  (status='read' filtered)
                     │
T7 Update            ├─ _unreadCountPerChat
   _unreadCountPerChat├─  ['chat_A'] = 0
                     │  (previously 2)
                     │
T8 Calculate         ├─ totalUnreadCount
   total             │  = 0 + 3 = 3
                     │  (previously 5)
                     │
T9 notifyListeners() ├─ Signal change
                     │
T10 ChatIconWithBadge├─ rebuild()
    rebuilds         ├─ Read totalUnreadCount
                     │
T11 Badge updates    ├─ Display changes
    on screen        │  from "5" → "3"
                     │
                     ▼ Animation completes
```

## Error Handling Flow

```
┌─────────────────────┐
│ Firestore Error     │
│ (network, etc.)     │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────────────┐
│ Listener.onError() callback  │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ Log error with dev.log()     │
│ "Error in unread tracking    │
│  stream: [error details]"    │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ Continue listening           │
│ Try to recover when network  │
│ returns                      │
└──────────────────────────────┘

No UI crash!
Badge keeps previous state
until Firestore recovers
```

---

All diagrams show the complete flow of data through the unread message badge system. The key insight is that everything flows through the centralized `MessageStateService`, which acts as a single source of truth for unread message state.

