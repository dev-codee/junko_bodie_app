/// Strategy Navigator / Debugger — replicates the web /strategies/debug page.
///
/// Steps through a strategy one spin at a time against the ported
/// [SimulationEngine], showing live KPIs, the active bets for the current spin,
/// and a running spin log. Also lets the user force a specific wheel result and
/// edit the strategy's notes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/strategy_service.dart';
import 'package:junko_bodie/services/strategy_prefs.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_help_button.dart';
import 'package:junko_bodie/tour/tour_registry.dart';
import 'package:junko_bodie/widgets/junko_tip_card.dart';

const Color _kInk = Color(0xFF0F2E21);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);
const Color _kTeal = Color(0xFF3FD1B4);
const Color _kLoss = Color(0xFFFF7B7B);

class _LogEntry {
  final int id;
  final int spinNumber;
  final String result;
  final double netResult;
  final int stage;
  final String action;
  final double bankroll;
  final String type; // win | loss | info | neutral
  final double? sessionProfitBanked;
  final double? resetBalance;

  _LogEntry({
    required this.id,
    required this.spinNumber,
    required this.result,
    required this.netResult,
    required this.stage,
    required this.action,
    required this.bankroll,
    required this.type,
    this.sessionProfitBanked,
    this.resetBalance,
  });
}

class StrategyDebuggerScreen extends StatefulWidget {
  final String? strategyId;
  const StrategyDebuggerScreen({super.key, this.strategyId});

  @override
  State<StrategyDebuggerScreen> createState() => _StrategyDebuggerScreenState();
}

class _StrategyDebuggerScreenState extends State<StrategyDebuggerScreen> {
  final StrategyService _service = StrategyService();
  final _forcedController = TextEditingController();
  final _notesController = TextEditingController();
  final _bankrollController = TextEditingController(text: '3500');
  final _missesController = TextEditingController(text: '1');
  final ScrollController _logScroll = ScrollController();

  List<BettingStrategy> _strategies = [];
  String _selectedId = '';
  double _startingBankroll = 3500;
  bool _resetBankroll = true;
  String _entryTrigger = 'immediate';
  int _missesRequired = 1;
  bool _isLoading = true;
  bool _isSavingNotes = false;

  bool _sessionStarted = false;
  SimulationEngine? _engine;
  SimulationState? _liveState;
  List<_LogEntry> _log = [];
  int _spinCounter = 0;

