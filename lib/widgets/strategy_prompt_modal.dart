import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kGold = Color(0xFFC9A44C);

/// Shown after a spin completes while a strategy is active, prompting the
/// player to choose how the staged sequence should proceed.
/// Ports the web's StrategyPromptModal.
class StrategyPromptModal extends StatelessWidget {
  final int stageNumber;
  final bool isLastStage;
  final VoidCallback onReplayStage;
  final VoidCallback onResetToStageOne;
  final VoidCallback onNextStage;
  final VoidCallback onExit;

  const StrategyPromptModal({
    super.key,
    required this.stageNumber,
    required this.isLastStage,
    required this.onReplayStage,
    required this.onResetToStageOne,
    required this.onNextStage,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B120C), Color(0xFF0E0906)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGold.withOpacity(0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, 12)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _kGold.withOpacity(0.25), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stage $stageNumber Complete',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Strategy Action Required',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Options
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  _OptionButton(
                    icon: Icons.refresh,
                    label: 'Replay Stage $stageNumber',
                    onTap: onReplayStage,
                  ),
                  if (stageNumber > 1) ...[
                    const SizedBox(height: 8),
                    _OptionButton(
                      icon: Icons.arrow_back,
                      label: 'Return to Stage 1',
                      onTap: onResetToStageOne,
                    ),
                  ],
                  if (!isLastStage) ...[
                    const SizedBox(height: 8),
                    _OptionButton(
                      icon: Icons.arrow_forward,
                      label: 'Next Stage',
                      onTap: onNextStage,
                      highlighted: true,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _OptionButton(
                    icon: Icons.close,
                    label: 'Exit Strategy',
                    onTap: onExit,
                    danger: true,
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool danger;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color border;
    Color background;
    Color iconBg;
    Color iconColor;
    Color labelColor;

    if (highlighted) {
      border = _kGold.withOpacity(0.3);
      background = _kGold.withOpacity(0.1);
      iconBg = _kGold;
      iconColor = const Color(0xFF111111);
      labelColor = _kGold;
    } else if (danger) {
      border = const Color(0xFFEF4444).withOpacity(0.2);
      background = const Color(0xFFEF4444).withOpacity(0.05);
      iconBg = const Color(0xFFEF4444).withOpacity(0.1);
      iconColor = const Color(0xFFEF4444);
      labelColor = const Color(0xFFEF4444);
    } else {
      border = Colors.white.withOpacity(0.06);
      background = Colors.white.withOpacity(0.02);
      iconBg = Colors.white.withOpacity(0.06);
      iconColor = Colors.white.withOpacity(0.85);
      labelColor = Colors.white;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
