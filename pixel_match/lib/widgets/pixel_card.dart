import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import 'level_badge.dart';

class PixelCard extends StatelessWidget {
  final UserModel user;
  final bool showStats;

  const PixelCard({super.key, required this.user, this.showStats = false});

  String _fullPhotoUrl(String photoUrl) {
    if (photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    return '${AppConstants.apiBaseUrl}$photoUrl';
  }

  @override
  Widget build(BuildContext context) {
    final url = _fullPhotoUrl(user.photoUrl);
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: url.isNotEmpty
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.surfaceColor),
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Expanded(
            flex: showStats ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(user.displayName,
                        style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
                    LevelBadge(level: user.level, league: user.league, size: 36),
                  ]),
                  const SizedBox(height: 4),
                  Text('${user.characterClass} · ${user.league}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (showStats) ...[
                    const SizedBox(height: 8),
                    Text(
                      'W ${user.wins}  L ${user.losses}  '
                      'WR ${user.wins + user.losses > 0 ? ((user.wins / (user.wins + user.losses)) * 100).toStringAsFixed(1) : 0}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
      color: AppTheme.surfaceColor,
      child: const Center(child: Icon(Icons.person, size: 64, color: AppTheme.textSecondary)));
}
