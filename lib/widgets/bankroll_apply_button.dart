import 'dart:async';
import 'package:flutter/material.dart';

/// Applies a valid draft to both the saved and live bankroll.
class BankrollApplyButton extends StatefulWidget {
  final TextEditingController controller;
  final double startingBalance;
  final double balance;
  final bool enabled;
  final ValueChanged<double> onApply;
  const BankrollApplyButton({super.key, required this.controller,
    required this.startingBalance, required this.balance,
    required this.enabled, required this.onApply});
  @override
  State<BankrollApplyButton> createState() => _BankrollApplyButtonState();
}

class _BankrollApplyButtonState extends State<BankrollApplyButton> {
  bool _pressed = false;
  bool _applied = false;
  Timer? _timer;
  @override
  void initState() { super.initState(); widget.controller.addListener(_edited); }
  @override
  void didUpdateWidget(covariant BankrollApplyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_edited);
      widget.controller.addListener(_edited);
    }
  }
  void _edited() { _timer?.cancel(); setState(() => _applied = false); }
  @override
  void dispose() { _timer?.cancel(); widget.controller.removeListener(_edited); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(widget.controller.text.trim());
    final canApply = widget.enabled && amount != null && amount > 0 &&
        amount <= 9007199254740991 &&
        (amount != widget.startingBalance || amount != widget.balance);
    return Listener(
      onPointerDown: (_) { if (canApply) setState(() => _pressed = true); },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton(
          onPressed: canApply ? () {
            widget.onApply(amount.toDouble());
            setState(() { _applied = true; _pressed = false; });
            _timer?.cancel();
            _timer = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _applied = false);
            });
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _applied ? const Color(0xFF22C55E) : const Color(0x1AC9A44C),
            foregroundColor: _applied ? Colors.white : const Color(0xFFC9A44C),
            disabledBackgroundColor: _applied ? const Color(0xFF22C55E) : const Color(0x1AC9A44C),
            disabledForegroundColor: _applied ? Colors.white : Colors.white38,
            minimumSize: const Size(94, 36),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .2), end: Offset.zero).animate(animation), child: child),
            ),
            child: Text(_applied ? 'APPLIED!' : 'APPLY', key: ValueKey(_applied),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
