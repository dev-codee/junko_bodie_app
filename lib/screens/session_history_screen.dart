import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/services/session_history_service.dart';

// ─── Gold/cream palette (matches the web session-history page) ──
const Color _kInk = Color(0xFF113626);
const Color _kInkDeep = Color(0xFF0F2E21);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);
const Color _kGoldText = Color(0xFFA47D25);
const Color _kPos = Color(0xFF15803D);
const Color _kNeg = Color(0xFFB91C1C);

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final SessionHistoryService _service = SessionHistoryService();

  String _tab = '10'; // '10' | '30' | 'lifetime'
  bool _isLoading = true;
  String? _error;
  List<GameSession> _sessions = [];
  LifetimeStats? _lifetime;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_tab == 'lifetime') {
        final lt = await _service.getLifetime();
        if (mounted) setState(() => _lifetime = lt);
      } else {
        final list = await _service.getSessions(limit: _tab == '30' ? 30 : 10);
        if (mounted) setState(() => _sessions = list);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load history. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setTab(String t) {
    if (_tab == t) return;
    setState(() => _tab = t);
    _load();
  }

  Future<void> _deleteSession(String id) async {
    setState(() => _sessions = _sessions.where((s) => s.id != id).toList());
    try {
      await _service.deleteSession(id);
    } catch (_) {}
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ClearAllDialog(),
    );
    if (ok != true) return;
    setState(() => _clearing = true);
    try {
      await _service.clearAll();
      if (mounted) {
        setState(() {
          _sessions = [];
          _lifetime = null;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFFFFDCA3), Color(0xFFDABB8B), Color(0xFF9E7F41)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGold),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 40, offset: Offset(0, 15)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool showClear = _sessions.isNotEmpty || _tab == 'lifetime';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        border: Border(bottom: BorderSide(color: _kGold.withValues(alpha: 0.3))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/lobby'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGold.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.arrow_back, color: _kInk, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Session History',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                Text(
                  'Your play sessions & lifetime stats',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kGoldDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (showClear)
            GestureDetector(
              onTap: _clearing ? null : _confirmClearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _clearing ? const Color(0xFFB91C1C) : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66EF4444), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      _clearing ? 'CLEARING…' : 'CLEAR ALL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 10),
          const Icon(Icons.access_time, color: _kGoldText, size: 20),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    Widget tab(String key, String label) {
      final bool active = _tab == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setTab(key),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? _kInkDeep : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? _kGold : _kGoldDark,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          tab('10', 'LAST 10'),
          tab('30', 'LAST 30'),
          tab('lifetime', 'LIFETIME'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: _kGold),
        ),
      );
    }
    if (_error != null) {
      return _emptyState(Icons.error_outline, 'Something went wrong', _error!);
    }
    if (_tab == 'lifetime') {
      return _buildLifetime();
    }
    if (_sessions.isEmpty) {
      return _emptyState(
        Icons.access_time,
        'No sessions yet',
        'Play a session in Solo Play or Tournament, then return to the lobby to see it here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _SessionCard(
        session: _sessions[i],
        onDelete: () => _deleteSession(_sessions[i].id),
      ),
    );
  }

  Widget _buildLifetime() {
    final s = _lifetime;
    if (s == null) {
      return _emptyState(
        Icons.show_chart,
        'No completed sessions yet',
        'Play a session and return to the lobby to see your lifetime stats.',
      );
    }

    String sign(double n) => n == 0 ? '±' : (n > 0 ? '+' : '-');
    String money(double n) => _fmt(n.abs());

    final items = <_LifeItem>[
      _LifeItem(Icons.layers_outlined, 'Total Sessions', _fmt(s.totalSessions.toDouble()), 'completed sessions'),
      _LifeItem(Icons.bolt_outlined, 'Total Spins', _fmt(s.totalSpins.toDouble()), '${_fmt(s.totalWins.toDouble())} wins'),
      _LifeItem(Icons.gps_fixed, 'Avg Win Rate', '${_fmt(s.avgWinPercentage, 1)}%', 'across all sessions'),
      _LifeItem(Icons.bar_chart, 'Lifetime P&L', '${sign(s.totalProfitLoss)}\$${money(s.totalProfitLoss)}', 'total profit / loss',
          variant: s.totalProfitLoss >= 0 ? 1 : -1),
      _LifeItem(Icons.trending_up, 'Best Session', '+\$${_fmt(s.bestSessionProfit)}', 'single session profit', variant: 1),
      _LifeItem(Icons.trending_down, 'Worst Session', '${sign(s.worstSessionLoss)}\$${money(s.worstSessionLoss)}', 'single session loss',
          variant: s.worstSessionLoss < 0 ? -1 : 0),
      _LifeItem(Icons.emoji_events_outlined, 'Biggest Win', '+\$${_fmt(s.biggestSingleWin)}', 'single spin profit', variant: 1),
      _LifeItem(Icons.show_chart, 'Avg / Spin', '${sign(s.avgNetPerSpin)}\$${money2(s.avgNetPerSpin)}', 'average net per spin',
          variant: s.avgNetPerSpin >= 0 ? 1 : -1),
      _LifeItem(Icons.trending_up, 'Peak Bankroll', '\$${_fmt(s.bestBankroll)}', 'all-time highest'),
      _LifeItem(Icons.layers_outlined, 'Total Wagered', '\$${_fmt(s.totalVolumeWagered)}', 'chips wagered lifetime'),
    ];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _lifetimeCard(items[i]),
    );
  }

  Widget _lifetimeCard(_LifeItem it) {
    final Color valColor = it.variant == 1
        ? _kPos
        : it.variant == -1
            ? _kNeg
            : _kInk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(it.icon, size: 16, color: _kGoldText),
          const SizedBox(height: 4),
          Text(
            it.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _kGoldDark,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              it.value,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: valColor,
              ),
            ),
          ),
          Text(
            it.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: _kInk.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String desc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _kGoldText, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _kInk.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // helpers
  String money2(double n) => n.abs().toStringAsFixed(2);
}

