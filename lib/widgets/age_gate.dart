/// Age verification gate shown on first app launch.
///
/// Apple requires 17+ age confirmation for apps with simulated gambling
/// content (Guideline 5.3.4). This dialog appears once on first launch
/// and the user's acknowledgment is persisted via SharedPreferences.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junko_bodie/config/theme.dart';

const String _kAgeVerifiedKey = 'age_verified_17_plus';

/// Call this at app startup to show the age gate if the user has not
/// previously confirmed they are 17+.
Future<void> showAgeGateIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyVerified = prefs.getBool(_kAgeVerifiedKey) ?? false;

  if (alreadyVerified) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => const _AgeGateDialog(),
  );
}

class _AgeGateDialog extends StatelessWidget {
  const _AgeGateDialog();

  Future<void> _handleConfirm(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAgeVerifiedKey, true);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 380,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F17),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
                const BoxShadow(
                  color: Color(0x60000000),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shield icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'AGE VERIFICATION',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Junko Bodie is a roulette simulator for entertainment '
                  'and strategy practice purposes only.\n\n'
                  'No real money is used. No prizes are awarded. '
                  'This app contains simulated gambling content '
                  'and is rated 17+.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFF5EDD5).withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleConfirm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.gold.withValues(alpha: 0.25),
                    ),
                    child: Text(
                      'I AM 17 OR OLDER',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Decline text
                Text(
                  'You must be 17 or older to use this app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
