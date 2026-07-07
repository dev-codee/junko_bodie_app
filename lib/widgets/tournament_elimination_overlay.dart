import 'package:flutter/material.dart';

class TournamentEliminationOverlay extends StatelessWidget {
  final dynamic player; // Renders details of the eliminated player
  final bool visible;
  final VoidCallback onDismiss;

  const TournamentEliminationOverlay({
    super.key,
    required this.player,
    required this.visible,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || player == null) return const SizedBox.shrink();

    final double chips = (player['chips'] ?? 0.0).toDouble();
    final int rank = player['rank'] ?? 0;
    final String avatarUrl = player['avatar_url'] ?? '';

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFA500A0A), Color(0xFD140000)],
              center: Alignment.center,
              radius: 1.0,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing backdrop shadow
              _PulsingRedGlow(),

              SafeArea(
                // Scale the content down to fit short landscape screens so the
                // whole elimination screen is visible without overflow.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 600;
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: w,
                          child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grayscale Avatar with Skull Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xAAEF4444), width: 4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66DC2626),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ]),
                              child: ClipOval(
                                child: avatarUrl.isNotEmpty
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                                      )
                                    : _buildDefaultAvatar(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Transform.rotate(
                              angle: 0.2,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  border: Border.all(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.dangerous,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // System active stamp
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x66DC2626),
                          border: Border.all(color: const Color(0xAAEF4444), width: 1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'SYSTEM ELIMINATION ACTIVE',
                          style: TextStyle(
                            color: Color(0xFFFEE2E2),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'YOU HAVE BEEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          fontFamily: 'Playfair Display',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Text(
                        'ELIMINATED',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          fontFamily: 'Playfair Display',
                          fontStyle: FontStyle.italic,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Color(0x88DC2626),
                              blurRadius: 20,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Statistics Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          border: Border.all(color: Colors.white24, width: 1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCol('FINAL RANK', '#$rank'),
                            _buildDivider(),
                            _buildStatCol('SETTLED CHIPS', '\$${chips.toStringAsFixed(0)}'),
                            _buildDivider(),
                            _buildStatCol('POINTS', chips <= 0 ? '-50' : '0', color: chips <= 0 ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Loading/Sync Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (idx) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SYNCHRONIZING CHAMPIONSHIP RESULTS...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Back Button / Dismiss
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text(
                          'RETURN TO LOBBY',
                          style: TextStyle(
                            color: Color(0xFFC9A44C),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String val, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white12,
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF1E0707),
      child: const Icon(Icons.person, color: Color(0xFFEF4444), size: 48),
    );
  }
}

class _PulsingRedGlow extends StatefulWidget {
  @override
  State<_PulsingRedGlow> createState() => _PulsingRedGlowState();
}

class _PulsingRedGlowState extends State<_PulsingRedGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.3);
        final opacity = 0.15 + (_controller.value * 0.15);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 500,
              height: 500,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
