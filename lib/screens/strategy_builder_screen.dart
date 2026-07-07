/// Strategy Builder — replicates the web /strategies/build page.
///
/// Lets the user create/edit a staged betting strategy: set name, wheel type,
/// description, max stages; add/delete stages; place chips on the interactive
/// felt per stage; undo/clear; and save (POST/PUT) to the backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/strategy_service.dart';
import 'package:junko_bodie/widgets/betting_layout.dart';
import 'package:junko_bodie/widgets/chip_tray.dart';

// ─── Palette (matches the gold/cream builder page) ──
const Color _kInk = Color(0xFF0F2E21);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);

/// Mutable working copy of a stage while editing.
class _WorkStage {
  int stageNumber;
  // position (betId) -> total amount wagered
  Map<String, double> bets;
  String onWin;
  String onLoss;

  _WorkStage({
    required this.stageNumber,
    Map<String, double>? bets,
    this.onWin = 'reset',
    this.onLoss = 'next',
  }) : bets = bets ?? {};

  double get totalWager => bets.values.fold(0.0, (a, b) => a + b);

  _WorkStage clone() => _WorkStage(
        stageNumber: stageNumber,
        bets: Map<String, double>.from(bets),
        onWin: onWin,
        onLoss: onLoss,
      );

  StrategyStage toStage() => StrategyStage(
        stageNumber: stageNumber,
        bets: bets.entries
            .map((e) => StageBet(position: e.key, amount: e.value))
            .toList(),
        totalWager: totalWager,
        onWin: onWin,
        onLoss: onLoss,
      );

