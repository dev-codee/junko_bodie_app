import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

// ─── Web parchment palette ─────────────────────────────────
const Color _kPagePaper = Color(0xFFE8D9B8);
const Color _kCardPaper = Color(0xFFF5EDD5);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kInkGreen = Color(0xFF0F2318);
const Color _kInkBrown = Color(0xFF3A3028);
const Color _kInkMuted = Color(0xFF6B5A3A);
const Color _kChampRed = Color(0xFFC0392B);

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedWheelType = 'american';
  bool _isQueueing = false;

  @override
  void initState() {
    super.initState();
    // Play entry background music
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        soundEngine.playEntryBackgroundMusic();
      }
    });
  }

  @override
  void dispose() {
    soundEngine.stopEntryBackgroundMusic();
    super.dispose();
  }

  Future<void> _handleStartMatchmaking() async {
    setState(() {
      _isQueueing = true;
    });

    soundEngine.playClick();
    soundEngine.playWaitingBackgroundMusic();

    final provider = Provider.of<TournamentProvider>(context, listen: false);
    provider.clearError();
    await provider.createOrJoinTournament(_selectedWheelType);

    // If the matchmaking call set an error, drop back to the entry lobby so
    // the user sees the dialog and can retry.
    if (provider.error != null && mounted) {
      soundEngine.stopWaitingBackgroundMusic();
      setState(() {
        _isQueueing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();

    // Route to tournament screen once active
    if (_isQueueing && provider.tournament != null && provider.tournament!.status == 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        soundEngine.stopEntryBackgroundMusic();
        soundEngine.stopWaitingBackgroundMusic();
        soundEngine.playTourneyBackgroundMusic();
        context.go('/tournament/${provider.tournament!.id}');
      });
    }

    // Briefing-room (matchmaking) keeps its dark theme; the entry lobby uses
    // the cream/parchment design that mirrors the web app.
    if (_isQueueing) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF1E7A5E), Color(0xFF0A2318)],
              center: Alignment.center,
              radius: 1.2,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: _buildBriefingCard(provider),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kPagePaper,
      body: SafeArea(
        child: Stack(
          children: [
            _buildLobbyMain(provider),
            if (provider.error != null)
              _buildErrorBanner(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(TournamentProvider provider) {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFFEE2E2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MATCHMAKING UNAVAILABLE',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.error!,
                          style: const TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFB91C1C), size: 18),
                    splashRadius: 18,
                    onPressed: provider.clearError,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyMain(TournamentProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          // Cream card filling the safe area
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _kCardPaper,
                border: Border.all(color: _kGold, width: 2.5),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: _kGold.withOpacity(0.18),
                    blurRadius: 0,
                    spreadRadius: 6,
                  ),
                  const BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 40,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Inner gold inset line
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _kGold.withOpacity(0.5), width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  // Compass watermark on the right
                  Positioned(
                    right: -40,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: 440,
                        height: 440,
                        child: CustomPaint(painter: _CompassWatermarkPainter()),
                      ),
                    ),
                  ),
                  // Main content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 16, 48, 24),
                    child: _buildLobbyContent(),
                  ),
                  // Sign Out (top right)
                  Positioned(
                    top: 12,
                    right: 20,
                    child: TextButton(
                      onPressed: () async {
                        await Provider.of<AuthProvider>(context, listen: false).signOut();
                        if (mounted) context.go('/login');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        backgroundColor: const Color(0x1ADC2626),
                        side: const BorderSide(color: Color(0x4DDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'SIGN OUT',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),
                  // Back chevron (bottom left, matches the "<" icon visible in the web screenshot)
                  Positioned(
                    top: 12,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => context.go('/lobby'),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kGold.withOpacity(0.1),
                          border: Border.all(color: _kGold.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_left, color: _kGold, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Corner notch "bites" — quarter circles in page-paper color cutting into card corners
          Positioned(top: 0, left: 0, child: _cornerBite(topLeft: true)),
          Positioned(top: 0, right: 0, child: _cornerBite(topRight: true)),
          Positioned(bottom: 0, left: 0, child: _cornerBite(bottomLeft: true)),
          Positioned(bottom: 0, right: 0, child: _cornerBite(bottomRight: true)),
        ],
      ),
    );
  }

  Widget _buildLobbyContent() {
    // On wide/short (landscape) screens use a two-column layout — hero on the
    // left, championship info on the right — so the content fills the card
    // instead of shrinking into a small centered block. Tall/narrow screens get
    // the single column. Either way a FittedBox guards against overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 600;
        // Two-column (landscape) whenever the card is comfortably wide. Based on
        // width only — the available height can be reported loosely here, and a
        // height check was wrongly falling back to the small single column.
        final bool wide = maxW > 720;

        final Widget body = wide
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: hero + wheel select + enter button
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _topLabelRow(),
                            const SizedBox(height: 10),
                            _title(),
                            const SizedBox(height: 12),
                            _diamondSeparator(),
                            const SizedBox(height: 14),
                            _subtitle(),
                            const SizedBox(height: 26),
                            _wheelToggle(),
                            const SizedBox(height: 22),
                            _enterButton(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      // Right: championship points card
                      Expanded(child: _champCard()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _statsRow(),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _topLabelRow(),
                  const SizedBox(height: 6),
                  _title(),
                  const SizedBox(height: 8),
                  _diamondSeparator(),
                  const SizedBox(height: 10),
                  _subtitle(),
                  const SizedBox(height: 18),
                  _wheelToggle(),
                  const SizedBox(height: 18),
                  _enterButton(),
                  const SizedBox(height: 22),
                  _statsRow(),
                  const SizedBox(height: 14),
                  _champCard(),
                  const SizedBox(height: 6),
                ],
              );

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: maxW, child: body),
          ),
        );
      },
    );
  }

  Widget _topLabelRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 1.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _kGold, Colors.transparent]),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'THE CALM BEFORE THE STORM',
          style: GoogleFonts.inter(
            color: _kGoldDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.9,
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 56,
          height: 1.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _kGold, Colors.transparent]),
          ),
        ),
      ],
    );
  }

  Widget _title() {
    return Text(
      "Ready To Prove You're the Best?",
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Georgia',
        color: _kInkGreen,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 0.4,
        fontFeatures: [FontFeature.enable('smcp')],
      ),
    );
  }

  Widget _diamondSeparator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 40, height: 1, color: _kGold.withOpacity(0.6)),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 7, height: 7, color: _kGold),
        ),
        const SizedBox(width: 10),
        Container(width: 40, height: 1, color: _kGold.withOpacity(0.6)),
      ],
    );
  }

  Widget _subtitle() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: const Text(
        "You've learned the rules. Now it's time to test your strategy and skill\nagainst other players in a combat format.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Georgia',
          color: _kInkBrown,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _wheelToggle() {
    return Column(
      children: [
        Text(
          'SELECT WHEEL VARIANT',
          style: GoogleFonts.inter(
            color: _kGoldDark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2318).withOpacity(0.06),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _kGold.withOpacity(0.25), width: 1.5),
            ),
            child: Row(
              children: [
                _toggleSegment('AMERICAN (00)', 'american'),
                _toggleSegment('EUROPEAN (0)', 'european'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleSegment(String label, String value) {
    final bool isActive = _selectedWheelType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          soundEngine.playClick();
          setState(() {
            _selectedWheelType = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? _kGold : _kGold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100),
            boxShadow: isActive
                ? [BoxShadow(color: _kGold.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? _kInkGreen : _kGoldDark,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'Arial',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _enterButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: GestureDetector(
        onTap: _handleStartMatchmaking,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF9E7B9),
                Color(0xFFD4AC4A),
                Color(0xFFC9941E),
                Color(0xFF8A5E0A),
              ],
              stops: [0.0, 0.45, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0x66FFFFFF), width: 1),
            // Sharp dark bottom edge (simulates the web's 6px bottom border)
            // + soft drop shadow underneath.
            boxShadow: const [
              BoxShadow(color: Color(0xFF6B4A08), offset: Offset(0, 6)),
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          alignment: Alignment.center,
          // DefaultTextStyle.merge forces an explicit baseline so nothing
          // upstream can render this Text invisible.
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFF0F2318),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              decoration: TextDecoration.none,
            ),
            child: const Text('ENTER TOURNAMENT'),
          ),
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        _statItem(Icons.group, '6 PLAYERS'),
        _statVDivider(),
        _statItem(Icons.emoji_events, 'PRIZE: CHAMPIONSHIP POINTS'),
        _statVDivider(),
        _statItem(Icons.close, '5 ROUND ELIMINATION'),
      ],
    );
  }

  Widget _statItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kInkGreen.withOpacity(0.85), size: 20),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: _kInkGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statVDivider() {
    return Container(
      width: 1,
      height: 28,
      color: _kInkGreen.withOpacity(0.3),
    );
  }

  Widget _champCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGold.withOpacity(0.4), width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _kInkGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, color: _kGold, size: 22),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CHAMPIONSHIP POINTS',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: _kInkGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.1,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Only the Top 3 players with a positive chip balance earn championship points.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: Color(0xFF5A4A30),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _kGold.withOpacity(0.2)),
          // Points row
          IntrinsicHeight(
            child: Row(
              children: [
                _champCol('1ST PLACE', '+1000', _kGold),
                _champVDivider(),
                _champCol('2ND PLACE', '+100', _kGold),
                _champVDivider(),
                _champCol('3RD PLACE', '+50', _kGold),
                _champVDivider(),
                _champCol('BUSTED (0 CHIPS)', '-50', _kChampRed, dimmed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _champCol(String place, String value, Color valueColor, {bool dimmed = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              place,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: _kInkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Georgia',
                color: valueColor == _kGold ? const Color(0xFFB8892E) : valueColor,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: dimmed ? 0.35 : 0.75,
              child: CustomPaint(
                size: const Size(56, 16),
                painter: _LaurelPainter(),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'POINTS',
              style: TextStyle(
                fontFamily: 'Arial',
                color: _kInkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _champVDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: _kGold.withOpacity(0.3),
    );
  }

  Widget _cornerBite({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    const double size = 22.0;
    BorderRadius radius;
    if (topLeft) {
      radius = const BorderRadius.only(bottomRight: Radius.circular(size));
    } else if (topRight) {
      radius = const BorderRadius.only(bottomLeft: Radius.circular(size));
    } else if (bottomLeft) {
      radius = const BorderRadius.only(topRight: Radius.circular(size));
    } else {
      radius = const BorderRadius.only(topLeft: Radius.circular(size));
    }
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _kPagePaper,
          borderRadius: radius,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BRIEFING / MATCHMAKING CARD — cream parchment, mirrors web
  // ──────────────────────────────────────────────────────────
  Widget _buildBriefingCard(TournamentProvider provider) {
    final int count = provider.tournament?.players.length ?? 0;
    final List<TournamentPlayer> players =
        (provider.tournament?.players ?? const <TournamentPlayer>[]).cast<TournamentPlayer>();

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _kCardPaper,
              border: Border.all(color: _kGold, width: 2.5),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: _kGold.withOpacity(0.18), spreadRadius: 6),
                const BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 12)),
              ],
            ),
            child: Stack(
              children: [
                // Inner gold inset line
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _kGold.withOpacity(0.5), width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
                  child: _buildBriefingContent(provider, count, players),
                ),
              ],
            ),
          ),
        ),
        // Corner notches (page color = green, since the briefing screen sits on green bg)
        Positioned(top: 0, left: 0, child: _briefingCornerBite(topLeft: true)),
        Positioned(top: 0, right: 0, child: _briefingCornerBite(topRight: true)),
        Positioned(bottom: 0, left: 0, child: _briefingCornerBite(bottomLeft: true)),
        Positioned(bottom: 0, right: 0, child: _briefingCornerBite(bottomRight: true)),
      ],
    );
  }

  Widget _buildBriefingContent(
    TournamentProvider provider,
    int count,
    List<TournamentPlayer> players,
  ) {
    // Scale the whole briefing block down to fit the card height so all six
    // player slots + the matched pill are visible at once (no scrolling) on
    // short landscape screens, while staying full-size on taller layouts.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 700;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top eyebrow
                  Text(
                    'TOURNAMENT MATCHMAKING',
                    style: TextStyle(
                      color: _kGoldDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5.6,
                      fontFamily: 'Arial',
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Big title
                  const Text(
                    'Searching for Players...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: Color(0xFF051410),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      fontFeatures: [FontFeature.enable('smcp')],
                      shadows: [Shadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle with live countdown
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        color: Color(0xFF3A3028),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Match begins automatically in '),
                        TextSpan(
                          text: '${provider.lobbyTimeRemaining}s',
                          style: const TextStyle(
                            color: _kGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // 3x2 player slots grid
                  Builder(
                    builder: (context) {
                      const double gap = 16;
                      final double cellW = (w - gap * 2) / 3;
                      return Column(
                        children: [
                          for (int row = 0; row < 2; row++) ...[
                            Row(
                              children: [
                                for (int col = 0; col < 3; col++) ...[
                                  SizedBox(
                                    width: cellW,
                                    child: () {
                                      final int i = row * 3 + col;
                                      if (i < count) {
                                        return _briefingSlotFilled(players[i]);
                                      }
                                      return _briefingSlotEmpty();
                                    }(),
                                  ),
                                  if (col < 2) const SizedBox(width: gap),
                                ],
                              ],
                            ),
                            if (row == 0) const SizedBox(height: gap),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  // Matched pill
                  _matchedPill(count),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _briefingSlotFilled(TournamentPlayer p) {
    final String avatar = p.avatarUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGold.withOpacity(0.4), width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF111111),
                  border: Border.all(color: _kGold, width: 2),
                ),
                child: ClipOval(
                  child: avatar.isNotEmpty && avatar.startsWith('http')
                      ? Image.network(avatar, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.person, color: _kGold, size: 32))
                      : const Icon(Icons.person, color: _kGold, size: 32),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.username.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: _kInkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _briefingSlotEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withOpacity(0.03),
        border: Border.all(color: _kGold.withOpacity(0.1), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withOpacity(0.08),
            ),
            child: Icon(Icons.person, color: _kGold.withOpacity(0.35), size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            'EMPTY',
            style: TextStyle(
              fontFamily: 'Arial',
              color: _kInkGreen.withOpacity(0.30),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchedPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: _kGold.withOpacity(0.08),
        border: Border.all(color: _kGold.withOpacity(0.2), width: 1.5),
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SpinningArc(size: 18, color: _kGold),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'Arial',
                color: Color(0xFF3A3028),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              children: [
                const TextSpan(text: 'MATCHED '),
                TextSpan(
                  text: '$count/6',
                  style: const TextStyle(color: _kGoldDark),
                ),
                const TextSpan(text: ' PLAYERS'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _briefingCornerBite({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    const double size = 22.0;
    BorderRadius radius;
    if (topLeft) {
      radius = const BorderRadius.only(bottomRight: Radius.circular(size));
    } else if (topRight) {
      radius = const BorderRadius.only(bottomLeft: Radius.circular(size));
    } else if (bottomLeft) {
      radius = const BorderRadius.only(topRight: Radius.circular(size));
    } else {
      radius = const BorderRadius.only(topLeft: Radius.circular(size));
    }
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        // Bite is the green page-bg color (radial-gradient midpoint approximation).
        decoration: BoxDecoration(
          color: const Color(0xFF134A37),
          borderRadius: radius,
        ),
      ),
    );
  }
}

// Spinning arc indicator for the "MATCHED X/6 PLAYERS" pill.
class _SpinningArc extends StatefulWidget {
  final double size;
  final Color color;
  const _SpinningArc({required this.size, required this.color});

  @override
  State<_SpinningArc> createState() => _SpinningArcState();
}

class _SpinningArcState extends State<_SpinningArc> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              backgroundColor: widget.color.withOpacity(0.1),
              value: 0.25,
            ),
          ),
        );
      },
    );
  }
}

// ─── Compass watermark painter (right-side decoration) ────────────────
class _CompassWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final Paint stroke = Paint()
      ..color = _kGold.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer rings
    canvas.drawCircle(Offset(cx, cy), 230, stroke);
    canvas.drawCircle(
      Offset(cx, cy),
      180,
      Paint()
        ..color = _kGold.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      120,
      Paint()
        ..color = _kGold.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      30,
      Paint()
        ..color = _kGold.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      12,
      Paint()..color = _kGold.withOpacity(0.5),
    );

    // Compass spikes
    final spike = Paint()..color = _kGold.withOpacity(0.45);
    final dimSpike = Paint()..color = _kGold.withOpacity(0.25);

    // North
    final p1 = Path()
      ..moveTo(cx, cy - 230)
      ..lineTo(cx + 12, cy - 10)
      ..lineTo(cx, cy)
      ..lineTo(cx - 12, cy - 10)
      ..close();
    canvas.drawPath(p1, spike);
    // South
    final p2 = Path()
      ..moveTo(cx, cy + 230)
      ..lineTo(cx + 12, cy + 10)
      ..lineTo(cx, cy)
      ..lineTo(cx - 12, cy + 10)
      ..close();
    canvas.drawPath(p2, dimSpike);
    // West
    final p3 = Path()
      ..moveTo(cx - 230, cy)
      ..lineTo(cx - 10, cy - 12)
      ..lineTo(cx, cy)
      ..lineTo(cx - 10, cy + 12)
      ..close();
    canvas.drawPath(p3, dimSpike);
    // East
    final p4 = Path()
      ..moveTo(cx + 230, cy)
      ..lineTo(cx + 10, cy - 12)
      ..lineTo(cx, cy)
      ..lineTo(cx + 10, cy + 12)
      ..close();
    canvas.drawPath(p4, spike);

    // 36 tick marks
    for (int i = 0; i < 36; i++) {
      final double angle = (i * 10) * math.pi / 180;
      final bool major = i % 9 == 0;
      final double r1 = major ? 195 : 205;
      const double r2 = 230;
      final Paint p = Paint()
        ..color = _kGold.withOpacity(0.3)
        ..strokeWidth = major ? 1.5 : 0.8;
      canvas.drawLine(
        Offset(cx + r1 * math.cos(angle), cy + r1 * math.sin(angle)),
        Offset(cx + r2 * math.cos(angle), cy + r2 * math.sin(angle)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompassWatermarkPainter oldDelegate) => false;
}

// ─── Laurel sprig painter (under each points number) ──────────────────
class _LaurelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint p = Paint()
      ..color = _kGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Left sprig
    final left = Path()
      ..moveTo(w * 0.10, h * 0.5)
      ..quadraticBezierTo(w * 0.05, h * 0.33, w * 0.025, h * 0.16)
      ..moveTo(w * 0.025, h * 0.16)
      ..quadraticBezierTo(w * 0.075, h * 0.21, w * 0.10, h * 0.38);
    canvas.drawPath(left, p);

    // Right sprig (mirrored)
    final right = Path()
      ..moveTo(w * 0.90, h * 0.5)
      ..quadraticBezierTo(w * 0.95, h * 0.33, w * 0.975, h * 0.16)
      ..moveTo(w * 0.975, h * 0.16)
      ..quadraticBezierTo(w * 0.925, h * 0.21, w * 0.90, h * 0.38);
    canvas.drawPath(right, p);

    // Center stem
    final stem = Path()
      ..moveTo(w * 0.45, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.58, w * 0.55, h * 0.75);
    canvas.drawPath(stem, p);
  }

  @override
  bool shouldRepaint(covariant _LaurelPainter oldDelegate) => false;
}
