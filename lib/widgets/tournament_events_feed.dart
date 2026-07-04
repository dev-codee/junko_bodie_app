import 'dart:async';
import 'package:flutter/material.dart';

class TournamentEventsFeed extends StatefulWidget {
  final List<Map<String, dynamic>> events;

  const TournamentEventsFeed({
    super.key,
    required this.events,
  });

  @override
  State<TournamentEventsFeed> createState() => _TournamentEventsFeedState();
}

class _TournamentEventsFeedState extends State<TournamentEventsFeed> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Periodically refresh to expire old events from the UI (lifespan of 8 seconds)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    // Filter to events within the last 8 seconds
    final visibleEvents = widget.events.where((e) {
      final int ts = e['timestamp'] ?? 0;
      return (now - ts) < 8000;
    }).toList();

    if (visibleEvents.isEmpty) {
      return Container(
        width: 200,
        decoration: const BoxDecoration(
          color: Color(0x7F07140E),
          border: Border(
            left: BorderSide(color: Color(0x30C9A44C), width: 1.5),
          ),
        ),
        child: const Center(
          child: Text(
            'Waiting for bets...',
            style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Color(0x7F07140E),
        border: Border(
          left: BorderSide(color: Color(0x30C9A44C), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x20C9A44C), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rss_feed, color: Color(0xFFC9A44C), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'LIVE FEED',
                      style: TextStyle(
                        color: Color(0xFFC9A44C),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Events scrolling list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              itemCount: visibleEvents.length,
              itemBuilder: (context, index) {
                final e = visibleEvents[index];
                final String username = e['username'] ?? '';
                final double amount = (e['amount'] ?? 0.0).toDouble();
                final String colorHex = e['color'] ?? '#c9a44c';
                final String betId = e['betId'] ?? '';
                final Color pColor = _parseHexColor(colorHex);

                // Format the zone name for display
                String zoneDisplay = betId.replaceAll('straight-', '').replaceAll('dozen-', '12s-').toUpperCase();
                if (zoneDisplay.startsWith('split-')) {
                  zoneDisplay = 'SPLIT';
                } else if (zoneDisplay.startsWith('corner-')) {
                  zoneDisplay = 'CORNER';
                } else if (zoneDisplay.startsWith('street-')) {
                  zoneDisplay = 'STREET';
                } else if (zoneDisplay.startsWith('sixline-')) {
                  zoneDisplay = '6-LINE';
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      // User color circle indicator
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Text info
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                            children: [
                              TextSpan(
                                text: username,
                                style: TextStyle(color: pColor, fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' placed on '),
                              TextSpan(
                                text: zoneDisplay,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bet Amount
                      Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
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

  Color _parseHexColor(String hex) {
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    return Color(int.parse(cleaned, radix: 16));
  }
}
