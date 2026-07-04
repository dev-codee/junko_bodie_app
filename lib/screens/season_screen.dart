import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/services/leaderboard_service.dart';
import 'package:junko_bodie/services/user_service.dart';

class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  List<LeaderboardEntry> _entries = [];
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final list = await _leaderboardService.getLeaderboard();
      final userProfile = await _userService.getProfile();
      if (mounted) {
        setState(() {
          _entries = list;
          _currentUsername = userProfile.username;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: const Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 4,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.deepGreen,
              Color(0xFF08100D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              _buildNavBar(),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  child: Column(
                    children: [
                      // Header Section
                      _buildHeader(),
                      const SizedBox(height: 16),

                      // Leaderboard Table
                      Expanded(
                        child: _buildLeaderboardTable(),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating footer action bar
              _buildFloatingFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left back link
          GestureDetector(
            onTap: () => context.go('/lobby'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 18, color: Colors.white30),
                const SizedBox(width: 4),
                Text(
                  'LOBBY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white30,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),

          // Center Title
          Column(
            children: [
              Text(
                'GLOBAL WEALTH',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white30,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public, size: 10, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    'WORLDWIDE REGISTRY',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right page links
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => context.go('/rankings'),
                child: Text(
                  'SEASON PTS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white30,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.white24, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: AppColors.gold, size: 24),
            const SizedBox(width: 10),
            Text(
              'WEALTH REGISTRY',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.95),
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Registry of verified asset equity across the global network.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'PROTOCOL SYNC ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.green,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderboardTable() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public, size: 36, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text(
              'NO ENTRIES FOUND',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.2),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: Colors.white.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    'RANK',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white30, letterSpacing: 1.0),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('CONTENDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white30, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(
                  width: 100,
                  child: Text('TIER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white30, letterSpacing: 1.0), textAlign: TextAlign.center),
                ),
                const SizedBox(
                  width: 100,
                  child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white30, letterSpacing: 1.0), textAlign: TextAlign.center),
                ),
                const SizedBox(
                  width: 140,
                  child: Text('NET WORTH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white30, letterSpacing: 1.0), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Scrollable List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _entries.length,
              itemBuilder: (context, idx) {
                final player = _entries[idx];
                final isMe = player.name == _currentUsername;
                final isGold = player.rank == 1;
                final isSilver = player.rank == 2;
                final isBronze = player.rank == 3;

                // Tier logic
                String tierLabel = 'Rookie';
                Color tierColor = Colors.white24;
                if (player.balance > 100000) {
                  tierLabel = 'Grandmaster';
                  tierColor = AppColors.gold;
                } else if (player.balance > 10000) {
                  tierLabel = 'Veteran';
                  tierColor = Colors.white54;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.gold.withValues(alpha: 0.06) : Colors.transparent,
                    border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Row(
                    children: [
                      // Rank
                      SizedBox(
                        width: 60,
                        child: Text(
                          player.rank.toString(),
                          style: playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isGold
                                ? AppColors.gold
                                : isSilver
                                    ? const Color(0xFFCCCCCC)
                                    : isBronze
                                        ? const Color(0xFFCD7F32)
                                        : isMe
                                            ? AppColors.gold
                                            : Colors.white12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Profile Avatar & Name
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white10,
                                  border: Border.all(
                                    color: isMe ? AppColors.gold : Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child: player.avatar != null && player.avatar!.startsWith('http')
                                      ? Image.network(player.avatar!, fit: BoxFit.cover)
                                      : Center(child: _buildAvatarIcon(player.avatar ?? 'default', size: 14)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        player.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                          color: isMe ? AppColors.gold : Colors.white.withValues(alpha: 0.9),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (player.isPro) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_user, size: 14, color: Colors.green),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tier
                      SizedBox(
                        width: 100,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: tierColor, width: 0.5),
                            ),
                            child: Text(
                              tierLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: tierColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Status
                      const SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'STABLE',
                              style: TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                      // Net Worth
                      SizedBox(
                        width: 140,
                        child: Text(
                          '\$${player.balance.toStringAsFixed(0)}',
                          style: playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isMe ? AppColors.gold : Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'GLOBAL ASSETS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 2.0,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Container(width: 1, height: 16, color: Colors.white10),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => context.go('/rankings'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SEASON RANKINGS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: AppColors.gold, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarIcon(String type, {required double size, Color? color}) {
    final c = color ?? const Color(0xFFF5EDD5);
    switch (type) {
      case 'default':
        return Icon(Icons.person_outline, size: size, color: c);
      case 'crown':
        return Icon(Icons.workspace_premium_outlined, size: size, color: c);
      case 'diamond':
        return Icon(Icons.diamond_outlined, size: size, color: c);
      case 'star':
        return Icon(Icons.star_outline, size: size, color: c);
      case 'spade':
        return Text('♠', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'heart':
        return Text('♥', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'club':
        return Text('♣', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'dice':
        return Icon(Icons.casino_outlined, size: size, color: c);
      case 'chip':
        return Icon(Icons.circle_outlined, size: size, color: c);
      case 'trophy':
        return Icon(Icons.emoji_events_outlined, size: size, color: c);
      case 'bolt':
        return Icon(Icons.bolt_outlined, size: size, color: c);
      default:
        return Icon(Icons.person_outline, size: size, color: c);
    }
  }
}