  TourController? _tour;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
    _tour = context.read<TourController>();
    _tour!.addListener(_syncTour);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTour());
  }

  /// Registers the funnel validator for the active debugger step.
  void _syncTour() {
    if (!mounted) return;
    final tour = _tour;
    if (tour == null) return;
    final step = tour.isActive ? tour.currentStep : null;
    if (step == null || step.route != '/strategies/debug') return;

    if (step.id == 'debug_force_number') {
      // Force spin result is optional — the user can enter a number or tap Next.
      tour.setStepValidator(() => ValidatorResult.ok, isCompleted: true);
    } else {
      tour.setStepValidator(null);
    }
  }

  /// Funnel "Start Debug Session" click-through (step debug_start).
  void _handleStartTap() {
    _start();
    if (_tour?.currentStep?.id == 'debug_start') {
      _tour?.advanceStep('debug_start');
    }
  }

  /// Funnel "SPIN" click-through (step debug_spin).
  void _handleSpinTap() {
    _spin();
    if (_tour?.currentStep?.id == 'debug_spin') {
      _tour?.advanceStep('debug_spin');
    }
  }

  /// Funnel "Test in Simulator" click-through (step debug_to_sim).
  void _handleSimulateTap() {
    if (_tour?.currentStep?.id == 'debug_to_sim') {
      _tour?.advanceStep('debug_to_sim');
    }
    final id = _selectedId;
    context.push(id.isNotEmpty
        ? '/simulation/setup?strategyId=$id'
        : '/simulation/setup');
  }

  @override
  void dispose() {
    _tour?.removeListener(_syncTour);
    _forcedController.dispose();
    _notesController.dispose();
    _bankrollController.dispose();
    _missesController.dispose();
    _logScroll.dispose();
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
          _selectedId = match.isNotEmpty
              ? match.first.id!
              : (list.first.id ?? '');
          _notesController.text = _selected?.strategyNotes ?? '';
        }
        _isLoading = false;
      });
      if (_selectedId.isNotEmpty) {
        await StrategyPrefs.setLastActive(_selectedId);
      }
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

  void _start() {
    final strategy = _selected;
    if (strategy == null) return;
    final config = SimulationConfig(
      requestedSpins: 999999,
      startingBankroll: _startingBankroll,
      resetBankrollOnSessionEnd: _resetBankroll,
      entryTrigger: _entryTrigger,
      missesRequired: _missesRequired,
    );
    final engine = SimulationEngine(strategy, config);
    setState(() {
      _engine = engine;
      _liveState = engine.getInternalState();
      _log = [];
      _spinCounter = 0;
      _sessionStarted = true;
    });
  }

  void _spin() {
    final engine = _engine;
    if (engine == null) return;

    final forced = _forcedController.text.trim();
    final forceNum = forced.isEmpty ? null : int.tryParse(forced);

    final before = engine.getInternalState();
    if (before.activeBankroll <= 0) return;

    engine.runChunk(1, forcedNumber: forceNum);

    final after = engine.getInternalState();
    final spin = engine.lastSpinResult;
    final payout = engine.lastPayoutResult;
    final action = engine.lastBaselineAction;
    final counter = _spinCounter + 1;

    final net = payout?.netResult ?? 0;
    final color = spin?.color ?? '';
    final displayNum = spin?.displayNumber ?? '?';
    final type = net > 0 ? 'win' : (net < 0 ? 'loss' : 'neutral');

    final actionLabel = _actionLabel(action, after, net);

    final sessionJustCompleted =
        after.totalCompletedSessions > before.totalCompletedSessions;
    final endedSuffix =
        sessionJustCompleted && before.isSessionActive ? ' 🔚' : '';

    setState(() {
      _spinCounter = counter;
      _liveState = after;
      _log.add(_LogEntry(
        id: counter,
        spinNumber: counter,
        result: '$displayNum $color',
        netResult: net.toDouble(),
        stage: !before.isSessionActive ? 1 : before.currentStageIndex + 1,
        action: '$actionLabel$endedSuffix',
        bankroll: after.activeBankroll,
        type: sessionJustCompleted ? 'info' : type,
        sessionProfitBanked: (sessionJustCompleted && _resetBankroll)
            ? after.sessionProfit
            : null,
        resetBalance:
            (sessionJustCompleted && _resetBankroll) ? _startingBankroll : null,
      ));
      _forcedController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _actionLabel(String action, SimulationState after, num net) {
    if (after.activeBankroll <= 0) return 'BUST — Bankroll exhausted';
    switch (action) {
      case 'next':
        return 'LOSS — moved to Stage ${after.currentStageIndex + 1}';
      case 'reset':
        return net >= 0 ? 'WIN — session complete ✓' : 'STOP — session ended';
      case 'repeat':
        return 'REPEAT — same stage next spin';
      case 'recovery':
        return '⚡ RECOVERY ACTIVE — retrying bets';
      case 'stop':
        return 'STOP LOSS hit — session ended';
      case 'push':
        return 'BREAK EVEN — treated as win ✓';
      default:
        if (action.startsWith('jump_')) {
          return 'JUMP → Stage ${action.split('_')[1]}';
        }
        return action.isEmpty ? 'N/A' : action.toUpperCase();
    }
  }

  void _reset() {
    setState(() {
      _engine = null;
      _liveState = null;
      _log = [];
      _spinCounter = 0;
      _sessionStarted = false;
      _forcedController.clear();
    });
  }

  Future<void> _saveNotes() async {
    if (_selectedId.isEmpty) return;
    setState(() => _isSavingNotes = true);
    try {
      await _service.updateStrategyNotes(_selectedId, _notesController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes saved'),
            backgroundColor: _kInk,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save notes: $e'),
            backgroundColor: const Color(0xFFC0392B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTour();
    });
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
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: JunkoTipCard(
                          title: 'Navigator Pre-Test',
                          text:
                              '"I use this Navigator feature to do a quick test of 200 spins or so to make sure my New Strategy setup doesn\'t have any obvious flaws. Think of it as a pre-test before you submit to the Simulation Engine for grading and more thorough testing. If you are using the Web version of JBR, note that the spacebar also acts as a spin trigger for faster paced testing."',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _sessionStarted
                              ? _buildLiveSession()
                              : _buildSetup(),
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
        _navPill('LIBRARY', Icons.arrow_back, () => context.go('/strategies')),
        const SizedBox(width: 8),
        const TourHelpButton(tourId: 'debugger'),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Strategy Navigator',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: _kInkText,
              ),
            ),
          ],
        ),
        if (_sessionStarted) ...[
          const SizedBox(width: 16),
          TourTarget(
            id: 'funnel-simulate-btn',
            child: GestureDetector(
            onTap: _handleSimulateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _kInk,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, size: 15, color: _kGold),
                  const SizedBox(width: 6),
                  Text('TEST IN SIMULATOR',
                      style: GoogleFonts.inter(
                          color: _kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _kLoss.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: _kLoss.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restart_alt,
                      size: 15, color: Color(0xFFC0392B)),
                  const SizedBox(width: 6),
                  Text('END SESSION',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFC0392B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navPill(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kInkText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kInkText.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _kInkText),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _kInkText)),
          ],
        ),
      ),
    );
  }

  // ── Setup ───────────────────────────────────────────────────────────────────
  Widget _buildSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card([
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: _kInk),
              const SizedBox(width: 8),
              Text('Configure Navigation Session',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kInkText)),
            ],
          ),
          const SizedBox(height: 14),
          if (_strategies.isEmpty)
            Text(
              'No saved strategies yet. Build one first in the Strategy Library.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: _kGoldDark),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final twoCol = c.maxWidth > 640;
              final fields = <Widget>[
                TourTarget(
                    id: 'select-strategy',
                    child: _field('Select Strategy to Navigate',
                        _strategyDropdown())),
                TourTarget(
                    id: 'bankroll-config',
                    child: _field('Starting Bankroll (\$)', _bankrollField())),
                TourTarget(
                    id: 'session-entry-rule',
                    child: _field('Session Entry Rule', _entryDropdown())),
                if (_entryTrigger == 'x_misses')
                  _field('Phantom Misses Required', _missesField()),
              ];
              if (!twoCol) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in fields)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12), child: f),
                  ],
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final f in fields)
                    SizedBox(width: (c.maxWidth - 16) / 2, child: f),
                ],
              );
            }),
          const SizedBox(height: 8),
          _instructions(),
          const SizedBox(height: 14),
          _startButton(),
        ]),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          _buildNotesCard(),
        ],
      ],
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _kGoldDark,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _strategyDropdown() {
    return _dropdownBox(
      DropdownButton<String>(
        value: _selectedId.isEmpty ? null : _selectedId,
        isDense: true,
        isExpanded: true,
        dropdownColor: const Color(0xFFF5EDD5),
        underline: const SizedBox.shrink(),
        style: const TextStyle(
            color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
        items: _strategies
            .map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.name}${s.isGlobal ? ' 🌍' : ''} (${s.wheelType})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _selectedId = v;
            _notesController.text = _selected?.strategyNotes ?? '';
          });
          StrategyPrefs.setLastActive(v);
        },
      ),
    );
  }

  Widget _entryDropdown() {
    return _dropdownBox(
      DropdownButton<String>(
        value: _entryTrigger,
        isDense: true,
        isExpanded: true,
        dropdownColor: const Color(0xFFF5EDD5),
        underline: const SizedBox.shrink(),
        style: const TextStyle(
            color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
        items: const [
          DropdownMenuItem(
              value: 'immediate', child: Text('Start Betting Immediately')),
          DropdownMenuItem(
              value: 'x_misses', child: Text('Wait for X Phantom Misses')),
        ],
        onChanged: (v) => setState(() => _entryTrigger = v ?? 'immediate'),
      ),
    );
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

  Widget _bankrollField() {
    return _numberInput(
      _bankrollController,
      (v) {
        final n = double.tryParse(v);
        if (n != null) setState(() => _startingBankroll = n);
      },
      trailing: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => setState(() => _resetBankroll = !_resetBankroll),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _resetBankroll,
                  onChanged: (v) => setState(() => _resetBankroll = v ?? false),
                  activeColor: _kInk,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bank Profits (reset to starting bankroll on new session)',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _kGoldDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missesField() {
    return _numberInput(_missesController, (v) {
      final n = int.tryParse(v);
      if (n != null && n >= 1) setState(() => _missesRequired = n);
    });
  }

  Widget _numberInput(
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
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
        ),
        ?trailing,
      ],
    );
  }

  Widget _instructions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kInk.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to use the Navigator',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kInk)),
          const SizedBox(height: 6),
          _bullet('Select a strategy and tap Start Navigation Session.'),
          _bullet('Tap SPIN to step through one spin at a time.'),
          _bullet(
              'Optionally enter a number in Force Result to test a specific outcome (e.g. 17).'),
          _bullet(
              'The Spin Log records every spin, its payout, and the engine action.'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ',
              style: TextStyle(color: _kGoldDark, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGoldDark)),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    final enabled = _selectedId.isNotEmpty && _strategies.isNotEmpty;
    return TourTarget(
      id: 'funnel-start-debug',
      child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? _handleStartTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow, size: 18, color: _kGold),
              const SizedBox(width: 8),
              Text('START NAVIGATION SESSION',
                  style: GoogleFonts.inter(
                      color: _kGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNotesCard() {
    return _card([
      Row(
        children: [
          const Icon(Icons.notes, size: 18, color: _kInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Strategy Notes',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInkText)),
          ),
          GestureDetector(
            onTap: _isSavingNotes ? null : _saveNotes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_isSavingNotes ? 'Saving...' : 'Save Notes',
                  style: GoogleFonts.inter(
                      color: _kInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notesController,
        maxLines: 5,
        style: const TextStyle(
            color: _kInkText, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.6),
          hintText:
              'Add background, appropriate use, testing recommendations, and progression variations...',
          hintStyle:
              TextStyle(color: _kInkText.withValues(alpha: 0.35), fontSize: 12),
          contentPadding: const EdgeInsets.all(12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kGold, width: 1.5),
          ),
        ),
      ),
    ]);
  }

  // ── Live session ────────────────────────────────────────────────────────────
  Widget _buildLiveSession() {
    final state = _liveState;
    final strategy = _selected;
    if (state == null || strategy == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TourTarget(id: 'live-metrics', child: _kpiRow(state)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final twoCol = c.maxWidth > 640;
          final controls = _controlsCard(state, strategy);
          final bets = _activeBetsCard(state);
          if (!twoCol) {
            return Column(children: [
              controls,
              const SizedBox(height: 12),
              bets,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: controls),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: bets),
            ],
          );
        }),
        const SizedBox(height: 12),
        TourTarget(id: 'spin-log', child: _spinLogCard()),
        // SPIN button anchored directly below the results so the most recent
        // spin (auto-scrolled to the bottom of the log) sits right above it —
        // no scrolling back up to spin again on mobile.
        const SizedBox(height: 10),
        _spinButton(state),
      ],
    );
  }

  Widget _spinButton(SimulationState s) {
    final busted = s.activeBankroll <= 0;
    return TourTarget(
      id: 'funnel-spin-button',
      child: GestureDetector(
        onTap: busted ? null : _handleSpinTap,
        child: Opacity(
          opacity: busted ? 0.5 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D0F2E21),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(busted ? Icons.block : Icons.play_arrow,
                    size: 20, color: _kGold),
                const SizedBox(width: 8),
                Text(busted ? 'SESSION BUSTED (\$0)' : 'SPIN',
                    style: GoogleFonts.inter(
                        color: _kGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiRow(SimulationState s) {
    Widget tile(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _kGoldDark,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
    }

    final pnlColor = s.sessionProfit >= 0 ? _kInk : const Color(0xFFC0392B);
    final bankColor =
        s.totalAggregatedProfit >= 0 ? _kInk : const Color(0xFFC0392B);
    final brollColor =
        s.activeBankroll >= _startingBankroll ? _kInk : const Color(0xFFC0392B);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        tile('Bankroll', '\$${_fmt(s.activeBankroll)}', brollColor),
        tile('Session P&L',
            '${s.sessionProfit >= 0 ? '+' : ''}\$${_fmt(s.sessionProfit)}',
            pnlColor),
        tile('Total Banked',
            '${s.totalAggregatedProfit >= 0 ? '+' : ''}\$${_fmt(s.totalAggregatedProfit)}',
            bankColor),
        tile('Active Stage',
            s.isSessionActive ? 'Stage ${s.currentStageIndex + 1}' : '—',
            _kGoldDark),
        tile('Total Spins', '${s.totalSpinsExecuted}', _kInkText),
      ],
    );
  }

  Widget _controlsCard(SimulationState s, BettingStrategy strategy) {
    return _card([
      Row(
        children: [
          const Icon(Icons.bolt, size: 16, color: _kInk),
          const SizedBox(width: 6),
          Text('Spin Controls',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInkText)),
        ],
      ),
      const SizedBox(height: 12),
      TourTarget(
        id: 'funnel-force-result',
        child: _field(
        'Force Spin Result (optional)',
        TextField(
          controller: _forcedController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
              color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            hintText: '0–36, or 37 for 00',
            hintStyle: TextStyle(
                color: _kInkText.withValues(alpha: 0.35), fontSize: 12),
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
        ),
      ),
      ),
      const SizedBox(height: 12),
      Divider(color: _kInk.withValues(alpha: 0.12)),
      const SizedBox(height: 8),
      Text('STRATEGY',
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _kGoldDark,
              letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(strategy.name,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
      Text('${strategy.wheelType} · ${strategy.stages.length} stage(s)',
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kGoldDark)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kInk.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sessions completed',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGoldDark)),
            Text('${s.totalCompletedSessions}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kInk)),
          ],
        ),
      ),
    ]);
  }

  Widget _activeBetsCard(SimulationState s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag, size: 15, color: _kGold),
              const SizedBox(width: 6),
              Text('Active Bets This Spin',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kGold)),
            ],
          ),
          const SizedBox(height: 10),
          if (s.isSessionActive && s.currentActiveBets.isNotEmpty)
            Column(
              children: [
                Row(
                  children: [
                    _cell('Position', flex: 3, header: true),
                    _cell('Amount', flex: 2, header: true),
                    _cell('Group', flex: 2, header: true),
                  ],
                ),
                const SizedBox(height: 4),
                ...s.currentActiveBets.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          _cell(b.position, flex: 3),
                          _cell('\$${b.amount}', flex: 2),
                          _cell(b.groupId ?? '—', flex: 2, faint: true),
                        ],
                      ),
                    )),
              ],
            )
          else
            Text(
              s.isSessionActive
                  ? 'No bets placed yet.'
                  : 'Session not yet active — waiting for entry trigger.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withValues(alpha: 0.4)),
            ),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {int flex = 1, bool header = false, bool faint = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: header ? 10 : 12,
          fontWeight: header ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: header ? 0.5 : 0,
          color: header
              ? _kGold
              : (faint
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white),
        ),
      ),
    );
  }

  Widget _spinLogCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 15, color: _kGold),
              const SizedBox(width: 6),
              Text('Spin Log',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kGold)),
              const Spacer(),
              Text('${_log.length} spin${_log.length != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _log.isEmpty
                ? Center(
                    child: Text(
                      'Session started. No spins executed yet — tap SPIN to begin.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.builder(
                    controller: _logScroll,
                    itemCount: _log.length,
                    itemBuilder: (context, i) => _logRow(_log[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(_LogEntry e) {
    Color bg;
    switch (e.type) {
      case 'win':
        bg = _kTeal.withValues(alpha: 0.12);
        break;
      case 'loss':
        bg = _kLoss.withValues(alpha: 0.12);
        break;
      case 'info':
        bg = _kGold.withValues(alpha: 0.12);
        break;
      default:
        bg = Colors.white.withValues(alpha: 0.04);
    }

    if (e.spinNumber == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(e.action,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8))),
      );
    }

    final netColor = e.netResult > 0
        ? _kTeal
        : (e.netResult < 0 ? _kLoss : Colors.white.withValues(alpha: 0.6));

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('#${e.spinNumber}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          SizedBox(
            width: 54,
            child: Text(e.result,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          SizedBox(
            width: 52,
            child: Text('${e.netResult > 0 ? '+' : ''}${_fmt(e.netResult)}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: netColor)),
          ),
          Expanded(
            child: Text('Stage ${e.stage} · ${e.action}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55))),
          ),
          Text('\$${_fmt(e.bankroll)}',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  String _fmt(num v) {
    final isNeg = v < 0;
    final abs = v.abs();
    final rounded = abs == abs.roundToDouble()
        ? abs.toInt().toString()
        : abs.toStringAsFixed(2);
    // Thousands separators.
    final parts = rounded.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final out = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return isNeg ? '-$out' : out;
  }
}