String _fmt(double n, [int decimals = 0]) {
  final s = n.toStringAsFixed(decimals);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
}

class _LifeItem {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final int variant; // 1 pos, -1 neg, 0 neutral
  _LifeItem(this.icon, this.label, this.value, this.sub, {this.variant = 0});
}

// ── Session card ───────────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final GameSession session;
  final VoidCallback onDelete;
  const _SessionCard({required this.session, required this.onDelete});

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year}  $h:$mm $ap';
  }

  String _duration() {
    if (session.endTime == null) return 'In progress';
    final ms = session.endTime!.difference(session.startTime).inMilliseconds;
    final mins = ms ~/ 60000;
    final secs = (ms % 60000) ~/ 1000;
    return mins == 0 ? '${secs}s' : '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final double? profit = session.computedProfit;
    final Color profitColor = (profit == null || profit == 0)
        ? _kGoldDark
        : profit > 0
            ? _kPos
            : _kNeg;
    final String profitText = profit == null
        ? '—'
        : '${profit == 0 ? '±' : profit > 0 ? '+' : '-'}\$${_fmt(profit.abs())}';
    final double winPct = session.winPercentage ??
        (session.totalSpins > 0 ? session.totalWins / session.totalSpins * 100 : 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.startTime),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.sessionType == 'tournament' ? '🏆 Tournament' : '🎯 Solo Play'} · ${_duration()}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _kGoldDark,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.endTime != null ? 'PROFIT / LOSS' : 'CURRENT P/L',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: _kGoldDark,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: profitColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: profitColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      profitText,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: profitColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                    border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.remove, color: _kGoldText, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip('Spins', '${session.totalSpins}'),
              _statChip('Win %', '${_fmt(winPct, 1)}%'),
              _statChip('Start', '\$${_fmt(session.startingBankroll)}'),
              _statChip('Peak', '\$${_fmt(session.highestBankroll)}', gold: true),
              _statChip('Low', '\$${_fmt(session.lowestBankroll)}'),
              _statChip('Best Win', '\$${_fmt(session.biggestSingleWin)}', gold: true),
              _statChip('Drawdown', '\$${_fmt(session.largestDrawdown)}'),
              if (session.strategyName != null && session.strategyName!.isNotEmpty)
                _statChip('Strategy', session.strategyName!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: _kGoldDark,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: gold ? _kGoldText : _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clear-all confirmation dialog ────────────────────────────────────────────
class _ClearAllDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clear Session History?',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete ALL your session history and lifetime stats. This action cannot be undone. Are you sure?',
              style: GoogleFonts.inter(fontSize: 13, color: _kGoldDark, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kGoldDark,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0x59EF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'CLEAR ALL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
