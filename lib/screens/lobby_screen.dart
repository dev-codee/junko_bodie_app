/// Lobby screen — the main hub after login.
///
/// Shows player profile, balance, Solo Play, Tournament, and quick actions.
/// Matches the web app's horizontal (landscape) layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/providers/auth_provider.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Enforce landscape mode for Lobby and all subsequent screens
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }

    // The lobby is landscape-only. While the device is still in portrait (the
    // orientation lock from initState is async), show a placeholder instead of
    // the broken vertical layout, and keep re-asserting the landscape lock.
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    if (isPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return const Scaffold(
        backgroundColor: Color(0xFF9E7F41),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, color: Color(0xFF0F2E21), size: 40),
              SizedBox(height: 16),
              Text(
                'ROTATE YOUR DEVICE',
                style: TextStyle(
                  color: Color(0xFF0F2E21),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final userName = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@')[0] ??
        'Player';
    final avatarUrl = user.userMetadata?['avatar_url'] ??
        user.userMetadata?['picture'];

    return Scaffold(
      body: Container(
        // Warm radial gold gradient background matching web
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFFFFDCA3), // #ffdca3
              Color(0xFFDABB8B), // #dabb8b
              Color(0xFF9E7F41), // #9e7f41
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background Accents (glowing orbs)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.15 - 150,
              top: MediaQuery.of(context).size.height * 0.75 - 150,
              child: _buildGlowOrb(Colors.white.withValues(alpha: 0.4)),
            ),
            Positioned(
              right: MediaQuery.of(context).size.width * 0.15 - 150,
              top: MediaQuery.of(context).size.height * 0.15 - 150,
              child: _buildGlowOrb(Colors.white.withValues(alpha: 0.3)),
            ),

            // Main Content Container (Glassmorphism)
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000), // 15% black
                      blurRadius: 45,
                      offset: Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ColorFilter.matrix([
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0, 0, 0, 1, 0,
                    ]), // Simplified backdrop filter to avoid heavy performance hit, relying on container color
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          // Scale paddings/gaps to the available height so the
                          // layout looks balanced on tall phones (Pixel 6a)
                          // AND on shorter aspect ratios (foldables, tablets).
                          final double h = c.maxHeight;
                          final double gap = (h * 0.025).clamp(8.0, 24.0);
                          final double bottomPad = (h * 0.04).clamp(12.0, 28.0);
                          return Padding(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                            child: Column(
                              children: [
                                // ── Header ─────────────────────────────────────
                                _buildHeader(context, auth, userName, avatarUrl),
                                SizedBox(height: gap),

                                // ── Main Content (Cards) — fills all leftover
                                //    vertical space, so cards aren't compressed.
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _PlayCard(
                                          icon: Icons.play_arrow_rounded,
                                          iconColor: const Color(0xFFD4BC81),
                                          label: 'SOLO PLAY',
                                          description:
                                              'Classic American and European Roulette.\nTest Your Skill Against The House.',
                                          onTap: () => context.push('/game'),
                                        ).animate().fadeIn(duration: 600.ms).slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 600.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _PlayCard(
                                          icon: Icons.emoji_events_rounded,
                                          iconColor: const Color(0xFF8B5CF6),
                                          label: 'TOURNAMENT',
                                          description:
                                              'Test Yourself Against Other Top Players\nIn A Live Tournament Experience.',
                                          onTap: () => context.push('/tournament'),
                                        )
                                            .animate()
                                            .fadeIn(duration: 600.ms, delay: 200.ms)
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 600.ms,
                                              delay: 200.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: gap),

                                // ── Quick Actions ─────────────────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _QuickAction(
                                      icon: Icons.history_rounded,
                                      label: 'HISTORY',
                                      onTap: () => context.push('/session-history'),
                                    ),
                                    const SizedBox(width: 16),
                                    _QuickAction(
                                      icon: Icons.track_changes_rounded,
                                      label: 'STRATEGIES',
                                      onTap: () => _comingSoon(context, 'Strategies'),
                                    ),
                                    const SizedBox(width: 16),
                                    _QuickAction(
                                      icon: Icons.bar_chart_rounded,
                                      label: 'RANKINGS',
                                      onTap: () => context.push('/rankings'),
                                    ),
                                  ],
                                )
                                    .animate()
                                    .fadeIn(duration: 500.ms, delay: 400.ms)
                                    .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      duration: 500.ms,
                                      delay: 400.ms,
                                      curve: Curves.easeOutCubic,
                                    ),

                                SizedBox(height: gap),

                                // ── Footer (Contact Support) — slim pill ─────
                                InkWell(
                                  onTap: () {}, // TODO: Contact support
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2E21),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFF0F2E21)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1A000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'CONTACT SUPPORT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFFF2E8D0),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: const Color(0xFF0F2E21),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildGlowOrb(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, String userName,
      String? avatarUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile card
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            height: 68,
            padding: const EdgeInsets.fromLTRB(12, 12, 26, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: AppColors.gold.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '1,000', // TODO: From game provider
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA47D25),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Logo center
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'JUNKO BODIE',
              style: playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF113626),
                letterSpacing: 3,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            Text(
              'ROULETTE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF113626),
                letterSpacing: 5,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Sign out
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: IconButton(
            onPressed: () => auth.signOut(),
            icon: const Icon(
              Icons.logout,
              color: Color(0xFF8B6B22),
              size: 24,
            ),
            tooltip: 'Sign Out',
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.transparent,
      child: const Center(
        child: Icon(Icons.person, color: AppColors.gold, size: 28),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Play Card Widget (Solo / Tournament)
// ──────────────────────────────────────────────────────────────────────────────

class _PlayCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _PlayCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  State<_PlayCard> createState() => _PlayCardState();
}

class _PlayCardState extends State<_PlayCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          // Fill the Expanded parent so cards have full height (not compressed).
          width: double.infinity,
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF113626) : const Color(0xFF0F2E21),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (_isHovered)
                const BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 45,
                  offset: Offset(0, 20),
                )
              else
                const BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
            ],
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
          // FittedBox guarantees the content never overflows the card, no
          // matter how short the available height is on a given device.
          // The inner SizedBox gives the description a bounded width so it
          // wraps to two lines instead of laying out as one long line.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
            width: 240,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.iconColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (_isHovered)
                      BoxShadow(
                        color: widget.iconColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Label
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              Text(
                widget.description.replaceAll('\n', ' '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ],
          ),
          ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Quick Action Button
// ──────────────────────────────────────────────────────────────────────────────

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 92,
          height: 56,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
            ),
            boxShadow: [
              if (_isHovered)
                const BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                )
              else
                const BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: const Color(0xFF113626),
                size: 18,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF113626),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
