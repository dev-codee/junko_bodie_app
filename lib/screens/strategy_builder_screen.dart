/// Strategy Builder — replicates the web /strategies/build page.
///
/// Lets the user create/edit a staged betting strategy: set name, wheel type,
/// description; place chips on the interactive felt per stage; tag bets into
/// groups; configure per-stage win/loss actions and safety/profit rules; add
/// advanced dynamic rules; set a global End-Game Recovery rule; write strategy
/// notes; and save (POST/PUT) to the backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/strategy_service.dart';
import 'package:junko_bodie/services/strategy_prefs.dart';
import 'package:junko_bodie/widgets/betting_layout.dart';
import 'package:junko_bodie/widgets/chip_tray.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_registry.dart';

// ─── Palette (matches the gold/cream builder page) ──
const Color _kInk = Color(0xFF0F2E21);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);
const Color _kTeal = Color(0xFF3FD1B4);
const Color _kLoss = Color(0xFFD9534F);

/// Deterministic color per group tag letter (hex string, no leading #).
const List<String> _groupPalette = [
  '3FD1B4', // A
  'F59E0B', // B
  'EF4444', // C
  '8B5CF6', // D
  '3B82F6', // E
  'EC4899', // F
  '10B981', // G
  'F97316', // H
];

String _groupColorHex(String letter) {
  if (letter.isEmpty) return _groupPalette[0];
  final idx = (letter.codeUnitAt(0) - 65) % _groupPalette.length;
  return _groupPalette[idx.abs()];
}

