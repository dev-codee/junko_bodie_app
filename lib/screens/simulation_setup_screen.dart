/// Simulation Setup — replicates the web /simulation/setup page.
///
/// Pick a saved strategy and engine parameters (spins, bankroll, entry rule),
/// then run a mass backtest via the ported [SimulationEngine].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/screens/simulation_run_screen.dart';
import 'package:junko_bodie/services/strategy_service.dart';
import 'package:junko_bodie/services/strategy_prefs.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_registry.dart';
import 'package:junko_bodie/widgets/junko_tip_card.dart';

const Color _kInk = Color(0xFF0F2E21);
// Deep ink used by the web grade card / dark header pills (#0A2218).
const Color _kGradeCardInk = Color(0xFF0A2218);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);

class SimulationSetupScreen extends StatefulWidget {
  final String? strategyId;
  const SimulationSetupScreen({super.key, this.strategyId});

  @override
  State<SimulationSetupScreen> createState() => _SimulationSetupScreenState();
}

class _SimulationSetupScreenState extends State<SimulationSetupScreen> {
  final StrategyService _service = StrategyService();
  final _spinsController = TextEditingController(text: '100');
  final _bankrollController = TextEditingController(text: '5000');
  final _missesController = TextEditingController(text: '1');

  List<BettingStrategy> _strategies = [];
  String _selectedId = '';
  int _requestedSpins = 100;
  double _startingBankroll = 5000;
  bool _resetBankroll = false;
  String _entryTrigger = 'immediate';
  int _missesRequired = 1;
  bool _isLoading = true;

  /// Junko's Tip is collapsed by default and revealed via the header "TIP" pill.
  bool _showTip = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  @override
  void dispose() {
    _spinsController.dispose();
    _bankrollController.dispose();
    _missesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchStrategies();
      // Prefer the explicit query id, else the last created/active strategy.
      final preferredId = widget.strategyId ?? await StrategyPrefs.preferredId();
      if (!mounted) return;
      setState(() {
        _strategies = list;
        if (list.isNotEmpty) {
          final match = preferredId != null
              ? list.where((s) => s.id == preferredId).toList()
              : <BettingStrategy>[];
          _selectedId = match.isNotEmpty ? match.first.id! : (list.first.id ?? '');
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  BettingStrategy? get _selected {
    for (final s in _strategies) {
      if (s.id == _selectedId) return s;
    }
    return null;
  }

  void _run() {
    final strategy = _selected;
    if (strategy == null) return;
    // Funnel "EXECUTE ENGINE" click-through (step sim_run).
    final tour = context.read<TourController>();
    if (tour.currentStep?.id == 'sim_run') {
      tour.advanceStep('sim_run');
    }
    final config = SimulationConfig(
      requestedSpins: _requestedSpins.clamp(10, 25000),
      startingBankroll: _startingBankroll,
      resetBankrollOnSessionEnd: _resetBankroll,
      entryTrigger: _entryTrigger,
      missesRequired: _missesRequired,
    );
    context.push('/simulation/run',
        extra: SimulationRunArgs(config: config, strategy: strategy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9E7F41),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFFFFDCA3), Color(0xFFDABB8B), Color(0xFF9E7F41)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _kInk, strokeWidth: 3),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      if (_showTip) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: JunkoTipCard(
                            title: 'Strategy Entry Advice',
                            text:
                                '"Strategy entry points are extremely important. The more misses your strategy has before you start your betting, the more time you have bought your system. In Roulette, time is everything. Be sure to consider this option carefully as you test your systems."',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: LayoutBuilder(builder: (context, c) {
                            final twoCol = c.maxWidth > 720;
                            final cards = [
                              _strategyCard(),
                              _paramsCard(),
                            ];
                            if (!twoCol) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  cards[0],
                                  const SizedBox(height: 12),
                                  cards[1],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[1]),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _navPill('STRATEGIES', Icons.arrow_back, () => context.go('/strategies')),
        const SizedBox(width: 8),
        _navPill(
          'TIP',
          _showTip ? Icons.lightbulb : Icons.lightbulb_outline,
          () => setState(() => _showTip = !_showTip),
          active: _showTip,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Simulation Engine',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: _kInkText)),
          ],
        ),
        const SizedBox(width: 16),
        _runButton(),
      ],
    );
  }

  /// Header pill. When [active] it mirrors the web gold-gradient
  /// `.returnLibBtn`; otherwise the dark-green gold-outline `.backBtn`.
  Widget _navPill(String label, IconData icon, VoidCallback onTap,
      {bool active = false}) {
    final Color fg = active ? _kGradeCardInk : _kGold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? null : _kGradeCardInk,
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kGold, Color(0xFFECD08C)],
                )
              : null,
          borderRadius: BorderRadius.circular(9999),
          border: active
              ? null
              : Border.all(color: _kGold.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: active
                  ? _kGold.withValues(alpha: 0.35)
                  : const Color(0x26000000),
              blurRadius: active ? 14 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: 1,
                    color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _runButton() {
    final enabled = _selectedId.isNotEmpty && _strategies.isNotEmpty;
    return TourTarget(
      id: 'funnel-run-simulation',
      child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? _run : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x660F2E21),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, size: 17, color: _kGold),
              const SizedBox(width: 8),
              Text('EXECUTE ENGINE',
                  style: GoogleFonts.inter(
                      color: _kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _card(IconData icon, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _kGold),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInkText)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _kGoldDark,
                letterSpacing: 1)),
      );

