/// Simulation Run + Dashboard — replicates the web /simulation/run page.
///
/// Runs the [SimulationEngine] in animation-frame-sized chunks (so the UI stays
/// responsive), shows a progress screen, then a results dashboard with a grade,
/// headline stats, a bankroll-trajectory chart, and metric tabs. Also renders a
/// previously stored run when opened from the Test Results History screen.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/simulation_history_service.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_help_button.dart';
import 'package:junko_bodie/tour/tour_registry.dart';
import 'package:junko_bodie/widgets/junko_tip_card.dart';

const Color _kInk = Color(0xFF0F2E21);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
// Darker bronze-gold used for the "B" grade so it stays legible on the tan
// dashboard background (the bright _kGold only reads on dark surfaces).
const Color _kGradeGold = Color(0xFF7A5C12);
const Color _kGoldDark = Color(0xFF6B5220);
const Color _kPos = Color(0xFF16A34A);
const Color _kNeg = Color(0xFFEF4444);

/// Navigation payload for the run screen. Either run a fresh simulation
/// ([config] + [strategy]) or display a stored [result] (from history).
class SimulationRunArgs {
  final SimulationConfig? config;
  final BettingStrategy? strategy;
  final SimulationResult? result;
  final bool fromHistory;

  const SimulationRunArgs({
    this.config,
    this.strategy,
    this.result,
    this.fromHistory = false,
  });
}

class SimulationRunScreen extends StatefulWidget {
  final SimulationRunArgs args;
  const SimulationRunScreen({super.key, required this.args});

  @override
  State<SimulationRunScreen> createState() => _SimulationRunScreenState();
}

class _SimulationRunScreenState extends State<SimulationRunScreen> {
  final SimulationHistoryService _historyService = SimulationHistoryService();

  String _status = 'initializing'; // initializing | running | finalizing | completed
  double _progress = 0;
  int _spinsExecuted = 0;
  int _targetSpins = 1000;
  SimulationResult? _results;
  String _activeTab = 'overview';
  bool _cancelled = false;

  TourController? _tour;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _tour = context.read<TourController>();
    _tour!.addListener(_syncTour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTour();
      _begin();
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _tour?.removeListener(_syncTour);
    super.dispose();
  }

  /// The tour target currently being spotlighted on this route, or null.
  /// Mirrors the overlay's own target resolution.
  String? _activeTourTarget() {
    final c = _tour;
    if (c == null) return null;
    if (c.pageTourActive) return c.currentPageStep?.id;
    final route = c.routeGetter?.call() ?? '';
    if (c.isActive && !c.isTourPaused && c.isStepVisibleOn(route)) {
      return c.currentStep?.targetId;
    }
    return null;
  }

  /// The bankroll chart lives in the "bankroll" tab, so force that tab active
  /// whenever the tour needs to spotlight it.
  void _syncTour() {
    if (!mounted) return;
    final target = _activeTourTarget();
    if (target == 'funnel-bankroll-chart' && _activeTab != 'bankroll') {
      setState(() => _activeTab = 'bankroll');
    } else if (target == 'funnel-profit-dynamics' &&
        _activeTab != 'profitability') {
      setState(() => _activeTab = 'profitability');
    }
  }