Color _hexColor(String hex) => Color(int.parse('0xFF${hex.replaceAll('#', '')}'));

class StrategyBuilderScreen extends StatefulWidget {
  final String? strategyId;
  const StrategyBuilderScreen({super.key, this.strategyId});

  @override
  State<StrategyBuilderScreen> createState() => _StrategyBuilderScreenState();
}

class _StrategyBuilderScreenState extends State<StrategyBuilderScreen> {
  final StrategyService _service = StrategyService();

  final _nameController = TextEditingController(text: 'New Strategy');
  final _descController = TextEditingController();
  final _notesController = TextEditingController();
  final _maxStagesController = TextEditingController(text: '30');
  final _recoveryPosController = TextEditingController();

  // Horizontal scroll for the (widened) betting board.
  final _boardScroll = ScrollController();

  String? _strategyId;
  String _wheelType = 'American';
  int _maxStages = 30;
  bool _isGlobal = false;
  String? _savedStrategyId;

  // Global End-Game Recovery.
  final EndgameRecoveryConfig _recovery = EndgameRecoveryConfig();
  num _recoverySelectedChip = 10;

  // Stages (working copies of the model — fields are mutable).
  List<StrategyStage> _stages = [
    StrategyStage(
      stageNumber: 1,
      bets: [],
      totalWager: 0,
      onWin: 'reset',
      onLoss: 'next',
    ),
  ];
  int _activeIndex = 0;
  double _selectedChip = 5;

  // Group tagging.
  String _activeGroupId = 'none';
  bool _tagOnlyMode = true;
  List<String> _customGroups = ['A', 'B', 'C'];

  // Per-stage undo history (reset on stage change).
  final List<List<StageBet>> _history = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSaved = false;

  // Onboarding funnel wiring.
  TourController? _tour;
  bool _tourChipTouched = false;

  static const List<double> _denoms = [1000, 500, 100, 25, 10, 5, 2, 1];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _strategyId = widget.strategyId;
    if (_strategyId != null && _strategyId!.isNotEmpty) {
      _loadStrategy();
    }
    // Register funnel validators as the active step changes.
    _tour = context.read<TourController>();
    _tour!.addListener(_syncTour);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTour());
  }

  @override
  void dispose() {
    _tour?.removeListener(_syncTour);
    _nameController.dispose();
    _descController.dispose();
    _notesController.dispose();
    _maxStagesController.dispose();
    _recoveryPosController.dispose();
    _boardScroll.dispose();
    super.dispose();
  }

  /// Registers the correct live validator + completion state for whichever
  /// funnel step is currently active on the builder route.
  void _syncTour() {
    if (!mounted) return;
    final tour = _tour;
    if (tour == null) return;
    final step = tour.isActive ? tour.currentStep : null;
    if (step == null || step.route != '/strategies/build') return;

    ValidatorResult fail() => ValidatorResult.fail(step.fallbackErrorMsg);

    switch (step.id) {
      case 'builder_name':
        bool ok() {
          final n = _nameController.text.trim();
          return n.isNotEmpty && n.toLowerCase() != 'new strategy';
        }
        tour.setStepValidator(
            () => ok() ? ValidatorResult.ok : fail(),
            isCompleted: ok());
        break;
      case 'builder_chip':
        tour.setStepValidator(
            () => _tourChipTouched ? ValidatorResult.ok : fail(),
            isCompleted: _tourChipTouched);
        break;
      case 'builder_place_bet':
      case 'builder_stage2_bet':
      case 'builder_stage3_bet':
        tour.setStepValidator(
            () => _active.bets.isNotEmpty ? ValidatorResult.ok : fail(),
            isCompleted: _active.bets.isNotEmpty);
        break;
      case 'builder_dynamic_rule':
        bool ok() => _active.dynamicRules?.isNotEmpty ?? false;
        tour.setStepValidator(
            () => ok() ? ValidatorResult.ok : fail(),
            isCompleted: ok());
        break;
      case 'builder_save':
        bool ok() => _savedStrategyId != null || _isSaved;
        tour.setStepValidator(
            () => ok() ? ValidatorResult.ok : fail(),
            isCompleted: ok());
        break;
      default:
        // Optional / informational steps advance freely.
        tour.setStepValidator(null);
    }
  }

  /// Funnel "+ Add Stage" click-through (steps builder_add_stage / _add_stage3).
  void _handleAddStageTap() {
    _addStage();
    final id = _tour?.currentStep?.id;
    if (id == 'builder_add_stage' || id == 'builder_add_stage3') {
      _tour?.advanceStep(id);
    }
  }

  /// Funnel "NAVIGATOR" click-through (step builder_navigator).
  void _handleNavigatorTap() {
    if (_tour?.currentStep?.id == 'builder_navigator') {
      _tour?.advanceStep('builder_navigator');
    }
    _openNavigator();
  }

  Future<void> _loadStrategy() async {
    setState(() => _isLoading = true);
    try {
      final s = await _service.fetchStrategyById(_strategyId!);
      if (s != null && mounted) {
        setState(() {
          _nameController.text = s.name;
          _descController.text = s.description ?? '';
          _notesController.text = s.strategyNotes ?? '';
          _wheelType = _normalizeWheel(s.wheelType);
          _maxStages = s.maxStages;
          _maxStagesController.text = s.maxStages.toString();
          _isGlobal = s.isGlobal;
          if (s.endgameRecovery != null) {
            _recovery
              ..enabled = s.endgameRecovery!.enabled
              ..recoveryBets = s.endgameRecovery!.recoveryBets
                  .map((b) => b.clone())
                  .toList()
              ..fallbackAmount = s.endgameRecovery!.fallbackAmount;
          }
          if (s.stages.isNotEmpty) {
            _stages = s.stages.map((st) => st.clone()).toList();
            // Rebuild the custom group list from tagged bets.
            final groups = <String>{'A', 'B', 'C'};
            for (final st in _stages) {
              for (final b in st.bets) {
                final g = b.groupId?.replaceAll('Group ', '').trim();
                if (g != null && g.isNotEmpty) groups.add(g);
              }
            }
            _customGroups = groups.toList()..sort();
          }
          _activeIndex = 0;
        });
      }
    } catch (_) {
      // Keep defaults on failure.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizeWheel(String w) {
    if (w == 'European') return 'European';
    if (w == 'Both') return 'Both';
    return 'American';
  }

  WheelType get _wheelEnum =>
      _wheelType == 'European' ? WheelType.european : WheelType.american;

  StrategyStage get _active => _stages[_activeIndex];
  num get _totalBankroll => _stages.fold<num>(0, (a, s) => a + s.totalWager);

  void _recalcWager(StrategyStage stage) {
    stage.totalWager = stage.bets.fold<num>(0, (a, b) => a + b.amount);
  }

  /// Break an amount into chip denominations (largest first) for a nice stack.
  List<double> _chipsFor(double amount) {
    final chips = <double>[];
    double rem = amount;
    for (final d in _denoms) {
      while (rem >= d - 0.0001) {
        chips.add(d);
        rem -= d;
      }
    }
    return chips.isEmpty ? [amount] : chips;
  }

  Map<String, PlacedBet> get _currentBetsMap {
    final map = <String, PlacedBet>{};
    for (final b in _active.bets) {
      final group = b.groupId;
      map[b.position] = PlacedBet(
        betId: b.position,
        amount: b.amount.toDouble(),
        chips: _chipsFor(b.amount.toDouble()),
        customColor: group != null ? _groupColorHex(group) : null,
        playerInitial: group,
      );
    }
    return map;
  }

  void _pushHistory() {
    _history.add(_active.bets.map((b) => b.clone()).toList());
  }

  // ── Bet placement (mirrors web handlePlaceBet) ──────────────────────────────
  void _placeBet(String betId) {
    setState(() {
      _pushHistory();
      final stage = _active;
      final idx = stage.bets.indexWhere((b) => b.position == betId);
      final tagged = _activeGroupId != 'none';

      final isTagOnlyExisting = _tagOnlyMode &&
          idx != -1 &&
          (tagged || stage.bets[idx].groupId != null);

      if (idx != -1) {
        final bet = stage.bets[idx];
        if (!isTagOnlyExisting) {
          bet.amount = bet.amount + _selectedChip;
        }
        bet.groupId = tagged ? _activeGroupId : null;
      } else {
        if (!isTagOnlyExisting) {
          stage.bets.add(StageBet(
            position: betId,
            amount: _selectedChip,
            groupId: tagged ? _activeGroupId : null,
          ));
        }
      }
      _recalcWager(stage);
    });
  }

  void _removeBet(String betId) {
    final idx = _active.bets.indexWhere((b) => b.position == betId);
    if (idx == -1) return;
    setState(() {
      _pushHistory();
      _active.bets.removeAt(idx);
      _recalcWager(_active);
    });
  }

  void _clearBoard() {
    if (_active.bets.isEmpty) return;
    setState(() {
      _pushHistory();
      _active.bets.clear();
      _recalcWager(_active);
    });
  }

  /// Merge the prior stage's bets into the current stage. Stage 2+ only.
  void _repeatBet() {
    if (_activeIndex == 0) return;
    final prev = _stages[_activeIndex - 1];
    if (prev.bets.isEmpty) return;
    setState(() {
      _pushHistory();
      final stage = _active;
      for (final pb in prev.bets) {
        final existing =
            stage.bets.where((b) => b.position == pb.position).toList();
        if (existing.isNotEmpty) {
          existing.first.amount += pb.amount;
          existing.first.groupId ??= pb.groupId;
        } else {
          stage.bets.add(pb.clone());
        }
      }
      _recalcWager(stage);
    });
  }

  void _doubleBet() {
    if (_active.bets.isEmpty) return;
    setState(() {
      _pushHistory();
      for (final b in _active.bets) {
        b.amount *= 2;
      }
      _recalcWager(_active);
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _active.bets = _history.removeLast();
      _recalcWager(_active);
    });
  }

  // ── Stage management ────────────────────────────────────────────────────────
  void _addStage() {
    if (_stages.length >= _maxStages) return;
    setState(() {
      _stages.add(StrategyStage(
        stageNumber: _stages.length + 1,
        bets: [],
        totalWager: 0,
        onWin: 'reset',
        onLoss: 'next',
      ));
      _activeIndex = _stages.length - 1;
      _history.clear();
    });
  }

  void _deleteStage(int idx) {
    if (_stages.length <= 1) return;
    setState(() {
      _stages.removeAt(idx);
      for (int i = 0; i < _stages.length; i++) {
        _stages[i].stageNumber = i + 1;
      }
      if (idx < _activeIndex) {
        _activeIndex -= 1;
      } else if (idx == _activeIndex) {
        _activeIndex = (_activeIndex - 1).clamp(0, _stages.length - 1);
      }
      _history.clear();
    });
  }

  void _selectStage(int idx) {
    setState(() {
      _activeIndex = idx;
      _history.clear();
    });
  }

  // ── Group tagging ───────────────────────────────────────────────────────────
  void _addGroup() {
    if (_customGroups.length >= 26) return;
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final next = alphabet.split('').firstWhere(
          (l) => !_customGroups.contains(l),
          orElse: () => 'A',
        );
    setState(() {
      _customGroups = [..._customGroups, next]..sort();
    });
  }

  void _removeGroup(String g) {
    setState(() {
      _customGroups.remove(g);
      if (_activeGroupId == g) _activeGroupId = 'none';
      for (final stage in _stages) {
        for (final b in stage.bets) {
          if (b.groupId == g) b.groupId = null;
        }
      }
    });
  }

  // ── Dynamic rules ───────────────────────────────────────────────────────────
  void _addDynamicRule() {
    setState(() {
      _active.dynamicRules ??= [];
      _active.dynamicRules!.add(DynamicRule(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        condition: RuleCondition.win,
        target: RuleTarget.allBets,
        action: RuleActionType.multiply,
        value: 2,
      ));
    });
  }

  void _removeDynamicRule(String id) {
    setState(() {
      _active.dynamicRules?.removeWhere((r) => r.id == id);
    });
  }

  // ── Recovery positions ──────────────────────────────────────────────────────
  void _addRecoveryPosition() {
    final val = _recoveryPosController.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _recovery.recoveryBets.removeWhere((b) => b.position == val);
      _recovery.recoveryBets
          .add(StageBet(position: val, amount: _recoverySelectedChip));
      _recoveryPosController.clear();
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final strategy = BettingStrategy(
      id: _strategyId,
      name: _nameController.text.trim().isEmpty
          ? 'New Strategy'
          : _nameController.text.trim(),
      wheelType: _wheelType,
      description: _descController.text.trim(),
      strategyNotes: _notesController.text.trim(),
      isActive: true,
      isGlobal: _isGlobal,
      maxStages: _stages.length,
      defaultMode: 'Manual',
      stages: _stages,
      endgameRecovery: _recovery,
    );
    try {
      final newId = await _service.saveStrategy(strategy);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (_strategyId == null || _strategyId!.isEmpty) {
          _strategyId = newId;
        }
        _savedStrategyId = newId;
        _isSaved = true;
      });
      // Remember the saved strategy so the Navigator / Simulation screens can
      // pre-select it (mirrors the web's localStorage last-active id).
      if (newId != null && newId.isNotEmpty) {
        await StrategyPrefs.setLastCreated(newId);
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isSaved = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save strategy: $e'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  void _openNavigator() {
    final id = _strategyId ?? _savedStrategyId;
    final path =
        id != null ? '/strategies/debug?strategyId=$id' : '/strategies/debug';
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the funnel's "ready to advance" glow in sync with live state.
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: _buildTopBar(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 250, child: _buildSidebar()),
                                  const SizedBox(width: 14),
                                  Expanded(child: _buildBuilderArea()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TourTarget(
                                id: 'funnel-stage-rules',
                                child: _buildStageRulesCard()),
                            const SizedBox(height: 16),
                            _buildDynamicRulesCard(),
                            const SizedBox(height: 16),
                            TourTarget(
                                id: 'strategy-notes',
                                child: _buildStrategyNotesSection()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return TourTarget(
      id: 'builder-top-nav',
      child: Row(
        children: [
          _navPill('LIBRARY', Icons.arrow_back, () => context.go('/strategies')),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Strategy Builder',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: _kInkText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if ((_strategyId ?? _savedStrategyId) != null) ...[
            _pillButton('TEST RESULTS', Icons.bar_chart, () {
              final id = _strategyId ?? _savedStrategyId;
              context.push('/simulation/history?strategyId=$id');
            }, filled: false),
            const SizedBox(width: 10),
          ],
          TourTarget(
            id: 'funnel-goto-navigator',
            child: _pillButton('NAVIGATOR', Icons.insights, _handleNavigatorTap,
                filled: false),
          ),
        ],
      ),
    );
  }

  Widget _navPill(String label, IconData? icon, VoidCallback onTap) {
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
            if (icon != null) ...[
              Icon(icon, size: 13, color: _kInkText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _kInkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onTap,
      {bool filled = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? _kInk : _kInk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9999),
          border: filled ? null : Border.all(color: _kInk.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? _kGold : _kInk),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: filled ? _kGold : _kInk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: _kInk,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(
                color: Color(0x660F2E21), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSaving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kGold),
              )
            else
              const Icon(Icons.save_outlined, size: 15, color: _kGold),
            const SizedBox(width: 8),
            Text(
              _isSaving
                  ? 'SAVING...'
                  : _isSaved
                      ? 'SAVED ✓'
                      : 'SAVE',
              style: GoogleFonts.inter(
                color: _kGold,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left sidebar ────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return TourTarget(
      id: 'builder-sidebar',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card('Strategy Info', [
          _fieldLabel('Strategy Name'),
          TourTarget(
            id: 'funnel-strategy-name',
            child: _textField(_nameController,
                hint: 'e.g. Green Neighbors',
                onChanged: (_) => setState(() {})),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Wheel Type'),
          TourTarget(id: 'funnel-wheel-type', child: _wheelDropdown()),
          const SizedBox(height: 12),
          _fieldLabel('Description (Optional)'),
          TourTarget(
            id: 'funnel-description',
            child: _textField(_descController,
                hint: 'Notes about this strategy...', maxLines: 3),
          ),
        ]),
        const SizedBox(height: 12),
        _buildRecoveryCard(),
        const SizedBox(height: 12),
        _card('Settings', [
          _fieldLabel('Max Stages'),
          _textField(
            _maxStagesController,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 1 && n <= 30) {
                setState(() => _maxStages = n);
              }
            },
          ),
          if (_isGlobal) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('🌍', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'GLOBAL STRATEGY',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _kGoldDark,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ]),
      ],
    ),
    );
  }

  Widget _buildRecoveryCard() {
    return _card('⚡ End-Game Recovery', [
      Text(
        'Global rule — applies to ALL stages. When every tagged group has won '
        'but session profit is negative, break-even recovery bets auto-deploy.',
        style: GoogleFonts.inter(
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: _kGoldDark,
        ),
      ),
      const SizedBox(height: 8),
      _checkRow(
        'Enable End-Game Recovery',
        _recovery.enabled,
        (v) => setState(() => _recovery.enabled = v),
        accent: _kInk,
      ),
      if (_recovery.enabled) ...[
        const SizedBox(height: 8),
        _fieldLabel('Recovery Bet Positions'),
        Text(
          'Select a chip value, then add recovery position codes.',
          style: GoogleFonts.inter(
              fontSize: 10, color: _kGoldDark, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [1, 2, 5, 10, 25, 50, 100].map((chip) {
            final sel = _recoverySelectedChip == chip;
            return GestureDetector(
              onTap: () => setState(() => _recoverySelectedChip = chip),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? _kGold.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel ? _kGold : _kGold.withValues(alpha: 0.3),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '\$$chip',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? const Color(0xFF8C6518) : _kInkText,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_recovery.recoveryBets.isEmpty)
          Text(
            'No recovery positions added yet.',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: _kGoldDark),
          ),
        ..._recovery.recoveryBets.asMap().entries.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${e.value.position}  (\$${e.value.amount})',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kInkText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _recovery.recoveryBets.removeAt(e.key)),
                  child: const Icon(Icons.close, size: 15, color: _kLoss),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: _textField(_recoveryPosController,
                  hint: 'e.g. split-25-26',
                  onSubmitted: (_) => _addRecoveryPosition()),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _addRecoveryPosition,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+ Add',
                    style: GoogleFonts.inter(
                        color: _kGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _fieldLabel('Fallback Bet Amount (\$)'),
        _numberField(
          value: _recovery.fallbackAmount,
          hint: '10',
          onChanged: (n) => setState(() => _recovery.fallbackAmount = n ?? 10),
        ),
      ],
    ]);
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800, color: _kInkText),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _kGoldDark,
            letterSpacing: 1,
          ),
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(
          color: _kInkText, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        hintText: hint,
        hintStyle:
            TextStyle(color: _kInkText.withValues(alpha: 0.35), fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _kGold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _numberField({
    required num? value,
    String? hint,
    required ValueChanged<num?> onChanged,
  }) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
          color: _kInkText, fontSize: 13, fontWeight: FontWeight.w600),
      onChanged: (v) => onChanged(v.isEmpty ? null : num.tryParse(v)),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        hintText: hint,
        hintStyle:
            TextStyle(color: _kInkText.withValues(alpha: 0.35), fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _kGold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }

  Widget _wheelDropdown() {
    return _dropdown<String>(
      value: _wheelType,
      items: const {
        'American': 'American (0, 00)',
        'European': 'European (0)',
        'Both': 'Both (American & European)',
      },
      onChanged: (v) => setState(() => _wheelType = v),
    );
  }

  /// Generic styled dropdown.
  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (accent ?? _kGold).withValues(alpha: 0.35), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: const Color(0xFFF5EDD5),
          style: TextStyle(
            color: accent ?? _kInkText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem<T>(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged,
      {Color accent = _kTeal}) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kInkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Builder area (stage tabs + table + tags + chips) ────────────────────────
  Widget _buildBuilderArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageTabs(),
        const SizedBox(height: 8),
        _buildTableCard(),
      ],
    );
  }

  Widget _buildStageTabs() {
    return TourTarget(
      id: 'stage-tabs',
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _stages.length; i++) _stageTab(i),
                  if (_stages.length < _maxStages)
                    TourTarget(
                      id: 'funnel-add-stage',
                      child: GestureDetector(
                        onTap: _handleAddStageTap,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _kInk.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _kInk.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add, size: 14, color: _kInkText),
                              const SizedBox(width: 4),
                              Text(
                                'ADD STAGE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kInkText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Save is anchored here so it is always reachable on every stage —
            // the top bar can push its Save off-screen when Test Results +
            // Navigator are also shown.
            const SizedBox(width: 8),
            TourTarget(
              id: 'funnel-save-strategy',
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageTab(int idx) {
    final bool active = _activeIndex == idx;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? _kInk : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: active ? _kInk : _kInkText.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _selectStage(idx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'STAGE ${_stages[idx].stageNumber}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? _kGold : _kInkText,
                ),
              ),
            ),
          ),
          if (_stages.length > 1)
            GestureDetector(
              onTap: () => _deleteStage(idx),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.close,
                    size: 13,
                    color: active ? _kGold : _kLoss),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          TourTarget(id: 'table-toolbar', child: _buildTableHeader()),
          const SizedBox(height: 6),
          TourTarget(
            id: 'funnel-betting-board',
            child: SizedBox(
              height: 360,
              child: LayoutBuilder(
                builder: (context, c) {
                  // Widen the felt so number cells and the split/corner tap
                  // zones between them are comfortably large; scroll if the
                  // panel is narrower than that target width.
                  final boardWidth =
                      c.maxWidth > 760 ? c.maxWidth : 760.0;
                  return Scrollbar(
                    controller: _boardScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _boardScroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: boardWidth,
                        child: BettingLayout(
                          bets: _currentBetsMap,
                          onPlaceBet: _placeBet,
                          onRemoveBet: _removeBet,
                          disabled: false,
                          showWinHighlight: false,
                          phase: 'betting',
                          wheelType: _wheelEnum,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          TourTarget(id: 'funnel-tag-system', child: _buildTagSystem()),
          const SizedBox(height: 8),
          TourTarget(
            id: 'funnel-chip-selector',
            child: ChipTray(
              selectedChip: _selectedChip,
              onSelectChip: (v) => setState(() {
                _selectedChip = v;
                _tourChipTouched = true;
              }),
              balance: 999999,
              totalBet: _active.totalWager.toDouble(),
              disabled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Text(
          'Stage ${_active.stageNumber} Layout',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800, color: _kInkText),
        ),
        _kv('Wager', '\$${_active.totalWager}'),
        _kv('Bankroll', '\$$_totalBankroll'),
        const SizedBox(width: 4),
        _tableBtn('REBET', Icons.refresh,
            (_activeIndex == 0 || _stages[_activeIndex - 1].bets.isEmpty)
                ? null
                : _repeatBet),
        _tableBtn('DOUBLE', null, _active.bets.isEmpty ? null : _doubleBet,
            leadingText: '2x'),
        _tableBtn('UNDO', Icons.undo, _history.isEmpty ? null : _undo),
        _tableBtn('CLEAR', Icons.delete_outline,
            _active.bets.isEmpty ? null : _clearBoard),
      ],
    );
  }

  Widget _tableBtn(String label, IconData? icon, VoidCallback? onTap,
      {String? leadingText}) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kInkText.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingText != null)
                Text(leadingText,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _kInkText,
                        height: 1))
              else if (icon != null)
                Icon(icon, size: 14, color: _kInkText),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kInkText,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Text.rich(
      TextSpan(
        text: '$k ',
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kGoldDark),
        children: [
          TextSpan(
            text: v,
            style: const TextStyle(color: _kInkText, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSystem() {
    final assigned = _activeGroupId != 'none'
        ? _active.bets.where((b) => b.groupId == _activeGroupId).toList()
        : <StageBet>[];
    return Column(
      children: [
        Text(
          'ASSIGN TAG',
          style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: _kGold),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            children: [
              _groupTab('none', 'No Tag'),
              for (final g in _customGroups) _groupTab(g, 'G-$g'),
              GestureDetector(
                onTap: _addGroup,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kInk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kInk.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 13, color: _kInkText),
                      const SizedBox(width: 3),
                      Text('ADD TAG',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kInkText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _checkRow(
          'Tag Only Mode (assign tags without adding chips to existing bets)',
          _tagOnlyMode,
          (v) => setState(() => _tagOnlyMode = v),
        ),
        if (_activeGroupId != 'none')
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kTeal.withValues(alpha: 0.3)),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Group $_activeGroupId: ',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800, color: _kTeal),
                children: [
                  TextSpan(
                    text: assigned.isEmpty
                        ? 'No bets assigned yet. Tap chips on the board to tag them.'
                        : '${assigned.map((b) => _prettyPos(b.position)).join(', ')} '
                            '(${assigned.length} bets, \$${assigned.fold<num>(0, (a, b) => a + b.amount)} total)',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kInkText),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _prettyPos(String pos) => pos
      .replaceAll('split-', '')
      .replaceAll('straight-', '')
      .replaceAll('corner-', '')
      .replaceAll('street-', '')
      .replaceAll('sixline-', '')
      .replaceAll('-', '/');

  Widget _groupTab(String id, String label) {
    final active = _activeGroupId == id;
    final isGroup = id != 'none';
    final color = isGroup ? _hexColor(_groupColorHex(id)) : _kInk;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? color : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active ? color : _kInkText.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _activeGroupId = id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _kInkText,
                ),
              ),
            ),
          ),
          if (isGroup)
            GestureDetector(
              onTap: () => _removeGroup(id),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.close,
                    size: 12, color: active ? Colors.white : _kLoss),
              ),
            ),
        ],
      ),
    );
  }

  // ── Stage rules card ────────────────────────────────────────────────────────
  Widget _buildStageRulesCard() {
    final stage = _active;
    final actionOptions = <String, String>{
      'next': 'Advance to Next Stage',
      'repeat': 'Repeat This Stage',
      for (final s in _stages) 'jump_${s.stageNumber}': 'Jump to Stage ${s.stageNumber}',
      'reset': 'Clear Bets & Reset to Stage 1',
      'stop': 'Stop Strategy',
      'manual': 'Exit to Manual Betting',
    };
    final rules = stage.optionalRules ??= StageOptionalRules();

    return _wideCard(
      icon: Icons.settings,
      title: 'Stage ${stage.stageNumber} Rules',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IF SPIN LOSES',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kLoss,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  _dropdown<String>(
                    value: actionOptions.containsKey(stage.onLoss)
                        ? stage.onLoss
                        : 'next',
                    items: actionOptions,
                    accent: _kLoss,
                    onChanged: (v) => setState(() => stage.onLoss = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IF SPIN WINS',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  _dropdown<String>(
                    value: actionOptions.containsKey(stage.onWin)
                        ? stage.onWin
                        : 'reset',
                    items: actionOptions,
                    accent: _kInk,
                    onChanged: (v) => setState(() => stage.onWin = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('OPTIONAL SAFETY & PROFIT RULES',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kGoldDark,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        _checkRow('Reset to Stage 1 on any winning spin',
            rules.resetOnAnyWin ?? false,
            (v) => setState(() => rules.resetOnAnyWin = v)),
        _checkRow('Reset if overall session becomes profitable',
            rules.resetOnProfitableSession ?? false,
            (v) => setState(() => rules.resetOnProfitableSession = v)),
        _checkRow('Reset if new session high reached',
            rules.resetOnNewSessionHigh ?? false,
            (v) => setState(() => rules.resetOnNewSessionHigh = v)),
        _checkRow('Reset session if board is empty (0 active bets)',
            rules.resetOnEmptyBoard ?? false,
            (v) => setState(() => rules.resetOnEmptyBoard = v)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Reset if profit goal reached (\$)'),
                  _numberField(
                    value: rules.resetOnProfitGoal,
                    hint: 'Optional...',
                    onChanged: (n) =>
                        setState(() => rules.resetOnProfitGoal = n),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('End session if stop loss reached (\$)'),
                  _numberField(
                    value: rules.stopOnStopLoss,
                    hint: 'Optional...',
                    onChanged: (n) => setState(() => rules.stopOnStopLoss = n),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Dynamic rules card ──────────────────────────────────────────────────────
  Widget _buildDynamicRulesCard() {
    final stage = _active;
    final rules = stage.dynamicRules ?? [];
    return _wideCard(
      icon: Icons.bolt,
      title: 'Advanced Rules (Simulation Engine)',
      trailing: TourTarget(
        id: 'funnel-dynamic-rules-btn',
        child: GestureDetector(
        onTap: _addDynamicRule,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 14, color: _kGold),
              const SizedBox(width: 5),
              Text('ADD DYNAMIC RULE',
                  style: GoogleFonts.inter(
                      color: _kGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
      ),
      children: [
        if (rules.isEmpty)
          Text(
            'No advanced rules configured for this stage.',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: _kGoldDark),
          ),
        for (int i = 0; i < rules.length; i++) _dynamicRuleRow(rules[i], i),
      ],
    );
  }

  Widget _dynamicRuleRow(DynamicRule rule, int idx) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RULE ${idx + 1}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: 1)),
              GestureDetector(
                onTap: () => _removeDynamicRule(rule.id),
                child: const Icon(Icons.delete_outline, size: 16, color: _kLoss),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final twoCol = c.maxWidth > 560;
            final children = <Widget>[
              _ruleField(
                'When condition is...',
                _dropdown<String>(
                  value: rule.condition,
                  items: const {
                    RuleCondition.win: 'On Winning Spin',
                    RuleCondition.loss: 'On Losing Spin',
                    RuleCondition.winSessionHighNotReached:
                        'Win (failed to break session high)',
                    RuleCondition.winSessionLoss:
                        'Win (overall session negative)',
                    RuleCondition.winSessionProfit:
                        'Win (overall session positive)',
                    RuleCondition.lossSessionLoss:
                        'Loss (overall session negative)',
                    RuleCondition.lossSessionProfit:
                        'Loss (overall session positive)',
                    RuleCondition.oneGroupRemainsAndNegativeProfit:
                        '1 Group Remains & Negative Profit',
                    RuleCondition.any: 'On Any Spin Result',
                  },
                  onChanged: (v) => setState(() => rule.condition = v),
                ),
              ),
              _ruleField(
                'Identify targets...',
                _dropdown<String>(
                  value: rule.target,
                  items: const {
                    RuleTarget.allBets: 'All Placed Bets',
                    RuleTarget.winningBets: 'Only Winning Bets',
                    RuleTarget.losingBets: 'Only Losing Bets',
                    RuleTarget.winningGroup: 'Winning Group(s) (Tagged)',
                    RuleTarget.losingGroup: 'Losing Group(s) (Tagged)',
                  },
                  onChanged: (v) => setState(() => rule.target = v),
                ),
              ),
              _ruleField(
                'Execute action...',
                _dropdown<String>(
                  value: rule.action,
                  items: const {
                    RuleActionType.multiply: 'Multiply Bet Amount',
                    RuleActionType.add: 'Add Static Units (+)',
                    RuleActionType.remove: 'Remove Bet Entirely',
                    RuleActionType.set: 'Set Bet to Exact Amount',
                    RuleActionType.setBreakEven:
                        'Set Bet to Break-Even (or Fallback)',
                  },
                  onChanged: (v) => setState(() => rule.action = v),
                ),
              ),
              if (rule.action != RuleActionType.remove)
                _ruleField(
                  _valueLabel(rule.action),
                  _numberField(
                    value: rule.value,
                    onChanged: (n) => setState(() => rule.value = n),
                  ),
                ),
            ];
            if (!twoCol) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in children)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8), child: w),
                ],
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final w in children)
                  SizedBox(width: (c.maxWidth - 12) / 2, child: w),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _valueLabel(String action) {
    switch (action) {
      case RuleActionType.multiply:
        return 'Multiplier (e.g. 2 for Double)';
      case RuleActionType.add:
        return 'Units to Add (\$)';
      case RuleActionType.set:
        return 'Exact Amount (\$)';
      default:
        return 'Amount / Fallback Amount (\$)';
    }
  }

  Widget _ruleField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        field,
      ],
    );
  }

  Widget _wideCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
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
              Icon(icon, size: 18, color: _kInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInkText),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── Strategy notes section ──────────────────────────────────────────────────
  Widget _buildStrategyNotesSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.notes, size: 18, color: _kInk),
                const SizedBox(width: 8),
                Text('Strategy Notes',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInkText)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Detailed notes to help you understand, test, and implement this strategy.',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _kGoldDark, fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _textField(
              _notesController,
              hint:
                  'Add background, appropriate use, testing recommendations, and progression variations...',
              maxLines: 5,
            ),
          ),
          // Creator notes box
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGold),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 32, color: _kGold),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Creator Notes',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'This has been one of my go-to strategies for years when I want '
                        'controlled risk and consistent action. Keep sessions short, take '
                        'the small wins, and exit on a session high. Discipline is the key.',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Junko Bodie',
                  style: GoogleFonts.dancingScript(
                    fontSize: 28,
                    color: _kGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
