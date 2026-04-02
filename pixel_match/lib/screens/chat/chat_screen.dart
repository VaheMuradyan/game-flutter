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
                  (e) => e['code'] == msg.text, orElse: () => {'emoji': '?'});
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
