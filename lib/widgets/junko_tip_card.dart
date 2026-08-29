/// Junko's Tip card — mirrors the web `.junkoTipCard` used across the
/// Simulation Setup, Simulation Run, and Strategy Navigator screens. Dark ink
/// card with a gold "JUNKO'S TIP" pill, a title, and an italic advice body.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JunkoTipCard extends StatelessWidget {
  final String title;
  final String text;
  final double maxWidth;

  const JunkoTipCard({
    super.key,
    required this.title,
    required this.text,
    this.maxWidth = 480,
  });

  static const Color _ink = Color(0xFF0A2218);
  static const Color _gold = Color(0xFFC9A44C);
  static const Color _goldTitle = Color(0xFFECD08C);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.lightbulb, size: 14, color: _ink),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    "JUNKO'S TIP",
                    style: GoogleFonts.inter(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _goldTitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
