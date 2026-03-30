# Phase 8 — Matching & Chat

## Goal
Build the Go chat endpoints (send message, get messages, get matches), the Flutter chat list, chat screen with real-time polling, pixel emotes, and match celebration screen. When this phase is complete, matched users can chat with text and pixel emotes.

## Prerequisites
Phases 1–7 complete: `matches` and `chats` tables populated on mutual likes.

---

## 1. Go: Message Model — `models/message.go`

```go
package models

import "time"

type Message struct {
	ID          string    `json:"id"`
	ChatID      string    `json:"chatId"`
	SenderUID   string    `json:"senderUid"`
	Text        string    `json:"text"`
	MessageType string    `json:"messageType"` // "text", "emote"
	CreatedAt   time.Time `json:"createdAt"`
}
```

---

## 2. Go: Chat Handlers — `handlers/chat.go`

```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type ChatHandler struct{}

func (h *ChatHandler) GetMessages(c *gin.Context) {
	uid := c.GetString("uid")
	chatID := c.Param("chatId")

	// Verify user is a participant
	var matchID string
	err := database.DB.QueryRow("SELECT match_id FROM chats WHERE id = $1", chatID).Scan(&matchID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "chat not found"})
		return
	}

	var isParticipant bool
	database.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM matches WHERE id = $1 AND (user1_uid = $2 OR user2_uid = $2)
		)
	`, matchID, uid).Scan(&isParticipant)

	if !isParticipant {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a participant"})
		return
	}

	// Get messages, optionally after a timestamp for polling
	afterParam := c.Query("after") // ISO timestamp string

	var rows interface{ Close() error }
	var queryErr error

	if afterParam != "" {
		rows2, err := database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1 AND created_at > $2
			ORDER BY created_at ASC
		`, chatID, afterParam)
		rows = rows2
		queryErr = err
	} else {
		rows2, err := database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1
			ORDER BY created_at ASC LIMIT 100
		`, chatID)
		rows = rows2
		queryErr = err
	}

	if queryErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	messages := []models.Message{}
	// Type assert to iterate
	if r, ok := rows.(interface {
		Next() bool
		Scan(dest ...interface{}) error
	}); ok {
		for r.Next() {
			var m models.Message
			r.Scan(&m.ID, &m.ChatID, &m.SenderUID, &m.Text, &m.MessageType, &m.CreatedAt)
			messages = append(messages, m)
		}
	}

	c.JSON(http.StatusOK, gin.H{"messages": messages})
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	uid := c.GetString("uid")
	chatID := c.Param("chatId")

	var req struct {
		Text        string `json:"text" binding:"required"`
		MessageType string `json:"messageType"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.MessageType == "" {
		req.MessageType = "text"
	}

	// Verify participation
	var matchID string
	err := database.DB.QueryRow("SELECT match_id FROM chats WHERE id = $1", chatID).Scan(&matchID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "chat not found"})
		return
	}

	var isParticipant bool
	database.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM matches WHERE id = $1 AND (user1_uid = $2 OR user2_uid = $2)
		)
	`, matchID, uid).Scan(&isParticipant)

	if !isParticipant {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a participant"})
		return
	}

	// Insert message
	var msg models.Message
	err = database.DB.QueryRow(`
		INSERT INTO messages (chat_id, sender_uid, text, message_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, chat_id, sender_uid, text, message_type, created_at
	`, chatID, uid, req.Text, req.MessageType).Scan(
		&msg.ID, &msg.ChatID, &msg.SenderUID, &msg.Text, &msg.MessageType, &msg.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "insert failed"})
		return
	}

	// Update chat's last message
	preview := req.Text
	if req.MessageType == "emote" {
		preview = "[emote]"
	}
	database.DB.Exec(`
		UPDATE chats SET last_message = $1, last_message_at = NOW() WHERE id = $2
	`, preview, chatID)

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}
```

---

## 3. Register Chat Routes in `main.go`

Inside the `protected` group:

```go
chatHandler := &handlers.ChatHandler{}

protected.GET("/chats/:chatId/messages", chatHandler.GetMessages)
protected.POST("/chats/:chatId/messages", chatHandler.SendMessage)
```

---

## 4. Flutter: `lib/services/chat_service.dart`

```dart
import '../config/api_client.dart';
import '../models/message_model.dart';

