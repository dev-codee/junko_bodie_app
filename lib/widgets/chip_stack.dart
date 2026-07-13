import 'package:flutter/material.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/widgets/chip.dart';

Color getChipColor(double val) {
  if (val == 1.0) return AppColors.chipWhite;
  if (val == 2.0) return AppColors.chipOrange;
  if (val == 5.0) return AppColors.chipRed;
  if (val == 10.0) return AppColors.chipBlue;
  if (val == 25.0) return AppColors.chipGreen;
  if (val == 100.0) return AppColors.chipBlack;
  if (val == 500.0) return AppColors.chipPurple;
  if (val == 1000.0) return AppColors.chipYellow;
  return AppColors.gold;
}

Color getChipTextColor(double val) {
  if (val == 1.0 || val == 1000.0) return Colors.black;
  if (val == 100.0) return AppColors.gold;
  return Colors.white;
}

/// A smaller, lightweight chip drawn on the betting layout felt.
class MiniChip extends StatelessWidget {
  final double chipVal;
  final double yOffset;
  final int zIndex;
  final String? customColor;
  final String? displayText;

  const MiniChip({
    super.key,
    required this.chipVal,
    required this.yOffset,
    required this.zIndex,
    this.customColor,
    this.displayText,
  });

  @override
  Widget build(BuildContext context) {
    final color = getChipColor(chipVal);
    final textColor = getChipTextColor(chipVal);
    const size = 24.0;

    Color? parsedCustomColor;
    if (customColor != null) {
      try {
        final cleanHex = customColor!.replaceAll('#', '');
        parsedCustomColor = Color(int.parse('0xFF$cleanHex'));
      } catch (_) {}
    }

    return Positioned(
      top: yOffset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: parsedCustomColor != null
                  ? parsedCustomColor.withOpacity(0.5)
                  : Colors.black.withOpacity(0.6),
              blurRadius: 4,
              offset: const Offset(0, 0),
            ),
          ],
          border: Border.all(
            color: parsedCustomColor ?? AppColors.gold.withOpacity(0.75),
            width: 1.2,
          ),
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: ChipPainter(
              color: color,
              isSelected: false,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1.0),
                child: Text(
                  displayText ?? (chipVal >= 1000 ? '${(chipVal / 1000).toInt()}k' : '${chipVal.toInt()}'),
                  style: playfairDisplay(
                    fontSize: (displayText?.length ?? 0) > 3 ? 6.0 : 7.5,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ).copyWith(
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget showing a stack of chips placed on a betting grid cell.
/// Displays up to the last 4 chips vertically offset, with count indicators.
class ChipStackWidget extends StatelessWidget {
  final List<double> chips;
  final String phase;
  final bool deleteMode;
  final bool isMine;
  final String? customColor;
  final String? playerInitial;
  final bool isHovered;

  const ChipStackWidget({
    super.key,
    required this.chips,
    required this.phase,
    this.deleteMode = false,
    this.isMine = true,
    this.customColor,
    this.playerInitial,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    // Show last 4 chips visually in the stack
    final visibleChips = chips.length > 4 ? chips.sublist(chips.length - 4) : chips;
    final hiddenCount = chips.length - 4;

    // Set size to EXACTLY the base chip size. This ensures the bottom-most 
    // chip is perfectly centered on intersections. The stack will visually 
    // grow upwards by overflowing the clip box.
    const double chipSize = 24.0;
    final totalAmount = chips.fold<double>(0, (sum, val) => sum + val);
    final totalAmountText = totalAmount >= 1000 ? '${(totalAmount / 1000).toInt()}k' : '${totalAmount.toInt()}';

    return SizedBox(
      width: chipSize,
      height: chipSize,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Render the visible chips from bottom to top
          ...List.generate(visibleChips.length, (idx) {
            final chipVal = visibleChips[idx];
            final isTopChip = idx == visibleChips.length - 1;
            return MiniChip(
              key: ValueKey('chip-${chips.length - visibleChips.length + idx}'),
              chipVal: chipVal,
              yOffset: -(idx * 3.0), // Stack grows upwards
              zIndex: idx,
              customColor: customColor,
              displayText: isTopChip ? totalAmountText : null,
            );
          }),

          // Delete icon badge overlay (if deleteMode is enabled)
          if (deleteMode && isMine)
            Positioned(
              top: -((visibleChips.length - 1) * 3.0) - 6,
              right: -6,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.0),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '✕',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          // Hovered "+N" hidden count badge
          if (hiddenCount > 0 && isHovered)
            Positioned(
              bottom: -15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '+$hiddenCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
