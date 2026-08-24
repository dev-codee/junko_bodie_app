/// Simulation Test Results History — replicates the web /simulation/history page.
///
/// Lists the most recent stored backtests for a strategy; each row shows the net
/// profit and a performance grade, and opens the full dashboard on tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:junko_bodie/screens/simulation_run_screen.dart';
import 'package:junko_bodie/services/simulation_history_service.dart';

const Color _kInk = Color(0xFF0F2E21);
const Color _kInkText = Color(0xFF113626);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF6B5220);
const Color _kPos = Color(0xFF16A34A);
const Color _kNeg = Color(0xFFEF4444);

class SimulationHistoryScreen extends StatefulWidget {
  final String? strategyId;
  const SimulationHistoryScreen({super.key, this.strategyId});

  @override
  State<SimulationHistoryScreen> createState() =>
      _SimulationHistoryScreenState();
}

class _SimulationHistoryScreenState extends State<SimulationHistoryScreen> {
  final SimulationHistoryService _service = SimulationHistoryService();
  List<SimulationResult> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  Future<void> _load() async {
    if (widget.strategyId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final h = await _service.getHistory(widget.strategyId!);
    if (!mounted) return;
    setState(() {
      _history = h;
      _isLoading = false;
    });
  }

  ({String grade, String label, Color color}) _grade(SimulationResult r) {
    final roi = r.startingBankroll > 0 ? r.netProfit / r.startingBankroll : 0;
    if (roi >= 0.20) return (grade: 'A', label: 'Exceptional', color: _kPos);
    if (roi > 0) return (grade: 'B', label: 'Good', color: _kGold);
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
                      const SizedBox(height: 4),
                      Text(
                        'Review the most recent backtests for this strategy.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kGoldDark),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _history.isEmpty
                            ? _emptyState()
                            : ListView.separated(
                                itemCount: _history.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) =>
                                    _runRow(_history[i], i),
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
        GestureDetector(
          onTap: () {
            final id = widget.strategyId;
            context.go(id != null ? '/strategies/build?id=$id' : '/strategies');
          },
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
                const Icon(Icons.arrow_back, size: 13, color: _kInkText),
                const SizedBox(width: 6),
                Text('BACK TO STRATEGY',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _kInkText)),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text('Test Results History',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: _kInkText)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 44, color: _kInk.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text('No Simulation History',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kInkText)),
            const SizedBox(height: 6),
            Text(
              'Run a simulation for this strategy to generate your first report.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _kGoldDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runRow(SimulationResult r, int index) {
    final g = _grade(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kInk.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kInk.withValues(alpha: 0.1)),
            ),
            child: Text('#${index + 1}',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kInkText)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simulation Output ${index == 0 ? '(Latest)' : ''}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInkText)),
                Text(
                    '${_fmt(r.totalSpinsExecuted)} Spins • ${_fmt(r.totalSessions)} Sessions',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kGoldDark)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('NET PROFIT',
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: _kGoldDark)),
              Text(
                '${r.netProfit >= 0 ? '+' : '-'}\$${_fmt(r.netProfit.abs())}',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: r.netProfit >= 0 ? _kPos : _kNeg),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: g.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${g.grade} · ${g.label}',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: g.color)),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => context.push(
              '/simulation/run',
              extra: SimulationRunArgs(result: r, fromHistory: true),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _kInk,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('VIEW DETAILS',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _kGold)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(num v) {
    final abs = v.abs();
    final rounded = abs == abs.roundToDouble()
        ? abs.toInt().toString()
        : abs.toStringAsFixed(2);
    final parts = rounded.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
