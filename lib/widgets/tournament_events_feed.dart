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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    // Filter to events within the last 8 seconds
    final visibleEvents = widget.events.where((e) {
      final int ts = e['timestamp'] ?? 0;
      return (now - ts) < 8000;
    }).toList();

    // Aggregate events by player to show total bet on that spin
    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final e in visibleEvents) {
      final username = e['username'] ?? '';
      if (!aggregated.containsKey(username)) {
        aggregated[username] = {
          'username': username,
          'amount': 0.0,
          'color': e['color'] ?? '#c9a44c',
          'timestamp': e['timestamp'] ?? 0,
        };
      }
      aggregated[username]!['amount'] = (aggregated[username]!['amount'] as double) + (e['amount'] ?? 0.0).toDouble();
      if ((e['timestamp'] ?? 0) > (aggregated[username]!['timestamp'] as int)) {
        aggregated[username]!['timestamp'] = e['timestamp'] ?? 0;
      }
    }

    final displayEvents = aggregated.values.toList()
      ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    if (displayEvents.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC163C30), Color(0xE60C2319)],
          ),
          border: Border(
            left: BorderSide(color: Color(0x30C9A44C), width: 1.5),
            top: BorderSide(color: Color(0x30C9A44C), width: 1.5),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Expanded(
              child: Center(
                child: Text(
                  'Waiting for bets...',
                  style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC163C30), Color(0xE60C2319)],
        ),
        border: Border(
          left: BorderSide(color: Color(0x30C9A44C), width: 1.5),
          top: BorderSide(color: Color(0x30C9A44C), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Events scrolling list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              itemCount: displayEvents.length,
              itemBuilder: (context, index) {
                final e = displayEvents[index];
                final String username = e['username'] ?? '';
                final double amount = (e['amount'] ?? 0.0).toDouble();
                final String colorHex = e['color'] ?? '#c9a44c';
                final String betId = e['betId'] ?? '';
                final Color pColor = _parseHexColor(colorHex);

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
                      const SizedBox(width: 8),

                      // Text info
                      Expanded(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: pColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bet Amount
                      Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
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