  Future<void> _begin() async {
    // History view: show the stored result immediately.
    if (widget.args.result != null) {
      setState(() {
        _results = widget.args.result;
        _status = 'completed';
      });
      return;
    }

    final config = widget.args.config;
    final strategy = widget.args.strategy;
    if (config == null || strategy == null) {
      if (mounted) context.pop();
      return;
    }

    _targetSpins = config.requestedSpins;
    setState(() => _status = 'running');

    final engine = SimulationEngine(strategy, config);
    final chunkSize =
        min(25000, max(50, (_targetSpins / 30).floor()));

    // Run in chunks, yielding to the event loop between them so the progress
    // bar can paint (mirrors the web's requestAnimationFrame loop).
    bool complete = false;
    while (!complete && !_cancelled) {
      complete = engine.runChunk(chunkSize);
      final res = engine.getResults();
      if (!mounted || _cancelled) return;
      setState(() {
        _spinsExecuted = res.totalSpinsExecuted;
        _progress = (res.totalSpinsExecuted / _targetSpins).clamp(0.0, 1.0);
      });
      await Future<void>.delayed(Duration.zero);
    }
    if (!mounted || _cancelled) return;

    final finalRes = engine.getResults();
    await _historyService.addRun(finalRes);

    setState(() {
      _results = finalRes;
      _progress = 1;
      _status = 'finalizing';
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _status = 'completed');
  }

  String _progressLabel(double p) {
    if (p < 0.35) return 'EXECUTING ALGORITHM...';
    if (p < 0.70) return 'CALCULATING DYNAMICS...';
    if (p < 0.95) return 'AGGREGATING RESULTS...';
    return 'PREPARING REPORT...';
  }

  /// Context-sensitive Junko advice keyed off the active dashboard tab —
  /// mirrors the web run page's dynamic tip card.
  ({String title, String text}) _junkoTip() {
    switch (_activeTab) {
      case 'profitability':
        return (
          title: 'Profitability Metric',
          text:
              '"A key metric for me is that the success ratio of any system I use be at least 96% (or more). I also want my average profit per spin to exceed \$2."',
        );
      case 'bankroll':
        return (
          title: 'Bankroll Stability Goal',
          text:
              '"The player\'s goal for this graph is to a flat or upward trajectory. Adjust your system\'s chip coverage, betting progression, bankroll, or phantom misses to increase success."',
        );
      case 'stages':
        return (
          title: 'Stage Penetration Strategy',
          text:
              '"The number of stages we build into a system is a critical part of its construction... and success. Understanding penetration patterns helps us to decide betting progressions to coincide with our stage construction and preserve our bankroll. Learn to determine what the critical stages are for your strategies so you can plan for contingencies."',
        );
      default:
        return (
          title: 'Simulation Advice',
          text:
              '"Almost all Roulette systems receive low grades at 25,000 spins. To better evaluate your system, adjust the number of spins, or your bankroll, and/or your entry points for better results. Experiment with Simulation. Try different parameters until you achieve success."',
        );
    }
  }

  ({String grade, String label, Color color}) _grade(SimulationResult r) {
    final roi = r.startingBankroll > 0 ? r.netProfit / r.startingBankroll : 0;
    if (roi >= 0.20) return (grade: 'A', label: 'Exceptional', color: _kPos);
    if (roi > 0) return (grade: 'B', label: 'Good', color: _kGradeGold);
    if (roi >= -0.25) return (grade: 'C', label: 'Average', color: const Color(0xFF3B82F6));
    if (roi >= -0.60) return (grade: 'D', label: 'Below Average', color: const Color(0xFFEA580C));
    return (grade: 'E', label: 'Fail', color: _kNeg);
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
          child: _status == 'completed' && _results != null
              ? _buildDashboard(_results!)
              : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final finalizing = _status == 'finalizing';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(finalizing ? 'COMPILING REPORT...' : 'VIRTUALIZING SESSIONS',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _kInkText)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: SizedBox(
                width: 320,
                height: 10,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: _kInk.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(_kInk),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              finalizing
                  ? '100% COMPLETE - COMPILING METRICS'
                  : '${_progressLabel(_progress)} (${_fmt(_spinsExecuted)} / ${_fmt(_targetSpins)})',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kGoldDark,
                  letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(SimulationResult r) {
    final g = _grade(r);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dashboardHeader(r, g),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: JunkoTipCard(
              title: _junkoTip().title,
              text: _junkoTip().text,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topStats(r),
                  const SizedBox(height: 12),
                  _tabs(),
                  const SizedBox(height: 12),
                  _tabContent(r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardHeader(SimulationResult r, ({String grade, String label, Color color}) g) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Grade badge
        TourTarget(
          id: 'funnel-grade-card',
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: g.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: g.color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Text(g.grade,
                  style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: g.color,
                      height: 1)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SYSTEM RATING',
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: _kGoldDark)),
                  Text(g.label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: g.color)),
                ],
              ),
            ],
          ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${r.strategyName} Simulation',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: _kInkText),
                  overflow: TextOverflow.ellipsis),
              Text('Report covering ${_fmt(r.totalSpinsExecuted)} total spins.',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kGoldDark)),
            ],
          ),
        ),
        const TourHelpButton(tourId: 'simulation-run'),
        const SizedBox(width: 8),
        _headerBtn(
          widget.args.fromHistory ? 'HISTORY' : 'PARAMETERS',
          Icons.arrow_back,
          () {
            if (widget.args.fromHistory) {
              context.go('/simulation/history?strategyId=${r.strategyId}');
            } else {
              context.pop();
            }
          },
        ),
        const SizedBox(width: 8),
        TourTarget(
          id: 'funnel-return-library',
          child: _headerBtn('LIBRARY', null, _handleReturnToLibrary,
              filled: true),
        ),
      ],
    );
  }

  /// Funnel "Return to Strategy Library" click-through (step sim_return).
  void _handleReturnToLibrary() {
    final tour = _tour;
    if (tour != null && tour.currentStep?.id == 'sim_return') {
      tour.advanceStep('sim_return');
    }
    context.go('/strategies');
  }

  Widget _headerBtn(String label, IconData? icon, VoidCallback onTap,
      {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? _kGold : _kInkText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9999),
          border: filled
              ? null
              : Border.all(color: _kInkText.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: filled ? _kInk : _kInkText),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: filled ? _kInk : _kInkText)),
          ],
        ),
      ),
    );
  }

  Widget _topStats(SimulationResult r) {
    Widget stat(String title, String value, String sub, {Color? valueColor}) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _kGoldDark)),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? _kInkText)),
            const SizedBox(height: 2),
            Text(sub,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kGoldDark)),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        stat(
          'Net Profit/Loss',
          '${r.netProfit >= 0 ? '+' : '-'}\$${_fmt(r.netProfit.abs())}',
          'Overall Outcome',
          valueColor: r.netProfit >= 0 ? _kPos : _kNeg,
        ),
        stat('Final Bankroll', '\$${_fmt(r.endingBankroll)}',
            'Starting: \$${_fmt(r.startingBankroll)}'),
        stat('Sessions Executed', _fmt(r.totalSessions), 'Completed cycles'),
        stat('Peak Bankroll', '\$${_fmt(r.highestBankroll)}',
            'Highest recorded', valueColor: _kPos),
      ],
    );
  }

  Widget _tabs() {
    final tabs = {
      'overview': 'General Overview',
      'profitability': 'Profitability',
      'bankroll': 'Bankroll Stability',
      'stages': 'Stage Penetration',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tabs.entries.map((e) {
        final active = _activeTab == e.key;
        final tab = GestureDetector(
          onTap: () => setState(() => _activeTab = e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? _kInk : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                  color: active ? _kInk : _kInkText.withValues(alpha: 0.2)),
            ),
            child: Text(e.value,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? _kGold : _kInkText)),
          ),
        );
        // Spotlight the relevant tabs during the guided tour.
        if (e.key == 'profitability') {
          return TourTarget(id: 'funnel-profit-dynamics', child: tab);
        }
        if (e.key == 'bankroll') {
          return TourTarget(id: 'funnel-bankroll-stability', child: tab);
        }
        if (e.key == 'stages') {
          return TourTarget(id: 'funnel-stage-penetration', child: tab);
        }
        return tab;
      }).toList(),
    );
  }

  Widget _tabContent(SimulationResult r) {
    switch (_activeTab) {
      case 'profitability':
        final breakEven =
            r.totalSessions - r.winningSessions - r.losingSessions;
        return _dataList('Session Profitability', [
          _row('System Success Ratio', '${r.systemSuccessRatio}%', color: _kPos),
          _row('Average Profit per Session',
              '${r.averageProfitPerSession >= 0 ? '+' : '-'}\$${_fmt(r.averageProfitPerSession.abs())}',
              color: r.averageProfitPerSession >= 0 ? _kPos : _kNeg),
          _row('Average Profit per Spin',
              '${r.averageProfitPerSpin >= 0 ? '+' : '-'}\$${_fmt(r.averageProfitPerSpin.abs())}',
              color: r.averageProfitPerSpin >= 0 ? _kPos : _kNeg),
          _row('Winning Sessions', _fmt(r.winningSessions), color: _kPos),
          _row('Losing Sessions', _fmt(r.losingSessions), color: _kNeg),
          _row('Break-even / Ghost Sessions', _fmt(breakEven)),
        ]);
      case 'bankroll':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chartCard(r),
            const SizedBox(height: 12),
            _dataList('Risk & Drawdown', [
              _row('Largest Drawdown', '-\$${_fmt(r.maxDrawdown)}', color: _kNeg),
              _row('Lowest Bankroll Reached', '\$${_fmt(r.lowestBankroll)}'),
              _row('Table Busts (Insufficient Funds)', _fmt(r.bankruptcyCount),
                  color: r.bankruptcyCount > 0 ? _kNeg : null),
            ]),
          ],
        );
      case 'stages':
        final entries = r.stageHits.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return _dataList('Stage Execution Frequency', [
          if (entries.isEmpty)
            _row('No stages were triggered', '0')
          else
            ...entries.map((e) =>
                _row('${e.key} entered', '${_fmt(e.value)} times', color: _kPos)),
        ]);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, c) {
              final meta = _dataList('Simulation Metadata', [
                _row('Requested Spins', _fmt(r.totalSpinsRequested)),
                _row('Actual Spins', _fmt(r.totalSpinsExecuted)),
                _row('Avg Spins per Session', _fmt(r.averageSpinsPerSession)),
              ]);
              final streaks = _dataList('Global Streaks', [
                _row('Max Win Streak', '${r.maxWinStreak} Sessions',
                    color: _kPos),
                _row('Max Loss Streak', '${r.maxLossStreak} Sessions',
                    color: _kNeg),
              ]);
              if (c.maxWidth < 640) {
                return Column(children: [
                  meta,
                  const SizedBox(height: 12),
                  streaks
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: meta),
                  const SizedBox(width: 12),
                  Expanded(child: streaks),
                ],
              );
            }),
          ],
        );
    }
  }

  Widget _chartCard(SimulationResult r) {
    return TourTarget(
      id: 'funnel-bankroll-chart',
      child: Container(
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
          Text('Bankroll Trajectory',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kInkText)),
          Text('Balance across all simulated sessions.',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kGoldDark)),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            width: double.infinity,
            child: r.history.length < 2
                ? Center(
                    child: Text(
                      'Not enough data points to plot a trajectory.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: _kGoldDark),
                    ),
                  )
                : CustomPaint(
                    painter: _BankrollChartPainter(r.history),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _dataList(String title, List<Widget> rows) {
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
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInkText)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGoldDark)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color ?? _kInkText)),
        ],
      ),
    );
  }

  String _fmt(num v) {
    final isNeg = v < 0;
    final abs = v.abs();
    final rounded = abs == abs.roundToDouble()
        ? abs.toInt().toString()
        : abs.toStringAsFixed(2);
    final parts = rounded.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final out = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return isNeg ? '-$out' : out;
  }
}

