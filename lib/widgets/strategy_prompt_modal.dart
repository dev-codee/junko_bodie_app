import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kGold = Color(0xFFC9A44C);
const Color _kDanger = Color(0xFFEF4444);

/// Shown after a spin completes while a strategy is active, prompting the
/// player to choose how the staged sequence should proceed.
/// Ports the web's StrategyPromptModal.
class StrategyPromptModal extends StatefulWidget {
  final int stageNumber;
  final bool isLastStage;
  final VoidCallback onReplayStage;
  final VoidCallback onNextStage;
  final VoidCallback onExit;

  /// Jump back to an earlier stage by its 0-based index. Powers the
  /// "Return to Stage __" list under "More Options".
  final ValueChanged<int> onGoToStage;

  const StrategyPromptModal({
    super.key,
    required this.stageNumber,
    required this.isLastStage,
    required this.onReplayStage,
    required this.onNextStage,
    required this.onExit,
    required this.onGoToStage,
  });

  @override
  State<StrategyPromptModal> createState() => _StrategyPromptModalState();
}

class _StrategyPromptModalState extends State<StrategyPromptModal> {
  bool _isMoreOpen = false;

  @override
  Widget build(BuildContext context) {
    final bool hasPreviousStages = widget.stageNumber > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 460,
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
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _kGold.withOpacity(0.25), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage ${widget.stageNumber} Complete',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 22,
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    // Same Stage — gold circle, back-pointing arrow.
                    _OptionButton(
                      icon: Icons.refresh,
                      label: 'Same Stage',
                      onTap: widget.onReplayStage,
                      style: _OptionStyle.gold,
                    ),
                    if (!widget.isLastStage) ...[
                      const SizedBox(height: 12),
                      // Next Stage — gold circle, forward-pointing arrow.
                      _OptionButton(
                        icon: Icons.arrow_forward,
                        label: 'Next Stage',
                        onTap: widget.onNextStage,
                        style: _OptionStyle.gold,
                      ),
                    ],
                    if (hasPreviousStages) ...[
                      const SizedBox(height: 12),
                      _buildMoreOptions(),
                    ],
                    const SizedBox(height: 12),
                    // Exit — red / danger.
                    _OptionButton(
                      icon: Icons.close,
                      label: 'Exit Strategy',
                      onTap: widget.onExit,
                      style: _OptionStyle.danger,
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

  Widget _buildMoreOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle row
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isMoreOpen = !_isMoreOpen),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'More Options (Return to previous stages)',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _isMoreOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Dropdown list of all completed stages.
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              _isMoreOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.stageNumber - 1; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _StageJumpRow(
                    label: 'Return to Stage ${i + 1}',
                    onTap: () => widget.onGoToStage(i),
                  ),
                ],
              ],
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

enum _OptionStyle { gold, danger }

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _OptionStyle style;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final bool gold = style == _OptionStyle.gold;

    final Color border = gold ? _kGold.withOpacity(0.3) : _kDanger.withOpacity(0.2);
    final Color background = gold ? _kGold.withOpacity(0.1) : _kDanger.withOpacity(0.05);
    final Color iconBg = gold ? _kGold : _kDanger.withOpacity(0.1);
    final Color iconColor = gold ? const Color(0xFF111111) : _kDanger;
    final Color labelColor = gold ? _kGold : _kDanger;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: gold
                ? [
                    BoxShadow(
                      color: _kGold.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Bigger gold circle graphic.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: labelColor,
                  fontSize: 16,
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

class _StageJumpRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StageJumpRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
