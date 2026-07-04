import 'package:flutter/material.dart';

class TournamentScoresSidebar extends StatelessWidget {
  final List<dynamic> scores;
  final String? myPlayerId;

  const TournamentScoresSidebar({
    super.key,
    required this.scores,
    this.myPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0x7F07140E),
        border: Border(
          right: BorderSide(color: Color(0x30C9A44C), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x20C9A44C), width: 1),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.leaderboard, color: Color(0xFFC9A44C), size: 14),
                SizedBox(width: 8),
                Text(
                  'STANDINGS',
                  style: TextStyle(
                    color: Color(0xFFC9A44C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Player Rows
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: scores.length,
              itemBuilder: (context, index) {
                final s = scores[index];
                final String pid = s['player_id']?.toString() ?? '';
                final String username = s['username'] ?? '';
                final double chips = (s['chips'] ?? 0.0).toDouble();
                final int rank = s['rank'] ?? 0;
                final bool isMe = myPlayerId != null && pid == myPlayerId;
                final bool isEliminated = s['status'] == 'eliminated';
                final double wager = (s['currentWager'] ?? 0.0).toDouble();
                final String avatarUrl = s['avatar_url'] ?? '';
                final String colorHex = s['color'] ?? '#ffffff';
                final Color playerColor = _parseHexColor(colorHex);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0x20C9A44C) : const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFFC9A44C)
                          : isEliminated
                              ? Colors.red.withOpacity(0.2)
                              : Colors.white10,
                      width: isMe ? 1.5 : 1,
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: const Color(0xFFC9A44C).withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        // Rank Number / Crown
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: rank == 1 && !isEliminated
                                ? const Icon(Icons.emoji_events, color: Color(0xFFE5C060), size: 14)
                                : Text(
                                    '$rank',
                                    style: TextStyle(
                                      color: isEliminated ? Colors.white38 : const Color(0xFFC9A44C),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                          ),
                        ),

                        // Avatar
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isEliminated ? Colors.red.withOpacity(0.5) : playerColor,
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(isEliminated),
                                  )
                                : _buildDefaultAvatar(isEliminated),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Username & Chips
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isEliminated ? Colors.white30 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  decoration: isEliminated ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isEliminated ? 'ELIMINATED' : '\$${chips.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: isEliminated
                                      ? Colors.red.withOpacity(0.7)
                                      : const Color(0xFFC9A44C),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Active Wager Chip Badge
                        if (wager > 0 && !isEliminated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F3220),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFC9A44C), width: 1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x20C9A44C),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: Text(
                              '\$${wager.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFFC9A44C),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isEliminated) {
    return Container(
      color: const Color(0xFF0B2B1D),
      child: Icon(
        Icons.person,
        color: isEliminated ? Colors.red.withOpacity(0.3) : const Color(0xFFC9A44C),
        size: 16,
      ),
    );
  }

  Color _parseHexColor(String hex) {
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    return Color(int.parse(cleaned, radix: 16));
  }
}