  factory _WorkStage.fromStage(StrategyStage s) => _WorkStage(
        stageNumber: s.stageNumber,
        bets: {for (final b in s.bets) b.position: b.amount.toDouble()},
        onWin: s.onWin,
        onLoss: s.onLoss,
      );
}

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
  final _maxStagesController = TextEditingController(text: '10');

  String? _strategyId;
  String _wheelType = 'American';
  int _maxStages = 10;

  List<_WorkStage> _stages = [_WorkStage(stageNumber: 1)];
  int _activeIndex = 0;
  double _selectedChip = 5;

  // Per-stage undo history (reset on stage change), matching the web.
  final List<Map<String, double>> _history = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSaved = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _maxStagesController.dispose();
    super.dispose();
  }

  Future<void> _loadStrategy() async {
    setState(() => _isLoading = true);
    try {
      final s = await _service.fetchStrategyById(_strategyId!);
      if (s != null && mounted) {
        setState(() {
          _nameController.text = s.name;
          _descController.text = s.description ?? '';
          _wheelType = s.wheelType == 'European' ? 'European' : 'American';
          _maxStages = s.maxStages;
          _maxStagesController.text = s.maxStages.toString();
          if (s.stages.isNotEmpty) {
            _stages = s.stages.map(_WorkStage.fromStage).toList();
          }
          _activeIndex = 0;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _WorkStage get _active => _stages[_activeIndex];
  double get _totalBankroll => _stages.fold(0.0, (a, s) => a + s.totalWager);

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
    _active.bets.forEach((pos, amount) {
      map[pos] = PlacedBet(
        betId: pos,
        amount: amount,
        chips: _chipsFor(amount),
        playerInitial: 'S',
      );
    });
    return map;
  }

  void _pushHistory() {
    _history.add(Map<String, double>.from(_active.bets));
  }

  void _placeBet(String betId) {
    setState(() {
      _pushHistory();
      _active.bets[betId] = (_active.bets[betId] ?? 0) + _selectedChip;
    });
  }

  void _removeBet(String betId) {
    if (!_active.bets.containsKey(betId)) return;
    setState(() {
      _pushHistory();
      _active.bets.remove(betId);
    });
  }

  void _clearBoard() {
    setState(() {
      _pushHistory();
      _active.bets.clear();
    });
  }

  /// Merge the prior stage's bets into the current stage so the player can keep
  /// building on top of them. Only available from Stage 2 onwards. Mirrors the
  /// web's handleRepeatBet.
  void _repeatBet() {
    if (_activeIndex == 0) return;
    final prev = _stages[_activeIndex - 1];
    if (prev.bets.isEmpty) return;
    setState(() {
      _pushHistory();
      prev.bets.forEach((pos, amount) {
        _active.bets[pos] = (_active.bets[pos] ?? 0) + amount;
      });
    });
  }

  /// Double every bet on the current stage. Mirrors the web's handleDoubleBet
  /// (and the solo game's 2X button).
  void _doubleBet() {
    if (_active.bets.isEmpty) return;
    setState(() {
      _pushHistory();
      _active.bets.updateAll((_, amount) => amount * 2);
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _active.bets = _history.removeLast();
    });
  }

  void _addStage() {
    if (_stages.length >= _maxStages) return;
    setState(() {
      _stages.add(_WorkStage(stageNumber: _stages.length + 1));
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

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final strategy = BettingStrategy(
      id: _strategyId,
      name: _nameController.text.trim().isEmpty
          ? 'New Strategy'
          : _nameController.text.trim(),
      wheelType: _wheelType,
      description: _descController.text.trim(),
      isActive: true,
      maxStages: _maxStages,
      defaultMode: 'Manual',
      stages: _stages.map((s) => s.toStage()).toList(),
    );
    try {
      final newId = await _service.saveStrategy(strategy);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (_strategyId == null || _strategyId!.isEmpty) {
          _strategyId = newId; // continue editing the newly created strategy
        }
        _isSaved = true;
      });
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
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 230, child: _buildSidebar()),
                            const SizedBox(width: 14),
                            Expanded(child: _buildBuilderArea()),
                          ],
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
        _navPill('BACK TO LOBBY', Icons.arrow_back, () => context.go('/lobby')),
        const SizedBox(width: 12),
        Container(width: 1, height: 16, color: _kInkText.withValues(alpha: 0.25)),
        const SizedBox(width: 12),
        _navPill('RETURN TO LIBRARY', null, () => context.go('/strategies')),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Strategy Builder',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: _kInkText,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        _buildSaveButton(),
      ],
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

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: _kInk,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(color: Color(0x660F2E21), blurRadius: 12, offset: Offset(0, 4)),
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
              _isSaving ? 'SAVING...' : _isSaved ? 'SAVED ✓' : 'SAVE STRATEGY',
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

  // ── Left sidebar ───────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            'Strategy Info',
            [
              _fieldLabel('Strategy Name'),
              _textField(_nameController, hint: 'e.g. Green Neighbors'),
              const SizedBox(height: 12),
              _fieldLabel('Wheel Type'),
              _wheelDropdown(),
              const SizedBox(height: 12),
              _fieldLabel('Description (Optional)'),
              _textField(_descController, hint: 'Notes about this strategy...', maxLines: 3),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            'Settings',
            [
              _fieldLabel('Max Stages'),
              _textField(
                _maxStagesController,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1 && n <= 100) {
                    setState(() => _maxStages = n);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kInkText,
            ),
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
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: _kInkText, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        hintText: hint,
        hintStyle: TextStyle(color: _kInkText.withValues(alpha: 0.35), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kGold.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _wheelType,
          isDense: true,
          isExpanded: true,
          dropdownColor: const Color(0xFFF5EDD5),
          style: const TextStyle(color: _kInkText, fontSize: 13, fontWeight: FontWeight.w700),
          items: const [
            DropdownMenuItem(value: 'American', child: Text('American (0, 00)')),
            DropdownMenuItem(value: 'European', child: Text('European (0)')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _wheelType = v);
          },
        ),
      ),
    );
  }

  // ── Right builder area ───────────────────────────────────────────────────────
  Widget _buildBuilderArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageTabs(),
        const SizedBox(height: 8),
        Expanded(child: _buildTableCard()),
      ],
    );
  }

  Widget _buildStageTabs() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < _stages.length; i++) _stageTab(i),
          if (_stages.length < _maxStages)
            GestureDetector(
              onTap: _addStage,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _kInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kInk.withValues(alpha: 0.25)),
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
        ],
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
        border: Border.all(
          color: active ? _kInk : _kInkText.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _selectStage(idx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Stage ${_stages[idx].stageNumber}',
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
                child: Icon(
                  Icons.close,
                  size: 13,
                  color: active ? _kGold.withValues(alpha: 0.8) : _kInkText.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Compact single-row header: title + wager + bankroll + undo/clear
          Row(
            children: [
              Text(
                'Stage ${_active.stageNumber} Layout',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kInkText,
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(
                  text: 'Wager ',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _kGoldDark),
                  children: [
                    TextSpan(
                      text: '\$${_active.totalWager.toStringAsFixed(0)}',
                      style: const TextStyle(color: _kInkText, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(
                  text: 'Bankroll ',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _kGoldDark),
                  children: [
                    TextSpan(
                      text: '\$${_totalBankroll.toStringAsFixed(0)}',
                      style: const TextStyle(color: _kInkText, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _tableBtn(
                'REPEAT',
                Icons.refresh,
                (_activeIndex == 0 || _stages[_activeIndex - 1].bets.isEmpty)
                    ? null
                    : _repeatBet,
              ),
              const SizedBox(width: 6),
              _tableBtn(
                'DOUBLE',
                null,
                _active.bets.isEmpty ? null : _doubleBet,
                leadingText: '2X',
              ),
              const SizedBox(width: 6),
              _tableBtn('UNDO', Icons.undo, _history.isEmpty ? null : _undo),
              const SizedBox(width: 6),
              _tableBtn('CLEAR', Icons.delete_outline, _active.bets.isEmpty ? null : _clearBoard),
            ],
          ),
          const SizedBox(height: 4),
          // Felt board — compact so the numbers grid gets usable height.
          Expanded(
            child: BettingLayout(
              bets: _currentBetsMap,
              onPlaceBet: _placeBet,
              onRemoveBet: _removeBet,
              disabled: false,
              showWinHighlight: false,
              phase: 'betting',
              isCompact: true,
              wheelType: _wheelType == 'European' ? WheelType.european : WheelType.american,
            ),
          ),
          const SizedBox(height: 4),
          // Chip tray
          ChipTray(
            selectedChip: _selectedChip,
            onSelectChip: (v) => setState(() => _selectedChip = v),
            balance: 999999,
            totalBet: _active.totalWager,
            disabled: false,
          ),
        ],
      ),
    );
  }

  Widget _tableBtn(String label, IconData? icon, VoidCallback? onTap,
      {String? leadingText}) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
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
                Text(
                  leadingText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _kInkText,
                    height: 1,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 14, color: _kInkText),
              const SizedBox(width: 5),
              Text(
                label,
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
    );
  }
}