// ── Bankroll trajectory chart ──────────────────────────────────────────────
class _BankrollChartPainter extends CustomPainter {
  final List<Point<double>> data;
  _BankrollChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const leftPad = 48.0;
    const bottomPad = 20.0;
    const topPad = 8.0;
    const rightPad = 8.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double minX = data.first.x, maxX = data.first.x;
    double minY = data.first.y, maxY = data.first.y;
    for (final p in data) {
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minY = min(minY, p.y);
      maxY = max(maxY, p.y);
    }
    if (maxX == minX) maxX = minX + 1;
    if (maxY == minY) maxY = minY + 1;

    double px(double x) => leftPad + (x - minX) / (maxX - minX) * chartW;
    double py(double y) => topPad + (1 - (y - minY) / (maxY - minY)) * chartH;

    // Grid + y-axis labels.
    final gridPaint = Paint()
      ..color = _kInkText.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: _kInkText.withValues(alpha: 0.6),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final yy = topPad + chartH * i / gridLines;
      canvas.drawLine(Offset(leftPad, yy), Offset(size.width - rightPad, yy),
          gridPaint);
      final value = maxY - (maxY - minY) * i / gridLines;
      final tp = TextPainter(
        text: TextSpan(text: _short(value), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, yy - tp.height / 2));
    }

    // Line path.
    final linePaint = Paint()
      ..color = _kInk
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kInk.withValues(alpha: 0.18),
          _kInk.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));

    final path = Path();
    final fill = Path();
    for (int i = 0; i < data.length; i++) {
      final x = px(data[i].x);
      final y = py(data[i].y);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, topPad + chartH);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(px(data.last.x), topPad + chartH);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  String _short(double v) {
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _BankrollChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
