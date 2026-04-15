import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../utils/photo_url_helper.dart';
import '../../widgets/swipe_card.dart';

class MatchBrowserScreen extends StatefulWidget {
  const MatchBrowserScreen({super.key});
  @override
  State<MatchBrowserScreen> createState() => _MatchBrowserScreenState();
}

class _MatchBrowserScreenState extends State<MatchBrowserScreen> {
  final CardSwiperController _controller = CardSwiperController();
  final Set<int> _precached = <int>{};
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = Provider.of<MatchProvider>(context, listen: false);
      if (mp.profiles.isEmpty && !mp.loading) {
        mp.loadProfiles();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onSwipe(int prev, int? current, CardSwiperDirection direction) {
    if (_inFlight) return false;
    final mp = Provider.of<MatchProvider>(context, listen: false);
    if (mp.remainingSwipes <= 0) return false;
    if (prev < 0 || prev >= mp.profiles.length) return false;
    final profile = mp.profiles[prev];

    HapticFeedback.mediumImpact();

    if (direction == CardSwiperDirection.right) {
      final myName = Provider.of<AuthProvider>(context, listen: false)
              .user?.displayName ?? 'You';
      _inFlight = true;
      mp.like(profile.uid).then((isMatch) {
        if (!mounted) return;
        if (isMatch) {
          HapticFeedback.heavyImpact();
          context.push('/match-celebration', extra: {
            'myName': myName,
            'theirName': profile.displayName,
            'chatId': mp.lastMatchChatId ?? '',
          });
        }
      }).catchError((Object error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record like, try again')),
        );
      }).whenComplete(() {
        if (mounted) {
          setState(() => _inFlight = false);
        } else {
          _inFlight = false;
        }
      });
    } else if (direction == CardSwiperDirection.left) {
      mp.pass();
    } else {
      return false;
    }
    return true;
  }

  void _precacheAround(BuildContext context, List<dynamic> profiles, int topIndex) {
    for (final i in [topIndex + 1, topIndex + 2]) {
      if (i < 0 || i >= profiles.length) continue;
      if (_precached.contains(i)) continue;
      final url = profiles[i].photoUrl as String?;
      if (url == null || url.isEmpty) continue;
      _precached.add(i);
      precacheImage(
        CachedNetworkImageProvider(PhotoUrlHelper.fullUrl(url)),
        context,
      );
    }
  }

  Color _counterColor(int remaining) {
    if (remaining > 5) return AppTheme.accentGold;
    if (remaining >= 1) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BROWSE'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<MatchProvider>(builder: (_, mp, __) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Semantics(
                label: '${mp.remainingSwipes} swipes remaining today',
                child: Text('${mp.remainingSwipes} LEFT',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: _counterColor(mp.remainingSwipes))),
              ),
            ),
          )),
        ],
      ),
      body: Consumer<MatchProvider>(builder: (context, mp, _) {
        if (mp.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (mp.remainingSwipes <= 0) {
          return _emptyState(
            icon: Icons.lock,
            title: 'DAILY LIMIT REACHED',
            body: 'Come back tomorrow or unlock Premium for unlimited swipes.',
            ctaLabel: 'GO PREMIUM',
            onCta: () => context.push('/premium'),
          );
        }
        if (mp.profiles.isEmpty) {
          return _emptyState(
            icon: Icons.search_off,
            title: 'NO CHALLENGERS',
            body: 'Win battles to level up and unlock new opponents.',
            ctaLabel: 'BATTLE NOW',
            onCta: () => context.push('/battle/queue'),
          );
        }

        return Column(children: [
          Expanded(
            child: CardSwiper(
              controller: _controller,
              cardsCount: mp.profiles.length,
              numberOfCardsDisplayed:
                  mp.profiles.length >= 3 ? 3 : mp.profiles.length,
              backCardOffset: const Offset(0, 32),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              isLoop: false,
              allowedSwipeDirection: const AllowedSwipeDirection.symmetric(
                  horizontal: true, vertical: false),
              onSwipe: _onSwipe,
              onEnd: () => mp.loadProfiles(),
              cardBuilder: (context, index, px, py) {
                _precacheAround(context, mp.profiles, index);
                return SwipeCard(
                    user: mp.profiles[index], dragPercentX: px.toDouble());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Semantics(
                  button: true,
                  label: 'Pass',
                  child: _circleBtn(Icons.close, Colors.redAccent, () {
                    if (_inFlight) return;
                    _controller.swipe(CardSwiperDirection.left);
                  }),
                ),
                Semantics(
                  button: true,
                  label: 'Like',
                  child: _circleBtn(Icons.favorite, Colors.greenAccent, () {
                    if (_inFlight) return;
                    _controller.swipe(CardSwiperDirection.right);
                  }),
                ),
              ],
            ),
          ),
        ]);
      }),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) =>
      FloatingActionButton(
        heroTag: icon.codePoint,
        backgroundColor: color,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white),
      );

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String body,
    required String ctaLabel,
    required VoidCallback onCta,
  }) =>
      Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onCta, child: Text(ctaLabel)),
        ]),
      ));
}
