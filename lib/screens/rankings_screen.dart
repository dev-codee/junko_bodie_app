import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/models/season_ranking.dart';
import 'package:junko_bodie/services/season_service.dart';
import 'package:junko_bodie/services/user_service.dart';

// ─── Web parchment palette ─────────────────────────────────
const Color _kPage = Color(0xFFE8D9B8);
const Color _kCard = Color(0xFFF5EDD5);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kInk = Color(0xFF0F2318);
const Color _kAmber = Color(0xFFB8892E);

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final SeasonService _seasonService = SeasonService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  List<RankingEntry> _rankings = [];
  String _searchQuery = '';
  int _year = DateTime.now().year;
  String? _currentUserId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rankingsDoc = await _seasonService.getSeasonRankings();
      final userProfile = await _userService.getProfile();
      final sorted = List<RankingEntry>.from(rankingsDoc.rankings)
        ..sort((a, b) => b.points.compareTo(a.points));
      if (mounted) {
        setState(() {
          _rankings = sorted;
          _year = rankingsDoc.year;
          _currentUserId = userProfile.id;
          _currentUsername = userProfile.username;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFounder(RankingEntry e) =>
      e.badges?['founder'] == true;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kPage,
        body: Center(
          child: Text(
            'SYNCING REGISTRY...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _kInk,
              letterSpacing: 2.0,
            ),
          ),
        ),
      );
    }

    final nonNegative = _rankings.where((r) => r.points >= 0).toList();
    final filtered = nonNegative.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.username.toLowerCase().contains(q) ||
          r.playerId.toLowerCase() == q;
    }).toList();

    return Scaffold(
      backgroundColor: _kPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _buildCard(nonNegative.length, filtered),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dark green top bar ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _kInk,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 3, 16, 3),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/lobby'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'LOBBY',
                style: GoogleFonts.inter(
                  color: _kGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'JUNKO BODIE',
            style: GoogleFonts.inter(
              color: const Color(0xFFF2E8D0),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Text('|', style: TextStyle(color: _kGold.withValues(alpha: 0.5))),
          const SizedBox(width: 10),
          Text(
            'ELITE REGISTRY $_year',
            style: GoogleFonts.inter(
              color: _kGold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Big parchment card ─────────────────────────────────────
  Widget _buildCard(int total, List<RankingEntry> filtered) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        border: Border.all(color: _kGold, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: _kGold.withValues(alpha: 0.18), spreadRadius: 4),
          const BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Dark green header section
          _buildRegistryHeader(total, filtered.length),
          // Table header (cream)
          _buildTableHeader(),
          // Rows
          Expanded(child: _buildRows(filtered)),
          // Footer note
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildRegistryHeader(int total, int registryCount) {
    return Container(
      width: double.infinity,
      color: _kInk,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row with inline stats on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: _kGold, size: 14),
              const SizedBox(width: 6),
              Text(
                'THE ELITE REGISTRY',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  color: Color(0xFFF2E8D0),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· OFFICIAL $_year SEASON',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: _kGold.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Stats inline with the search bar on a single compact row
          Row(
            children: [
              _headerStat('CONTENDERS', total.toString()),
              const SizedBox(width: 16),
              _headerStat('REGISTRY', registryCount.toString()),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF1A2E23),
                      hintText: 'Search Contender Name...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                      prefixIcon: const Icon(Icons.gps_fixed, color: _kGold, size: 16),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kGold, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Georgia',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: _kGold.withValues(alpha: 0.55),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    TextStyle s() => GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kGoldDark,
          letterSpacing: 2,
        );
    return Container(
      color: _kCard,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('RANK', style: s(), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: Text('CONTENDER', style: s())),
          Expanded(flex: 2, child: Text('TIER', style: s(), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('ACTIVITY', style: s(), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('POINTS', style: s(), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildRows(List<RankingEntry> list) {
    if (list.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed, size: 40, color: _kInk.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'NO CONTENDERS FOUND',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _kInk.withValues(alpha: 0.3),
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white.withValues(alpha: 0.45),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: _kGold.withValues(alpha: 0.12)),
        itemBuilder: (context, idx) {
          final entry = list[idx];
          final isMe = entry.playerId == _currentUserId ||
              (entry.username.isNotEmpty && entry.username == _currentUsername);
          final globalRank =
              _rankings.indexWhere((r) => r.playerId == entry.playerId) + 1;
          final isTop3 = globalRank <= 3;
          final isElite = globalRank <= 50;
          final avatar = entry.avatarUrl ?? 'default';
          final isCustom = avatar.startsWith('http') || avatar.startsWith('/');

          return Container(
            color: isMe ? _kGold.withValues(alpha: 0.10) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 44,
                  child: Text(
                    globalRank.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: isTop3
                          ? _kAmber
                          : isMe
                              ? _kInk
                              : _kInk.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Contender
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF111722),
                          border: Border.all(
                            color: isMe ? _kGold : _kInk.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: isCustom
                              ? Image.network(avatar, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildAvatarIcon('default', size: 18, color: _kGold))
                              : Center(child: _buildAvatarIcon(avatar, size: 18, color: _kGold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    (entry.username.isNotEmpty
                                            ? entry.username
                                            : 'Anonymous')
                                        .toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _kInk.withValues(alpha: isMe ? 1 : 0.85),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                if (_isFounder(entry)) ...[
                                  const SizedBox(width: 8),
                                  _founderBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMe ? 'OFFICIAL PROFILE' : 'SEASON PARTICIPANT',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: _kInk.withValues(alpha: 0.25),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tier
                Expanded(
                  flex: 2,
                  child: Center(child: _tierBadge(isElite)),
                ),
                // Activity
                Expanded(
                  flex: 2,
                  child: Text(
                    '${entry.tournamentsPlayed} EVENTS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kInk.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // Points
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatNumber(entry.points),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isElite ? _kInk : _kInk.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tierBadge(bool isElite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isElite ? _kGold.withValues(alpha: 0.1) : _kInk.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isElite ? _kGold.withValues(alpha: 0.4) : _kInk.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        isElite ? 'ELITE TIER' : 'FIELD',
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: isElite ? _kGoldDark : _kInk.withValues(alpha: 0.3),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _founderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kGold.withValues(alpha: 0.2),
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            _kGold.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _kGold.withValues(alpha: 0.4)),
      ),
      child: Text(
        '★ FOUNDER',
        style: GoogleFonts.inter(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: _kGoldDark,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: _kCard,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        'OFFICIAL RECORD OF THE JUNKO BODIE GLOBAL PROTOCOL. ACCESS RESTRICTED TO AUTHORIZED CONTENDERS.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: _kInk.withValues(alpha: 0.4),
          letterSpacing: 3,
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Widget _buildAvatarIcon(String type, {required double size, Color? color}) {
    final c = color ?? _kGold;
    switch (type) {
      case 'default':
        return Icon(Icons.person, size: size, color: c);
      case 'crown':
        return Icon(Icons.workspace_premium, size: size, color: c);
      case 'diamond':
        return Icon(Icons.diamond, size: size, color: c);
      case 'star':
        return Icon(Icons.star, size: size, color: c);
      case 'spade':
        return Text('♠', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'heart':
        return Text('♥', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'club':
        return Text('♣', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'dice':
        return Icon(Icons.casino, size: size, color: c);
      case 'chip':
        return Icon(Icons.album, size: size, color: c);
      case 'trophy':
        return Icon(Icons.emoji_events, size: size, color: c);
      case 'bolt':
        return Icon(Icons.bolt, size: size, color: c);
      default:
        return Icon(Icons.person, size: size, color: c);
    }
  }
}
