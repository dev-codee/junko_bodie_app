import 'package:flutter/material.dart';
import 'package:junko_bodie/services/api_service.dart';

class TournamentWinnerOverlay extends StatefulWidget {
  final dynamic tournament;
  final dynamic mePlayer;
  final bool visible;
  final VoidCallback onExit;

  const TournamentWinnerOverlay({
    super.key,
    required this.tournament,
    required this.mePlayer,
    required this.visible,
    required this.onExit,
  });

  @override
  State<TournamentWinnerOverlay> createState() => _TournamentWinnerOverlayState();
}

class _TournamentWinnerOverlayState extends State<TournamentWinnerOverlay> {
  String _globalRank = '—';

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _fetchGlobalRank();
    }
  }

  @override
  void didUpdateWidget(covariant TournamentWinnerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _fetchGlobalRank();
    }
  }

  Future<void> _fetchGlobalRank() async {
    try {
      final api = ApiService();
      final res = await api.get('/api/season/rankings');
      final rankings = res['rankings'] as List<dynamic>? ?? [];
      
      final String myUsername = widget.mePlayer?['username'] ?? '';
      
      final myIdx = rankings.indexWhere((r) => r['username'] == myUsername);
      if (myIdx != -1) {
        if (mounted) {
          setState(() {
            _globalRank = '#${myIdx + 1}';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _globalRank = '—';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _globalRank = '—';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.tournament == null || widget.mePlayer == null) {
      return const SizedBox.shrink();
    }

    final String username = widget.mePlayer['username'] ?? '';
    final int position = widget.mePlayer['final_position'] ?? widget.mePlayer['rank'] ?? 6;
    final double chips = (widget.mePlayer['chips'] ?? 0.0).toDouble();
    final int points = widget.mePlayer['points_earned'] ?? 0;
    final bool isWinner = position == 1;

    // Build standings list
    final List<dynamic> players = List<dynamic>.from(widget.tournament['players'] ?? []);
    players.sort((a, b) {
      final int posA = a['final_position'] ?? (a['status'] == 'active' ? 0 : 7);
      final int posB = b['final_position'] ?? (b['status'] == 'active' ? 0 : 7);
      if (posA != posB) return posA.compareTo(posB);
      final double chipsA = (a['current_chips'] ?? 0.0).toDouble();
      final double chipsB = (b['current_chips'] ?? 0.0).toDouble();
      return chipsB.compareTo(chipsA); // tie-break active by chips desc
    });

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5EEDC), Color(0xFFE8D8B0), Color(0xFFDBCB9E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Header bar
              Container(
                height: 60,
                color: const Color(0xFF0F2318),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFFC9A44C)),
                          onPressed: widget.onExit,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'JUNKO BODIE ROULETTE | TOURNAMENT COMPLETE',
                          style: TextStyle(
                            color: Color(0xFFF2E8D0),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5C35),
                        foregroundColor: const Color(0xFFF5E9B8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.exit_to_app, size: 14),
                      label: const Text(
                        'EXIT',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        children: [
                          // Main Title
                          Text(
                            isWinner ? 'CHAMPION!' : 'TOURNAMENT RESULTS',
                            style: const TextStyle(
                              color: Color(0xFF0D2A20),
                              fontFamily: 'Playfair Display',
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              fontSize: 24,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Ribbon banner for username
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF1A4D28), Color(0xFF1A5C35), Color(0xFF1A4D28)]),
                              border: Border(
                                top: BorderSide(color: Color(0xFFC9A84C), width: 1.5),
                                bottom: BorderSide(color: Color(0xFFC9A84C), width: 1.5),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  username.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFF5E9B8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  position == 1 ? '1ST PLACE' : position == 2 ? '2ND PLACE' : position == 3 ? '3RD PLACE' : '$position\tPLACE',
                                  style: const TextStyle(
                                    color: Color(0xFFC9A84C),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stats Cards
                          Row(
                            children: [
                              Expanded(child: _buildSummaryCard('YOUR CHIPS', '\$${chips.toStringAsFixed(0)}', Icons.monetization_on)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSummaryCard('POINTS EARNED', points >= 0 ? '+$points' : '$points', Icons.trending_up, valueColor: points >= 0 ? const Color(0xFF1A5C35) : const Color(0xFFB83232))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSummaryCard('WORLD RANKING', _globalRank, Icons.public)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Standings Card Table
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xEAFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 1),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: const BoxDecoration(
                                    color: Color(0x0F1A5C35),
                                    border: Border(bottom: BorderSide(color: Colors.black12, width: 1.5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 45, child: Text('RANK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black54))),
                                      Expanded(child: Text('PLAYER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black54))),
                                      SizedBox(width: 100, child: Text('FINAL CHIPS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black54))),
                                      SizedBox(width: 80, child: Text('POINTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black54))),
                                    ],
                                  ),
                                ),
                                // Table Rows
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: players.length,
                                  itemBuilder: (context, idx) {
                                    final p = players[idx];
                                    final String pName = p['username'] ?? '';
                                    final double pChips = (p['final_chips'] ?? p['current_chips'] ?? 0.0).toDouble();
                                    final int pRank = idx + 1;
                                    final int pPoints = p['points_earned'] ?? 0;
                                    final bool isMeRow = pName == username;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isMeRow ? const Color(0x15C9A44C) : Colors.transparent,
                                        border: Border(bottom: idx < players.length - 1 ? const BorderSide(color: Colors.black12, width: 0.5) : BorderSide.none),
                                      ),
                                      child: Row(
                                        children: [
                                          // Rank Medal
                                          SizedBox(
                                            width: 45,
                                            child: pRank <= 3
                                                ? Icon(
                                                    Icons.emoji_events,
                                                    color: pRank == 1 ? const Color(0xFFB8960C) : pRank == 2 ? const Color(0xFF7A7A8A) : const Color(0xFF8B5E3C),
                                                    size: 16,
                                                  )
                                                : Text(' #$pRank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black45)),
                                          ),
                                          // Username
                                          Expanded(
                                            child: Text(
                                              pName,
                                              style: TextStyle(
                                                fontWeight: isMeRow ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 12,
                                                color: const Color(0xFF0F2318),
                                              ),
                                            ),
                                          ),
                                          // Chips
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              '\$${pChips.toStringAsFixed(0)}',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87),
                                            ),
                                          ),
                                          // Points
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              pPoints >= 0 ? '+$pPoints' : '$pPoints',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: pPoints >= 0 ? const Color(0xFF1A5C35) : const Color(0xFFB83232),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Points system reference footer
                          const Text(
                            'CHAMPIONSHIP POINTS SYSTEM',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: Color(0xFF1A5C35)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniPointsBadge('1st Place', '+1000 CP', const Color(0xFFB8960C)),
                              _buildMiniPointsBadge('2nd Place', '+100 CP', const Color(0xFF7A7A8A)),
                              _buildMiniPointsBadge('3rd Place', '+50 CP', const Color(0xFF8B5E3C)),
                              _buildMiniPointsBadge('Busted', '-50 CP', const Color(0xFFB83232)),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String val, IconData icon, {Color valueColor = const Color(0xFF1A3024)}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.black38, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: valueColor.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(
                val,
                style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPointsBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
