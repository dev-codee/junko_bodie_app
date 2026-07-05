import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/providers/game_provider.dart';
import 'package:junko_bodie/services/strategy_service.dart';

const Color _kGold = Color(0xFFC9A44C);

/// Strategy (staged-betting) selector — the "Target" icon in the game header
/// plus the strategy-picker dialog. Ports the web's StagedBettingSelector.
class StagedBettingSelector extends StatelessWidget {
  const StagedBettingSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final bool enabled = provider.stagedBettingEnabled;

    return IconButton(
      onPressed: () {
        soundEngine.playClick();
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (_) => ChangeNotifierProvider<GameProvider>.value(
            value: provider,
            child: const _StrategyDialog(),
          ),
        );
      },
      icon: Icon(
        Icons.track_changes,
        color: enabled ? _kGold : const Color(0xFFF5EDD5),
        size: 22,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Betting Strategy',
    );
  }
}

class _StrategyDialog extends StatefulWidget {
  const _StrategyDialog();

  @override
  State<_StrategyDialog> createState() => _StrategyDialogState();
}

class _StrategyDialogState extends State<_StrategyDialog> {
  final StrategyService _service = StrategyService();
  List<BettingStrategy> _strategies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStrategies();
  }

  Future<void> _fetchStrategies() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchStrategies();
      if (mounted) setState(() => _strategies = list);
    } catch (e) {
      debugPrint('StagedBettingSelector: fetch failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectStrategy(GameProvider provider, BettingStrategy strategy) {
    provider.setActiveStrategy(strategy);
    provider.setCurrentStageIndex(0);
    provider.setStagedBettingEnabled(true);
    if (strategy.stages.isNotEmpty) {
      provider.applyStageBets(strategy.stages.first.bets);
    }
    Navigator.of(context).pop();
  }

  void _disableStrategy(GameProvider provider) {
    provider.setStagedBettingEnabled(false);
    provider.setActiveStrategy(null);
    provider.setCurrentStageIndex(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final active = provider.activeStrategy;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 340),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (active != null) _buildActiveCard(provider, active),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
                      child: Text(
                        'AVAILABLE STRATEGIES',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildList(provider, active),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _kGold.withOpacity(0.25), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategies',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Auto-Betting Stages',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(GameProvider provider, BettingStrategy active) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGold.withOpacity(0.06),
        border: Border.all(color: _kGold.withOpacity(0.25), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active: ${active.name}',
                      style: GoogleFonts.inter(
                        color: _kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Stage ${provider.currentStageIndex + 1} of ${active.stages.length}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _disableStrategy(provider),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3C3C).withOpacity(0.1),
                  foregroundColor: const Color(0xFFFF6B6B),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFFFF3C3C).withOpacity(0.2)),
                  ),
                ),
                child: Text(
                  'Disable',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final stage = active.stages[provider.currentStageIndex];
                provider.applyStageBets(stage.bets);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'APPLY CURRENT STAGE BETS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(GameProvider provider, BettingStrategy? active) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _kGold),
          ),
        ),
      );
    }

    if (_strategies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No strategies found. Create one in the Strategy Library.',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: _strategies.map((s) {
        final bool isActive = active?.id == s.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${s.stages.length} stages • ${s.wheelType}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isActive ? null : () => _selectStrategy(provider, s),
                style: TextButton.styleFrom(
                  backgroundColor:
                      isActive ? _kGold : Colors.white.withOpacity(0.1),
                  foregroundColor: isActive ? const Color(0xFF111111) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isActive ? 'Active' : 'Select',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGold,
            foregroundColor: const Color(0xFF111111),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'DONE',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
