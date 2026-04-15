import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:shimmer/shimmer.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../utils/photo_url_helper.dart';
import 'level_badge.dart';

class PixelCard extends StatelessWidget {
  final UserModel user;
  final bool showStats;

  const PixelCard({super.key, required this.user, this.showStats = false});

  @override
  Widget build(BuildContext context) {
    final url = PhotoUrlHelper.fullUrl(user.photoUrl);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          const BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            offset: const Offset(-2, -2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: showStats ? 4 : 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                url.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        memCacheHeight: 900,
                        fadeInDuration: const Duration(milliseconds: 250),
                        placeholder: (_, __) => _placeholderForUser(),
                        errorWidget: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
                // Bottom gradient scrim with name / class / level
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.displayName,
                                style: textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${user.characterClass} · ${user.league}',
                                style: textTheme.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        LevelBadge(
                          level: user.level,
                          league: user.league,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showStats)
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 2),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'W ${user.wins}  L ${user.losses}  '
                    'WR ${user.wins + user.losses > 0 ? ((user.wins / (user.wins + user.losses)) * 100).toStringAsFixed(1) : 0}%',
                    style: textTheme.labelMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholderForUser() {
    final hash = user.blurHash;
    if (hash != null && hash.isNotEmpty) {
      return BlurHash(hash: hash);
    }
    return _shimmer();
  }

  Widget _fallback() => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.person, size: 64, color: AppColors.textMuted),
        ),
      );

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceAlt,
        child: Container(color: AppColors.surface),
      );
}