class ChatService {
  Future<List<MessageModel>> getMessages(String chatId, {String? after}) async {
    final path = after != null
        ? '/api/chats/$chatId/messages?after=$after'
        : '/api/chats/$chatId/messages';
    final resp = await ApiClient.get(path);
    if (resp.containsKey('error')) throw Exception(resp['error']);
    final list = resp['messages'] as List;
    return list.map((j) => MessageModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage(String chatId, String text, {String type = 'text'}) async {
    final resp = await ApiClient.post('/api/chats/$chatId/messages', {
      'text': text,
      'messageType': type,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return MessageModel.fromJson(resp['message'] as Map<String, dynamic>);
  }
}
```

---

## 5. Flutter: `lib/models/message_model.dart`

```dart
class MessageModel {
  final String id;
  final String chatId;
  final String senderUid;
  final String text;
  final String messageType; // "text", "emote"
  final DateTime createdAt;

  MessageModel({required this.id, required this.chatId, required this.senderUid,
      required this.text, this.messageType = 'text', required this.createdAt});

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] ?? '',
    chatId: json['chatId'] ?? '',
    senderUid: json['senderUid'] ?? '',
    text: json['text'] ?? '',
    messageType: json['messageType'] ?? 'text',
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}
```

---

## 6. Pixel Emotes — add to `lib/config/constants.dart`

```dart
static const List<Map<String, String>> pixelEmotes = [
  {'code': 'sword', 'emoji': '⚔️', 'label': 'Battle!'},
  {'code': 'heart', 'emoji': '❤️', 'label': 'Love'},
  {'code': 'fire', 'emoji': '🔥', 'label': 'Fire'},
  {'code': 'trophy', 'emoji': '🏆', 'label': 'Winner'},
  {'code': 'shield', 'emoji': '🛡️', 'label': 'Defend'},
  {'code': 'laugh', 'emoji': '😂', 'label': 'LOL'},
  {'code': 'wave', 'emoji': '👋', 'label': 'Hey'},
  {'code': 'crown', 'emoji': '👑', 'label': 'King'},
];
```

---

## 7. Flutter: `lib/providers/chat_provider.dart`

Uses polling (every 2 seconds) instead of WebSockets for chat to keep it simple.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../services/chat_service.dart';
import '../config/api_client.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<MatchModel> _matches = [];
  List<MessageModel> _messages = [];
  Timer? _pollTimer;
  String? _currentChatId;

  List<MatchModel> get matches => _matches;
  List<MessageModel> get messages => _messages;

  Future<void> loadMatches() async {
    final resp = await ApiClient.get('/api/matches');
    if (resp.containsKey('error')) return;
    final list = resp['matches'] as List;
    _matches = list.map((j) => MatchModel.fromJson(j as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  void startListening(String chatId) {
    _currentChatId = chatId;
    _loadMessages(chatId);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollNew(chatId));
  }

  void stopListening() {
    _pollTimer?.cancel();
    _currentChatId = null;
  }

  Future<void> _loadMessages(String chatId) async {
    _messages = await _chatService.getMessages(chatId);
    notifyListeners();
  }

  Future<void> _pollNew(String chatId) async {
    if (_messages.isEmpty) {
      await _loadMessages(chatId);
      return;
    }
    final after = _messages.last.createdAt.toIso8601String();
    final newMsgs = await _chatService.getMessages(chatId, after: after);
    if (newMsgs.isNotEmpty) {
      _messages.addAll(newMsgs);
      notifyListeners();
    }
  }

  Future<void> sendText(String chatId, String text) async {
    await _chatService.sendMessage(chatId, text);
    await _pollNew(chatId);
  }

  Future<void> sendEmote(String chatId, String emoteCode) async {
    await _chatService.sendMessage(chatId, emoteCode, type: 'emote');
    await _pollNew(chatId);
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }
}
```

---

## 8. Register `ChatProvider` in `lib/app.dart`

```dart
ChangeNotifierProvider(create: (_) => ChatProvider()),
```

---

## 9. Flutter: `lib/screens/chat/chat_list_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/level_badge.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MATCHES'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: Consumer<ChatProvider>(builder: (context, cp, _) {
        if (cp.matches.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No matches yet.', style: Theme.of(context).textTheme.bodyLarge),
          ]));
        }
        return ListView.builder(itemCount: cp.matches.length, itemBuilder: (context, i) {
          final match = cp.matches[i];
          final other = match.otherUser;
          if (other == null) return const SizedBox.shrink();
          final photoUrl = other.photoUrl.isNotEmpty
              ? (other.photoUrl.startsWith('http') ? other.photoUrl : '${AppConstants.apiBaseUrl}${other.photoUrl}')
              : '';
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              backgroundColor: AppTheme.surfaceColor,
              child: photoUrl.isEmpty ? const Icon(Icons.person, color: AppTheme.textSecondary) : null,
            ),
            title: Text(other.displayName),
            subtitle: Text('${other.characterClass} · Lv ${other.level}'),
            trailing: LevelBadge(level: other.level, league: other.league, size: 32),
            onTap: () => context.push('/chat/${match.chatId}'),
          );
        });
      }),
    );
  }
}
```

---

## 10. Flutter: `lib/screens/chat/chat_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showEmotes = false;

  @override
  void initState() {
    super.initState();
    Provider.of<ChatProvider>(context, listen: false).startListening(widget.chatId);
  }

  @override
  void dispose() {
    Provider.of<ChatProvider>(context, listen: false).stopListening();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    Provider.of<ChatProvider>(context, listen: false).sendText(widget.chatId, text);
    _textCtrl.clear();
    _scrollToBottom();
  }

  void _sendEmote(String code) {
    Provider.of<ChatProvider>(context, listen: false).sendEmote(widget.chatId, code);
    setState(() => _showEmotes = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<AuthProvider>(context).user?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('CHAT'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: Column(children: [
        Expanded(child: Consumer<ChatProvider>(builder: (context, cp, _) {
          if (cp.messages.isEmpty) {
            return const Center(child: Text('Say something!',
                style: TextStyle(color: AppTheme.textSecondary)));
          }
          return ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.all(12),
              itemCount: cp.messages.length, itemBuilder: (context, i) {
            final msg = cp.messages[i];
            final isMe = msg.senderUid == myUid;
            if (msg.messageType == 'emote') {
              final emote = AppConstants.pixelEmotes.firstWhere(
                  (e) => e['code'] == msg.text, orElse: () => {'emoji': '❓'});
              return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(emote['emoji']!, style: const TextStyle(fontSize: 40))));
            }
            return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primaryColor : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(isMe ? 12 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 12))),
                    child: Text(msg.text, style: TextStyle(
                        color: isMe ? Colors.white : AppTheme.textPrimary))));
          });
        })),
        if (_showEmotes) Container(height: 60, color: AppTheme.surfaceColor,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
                children: AppConstants.pixelEmotes.map((e) => GestureDetector(
                    onTap: () => _sendEmote(e['code']!),
                    child: Padding(padding: const EdgeInsets.all(8),
                        child: Text(e['emoji']!, style: const TextStyle(fontSize: 28))))).toList())),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: AppTheme.surfaceColor, child: Row(children: [
          IconButton(icon: Icon(_showEmotes ? Icons.keyboard : Icons.emoji_emotions,
              color: AppTheme.secondaryColor),
              onPressed: () => setState(() => _showEmotes = !_showEmotes)),
          Expanded(child: TextField(controller: _textCtrl,
              decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
              onSubmitted: (_) => _send())),
          IconButton(icon: const Icon(Icons.send, color: AppTheme.primaryColor), onPressed: _send),
        ])),
      ]),
    );
  }
}
```

---

## 11. Flutter: `lib/screens/match/match_celebration_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class MatchCelebrationScreen extends StatelessWidget {
  final String myName;
  final String theirName;
  final String chatId;
  const MatchCelebrationScreen({super.key, required this.myName,
      required this.theirName, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('❤️', style: TextStyle(fontSize: 48)).animate()
              .scale(begin: const Offset(0, 0), duration: 500.ms).then().shake(hz: 2, duration: 400.ms),
          const SizedBox(width: 24),
          const Text('⚔️', style: TextStyle(fontSize: 48)).animate(delay: 200.ms)
              .scale(begin: const Offset(0, 0), duration: 500.ms),
          const SizedBox(width: 24),
          const Text('❤️', style: TextStyle(fontSize: 48)).animate(delay: 400.ms)
              .scale(begin: const Offset(0, 0), duration: 500.ms).then().shake(hz: 2, duration: 400.ms),
        ]),
        const SizedBox(height: 32),
        Text("IT'S A MATCH!", style: TextStyle(fontSize: 28, color: AppTheme.accentGold,
                fontWeight: FontWeight.bold)).animate().fadeIn(delay: 600.ms, duration: 400.ms),
        const SizedBox(height: 12),
        Text('$myName & $theirName', style: Theme.of(context).textTheme.bodyLarge)
            .animate().fadeIn(delay: 800.ms, duration: 400.ms),
        const SizedBox(height: 48),
        ElevatedButton(onPressed: () => context.go('/chat/$chatId'),
            child: const Text('SEND A MESSAGE')).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/browse'), child: const Text('KEEP SWIPING')),
      ],
    )));
  }
}
```

---

## 12. Add routes

```dart
GoRoute(path: '/chats', builder: (_, s) => const ChatListScreen()),
GoRoute(path: '/chat/:chatId', builder: (_, s) => ChatScreen(chatId: s.pathParameters['chatId']!)),
GoRoute(path: '/match-celebration', builder: (_, s) {
  final extras = s.extra as Map<String, String>;
  return MatchCelebrationScreen(myName: extras['myName']!, theirName: extras['theirName']!, chatId: extras['chatId']!);
}),
```

---

## 13. Verification Checklist

- [ ] `GET /api/matches` returns matches with other user's profile
- [ ] `POST /api/chats/:chatId/messages` saves a message
- [ ] `GET /api/chats/:chatId/messages` returns messages in order
- [ ] `?after=` parameter works for polling
- [ ] Chat list shows all matched users
- [ ] Sending text appears after poll (within 2 seconds)
- [ ] Pixel emotes send and display as large emoji
- [ ] Match celebration screen animates correctly

---

## What Phase 9 Expects

Phase 9 builds leaderboard and battle history. It needs Go endpoints for fetching leaderboard and battle history.
