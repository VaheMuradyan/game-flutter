import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';
import '../../widgets/level_badge.dart';
import '../../utils/photo_url_helper.dart';

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
          final photoUrl = PhotoUrlHelper.fullUrl(other.photoUrl);
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
