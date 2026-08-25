/// "?" Tour button — Dart port of the web `TourHelpButton`.
/// Tapping it starts the per-page guide for [tourId].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tour_controller.dart';

class TourHelpButton extends StatelessWidget {
  final String tourId;
  const TourHelpButton({super.key, required this.tourId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: () => context.read<TourController>().startPageTour(tourId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x14123524),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: const Color(0x40123524)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.help_outline, size: 14, color: Color(0xFF123524)),
            SizedBox(width: 6),
            Text('TOUR',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF123524))),
          ]),
        ),
      ),
    );
  }
}
