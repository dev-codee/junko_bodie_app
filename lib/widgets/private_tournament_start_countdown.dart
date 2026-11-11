import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/logic/private_tournament_countdown.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/widgets/private_tournament_avatar.dart';

class PrivateTournamentStartCountdown extends StatefulWidget {
  final Tournament tournament;

  /// Server elapsed time at mount; subsequent ticks use a monotonic frame clock.
  final Duration elapsed;
  final VoidCallback onComplete;
  final ValueChanged<int>? onBeat;
  const PrivateTournamentStartCountdown({
    super.key,
    required this.tournament,
    required this.elapsed,
    required this.onComplete,
    this.onBeat,
  });

  @override
  State<PrivateTournamentStartCountdown> createState() => _CountdownState();
}

class _CountdownState extends State<PrivateTournamentStartCountdown>
    with SingleTickerProviderStateMixin {
  late final Duration _initialElapsed = widget.elapsed;
  late PrivateCountdownStep _step = privateCountdownStep(_initialElapsed);
  late final Ticker _ticker;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _update(_initialElapsed + elapsed));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_step == PrivateCountdownStep.done) {
        _complete();
      } else {
        _announce();
        _ticker.start();
      }
    });
  }

  void _update(Duration elapsed) {
    final next = privateCountdownStep(elapsed);
    if (next == _step) return;
    if (next == PrivateCountdownStep.done) {
      _complete();
      return;
    }
    setState(() => _step = next);
    _announce();
  }

  void _announce() {
    final beat = _step.beat;
    if (beat == null) return;
    if (widget.onBeat != null) {
      widget.onBeat!(beat);
    } else if (WidgetsBinding.instance.lifecycleState ==
        AppLifecycleState.resumed) {
      soundEngine.playPrivateCountdownBeat(beat);
    }
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _ticker.stop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        colors: [Color(0xFF244C36), Color(0xFF07170F)],
        radius: .9,
      ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight <= 500;
          final padding = compact ? 16.0 : 24.0;
          final width = math.min(1040.0, constraints.maxWidth - padding * 2);
          final dial = compact
              ? 120.0
              : (constraints.maxHeight * .38).clamp(200.0, 380.0);
          final avatarSize = compact ? 40.0 : 64.0;
          final playerWidth = compact ? 116.0 : 128.0;
          final isGo = _step == PrivateCountdownStep.go;
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - padding * 2),
              ),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'YOUR TABLE. YOUR RIVALS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD8BD77),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 12),
                      Text(
                        'Tournament starts in...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFF7EFD9),
                          fontFamily: 'Georgia',
                          fontSize: compact
                              ? 26
                              : (width * .055).clamp(28.0, 56.0),
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 24),
                      Container(
                        width: dial,
                        height: dial,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x99C9A44C),
                            width: 2,
                          ),
                          gradient: const RadialGradient(
                            colors: [Color(0x18C9A44C), Colors.transparent],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x15C9A44C), blurRadius: 60),
                          ],
                        ),
                        child: Semantics(
                          liveRegion: true,
                          label: _step.label,
                          child: ExcludeSemantics(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: AnimatedSwitcher(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween(
                                            begin: 1.25,
                                            end: 1.0,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      ),
                                  child: FittedBox(
                                    key: ValueKey(_step),
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _step.label,
                                      style: TextStyle(
                                        color: const Color(0xFFF4D58A),
                                        fontFamily: 'Georgia',
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                        fontSize:
                                            _step == PrivateCountdownStep.ready
                                            ? dial * .23
                                            : isGo
                                            ? dial * .42
                                            : dial * .66,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 12 : 24,
                        ),
                        child: Text(
                          isGo
                              ? 'Place your bets. Make your move.'
                              : 'Round 1 · Get ready to place your bets',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFDDCFAB),
                            fontSize: compact ? 14 : 16,
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: compact ? 16 : 40,
                        runSpacing: 14,
                        children: widget.tournament.players
                            .map(
                              (player) => SizedBox(
                                width: math.min(playerWidth, width),
                                child: compact
                                    ? Row(
                                        children: [
                                          PrivateTournamentAvatar(
                                            avatar: player.avatarUrl,
                                            size: avatarSize,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _name(player.username, 12),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PrivateTournamentAvatar(
                                            avatar: player.avatarUrl,
                                            size: avatarSize,
                                          ),
                                          const SizedBox(height: 10),
                                          _name(player.username, 14),
                                        ],
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _name(String name, double size) => Text(
    name,
    textAlign: TextAlign.center,
    style: TextStyle(color: const Color(0xFFF7EFD9), fontSize: size),
  );
}