  Widget _strategyCard() {
    return _card(Icons.storage, 'Select Strategy', [
      _label('Choose a Saved Strategy'),
      if (_strategies.isEmpty)
        Text('No saved strategies found. Create one in the Strategy Library.',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: _kGoldDark))
      else
        TourTarget(
          id: 'sim-strategy-select',
          child: _dropdownBox(DropdownButton<String>(
            value: _selectedId.isEmpty ? null : _selectedId,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFFF5EDD5),
            style: const TextStyle(
                color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
            items: _strategies
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.wheelType})',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedId = v ?? ''),
          )),
        ),
      const SizedBox(height: 20),
      _label('Session Entry Rule'),
      TourTarget(
        id: 'sim-entry-rule',
        child: _dropdownBox(DropdownButton<String>(
          value: _entryTrigger,
          isDense: true,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(0xFFF5EDD5),
          style: const TextStyle(
              color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
          items: const [
            DropdownMenuItem(
                value: 'immediate', child: Text('Start Betting Immediately')),
            DropdownMenuItem(
                value: 'x_misses',
                child: Text('Wait for Specific Misses (Phantom Betting)')),
          ],
          onChanged: (v) => setState(() => _entryTrigger = v ?? 'immediate'),
        )),
      ),
      if (_entryTrigger == 'x_misses') ...[
        const SizedBox(height: 12),
        _label("Consecutive 'Stage 1' misses required"),
        _numberInput(_missesController, (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 1) setState(() => _missesRequired = n);
        }),
      ],
    ]);
  }

  Widget _paramsCard() {
    return _card(Icons.settings, 'Engine Parameters', [
      _label('Requested Spins (max 25,000)'),
      TourTarget(
        id: 'sim-spins-config',
        child: _numberInput(_spinsController, (v) {
          var n = int.tryParse(v) ?? 0;
          if (n > 25000) n = 25000;
          setState(() => _requestedSpins = n);
        }),
      ),
      const SizedBox(height: 6),
      Text(
        'The simulation finishes an active session before stopping, so actual '
        'spins may slightly exceed the target.',
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kGoldDark),
      ),
      const SizedBox(height: 16),
      TourTarget(
        id: 'sim-bankroll-config',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Starting Bankroll (\$)'),
            _numberInput(_bankrollController, (v) {
              final n = double.tryParse(v);
              if (n != null) setState(() => _startingBankroll = n);
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _resetBankroll = !_resetBankroll),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _resetBankroll,
                      onChanged: (v) =>
                          setState(() => _resetBankroll = v ?? false),
                      activeColor: _kInk,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reset bankroll to the starting amount at the beginning of each new session.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kInkText),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: Text(
                'Leave unchecked to compound continuously across all sessions.',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kGoldDark),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _dropdownBox(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _numberInput(
      TextEditingController controller, ValueChanged<String> onChanged) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      // The numeric keyboard has no return key on mobile, so give the user an
      // explicit "done" action and dismiss the keyboard when they tap away.
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: const TextStyle(
          color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }
}
