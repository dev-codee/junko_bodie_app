import 'package:flutter/material.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/widgets/chip.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

/// A tray widget showing the available betting chips.
class ChipTray extends StatelessWidget {
  final double selectedChip;
  final ValueChanged<double> onSelectChip;
  final double balance;
  final double totalBet;
  final bool disabled;

  const ChipTray({
    super.key,
    required this.selectedChip,
    required this.onSelectChip,
    required this.balance,
    required this.totalBet,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final double availableFunds = balance - totalBet;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
          // Left-align so the chips hug the left edge and don't run under the
          // centered floating player card.
          mainAxisAlignment: MainAxisAlignment.start,
          children: chipDenominations.map((denom) {
            final double chipVal = denom.value.toDouble();
            final bool canAfford = availableFunds >= chipVal;
            final bool isSelected = selectedChip == chipVal;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Opacity(
                opacity: disabled ? 0.4 : (canAfford ? 1.0 : 0.6),
                child: ChipWidget(
                  value: chipVal,
                  color: denom.color,
                  textColor: denom.textColor,
                  label: denom.label, // Show "$1", "$2", … like the web app
                  isSelected: isSelected,
                  size: 38, // a little larger; the tray scrolls if they overflow
                  onClick: () {
                    if (!disabled) {
                      soundEngine.playThump();
                      onSelectChip(chipVal);
                    }
                  },
                ),
              ),
            );
          }).toList(),
      ),
    );
  }
}
