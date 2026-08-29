/// Strategies screen — Strategy Library list page.
///
/// Replicates the web app's /strategies page UI. Lists all user strategies as
/// cards with name, wheel type, stage count, description, last updated, a global
/// indicator, and Navigator / edit / hide / delete actions. Supports hiding
/// strategies (with a "Show Hidden" toggle) and importing a strategy from a
/// JSON file.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/strategy_service.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_help_button.dart';
import 'package:junko_bodie/tour/tour_registry.dart';

class StrategiesScreen extends StatefulWidget {
  const StrategiesScreen({super.key});

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  final StrategyService _service = StrategyService();

  List<BettingStrategy> _strategies = [];
  Set<String> _hiddenIds = {};
  bool _showHidden = false;
  bool _importing = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _fetchStrategies();
    // Auto-start the onboarding funnel on first visit (after prefs load).
    final tour = context.read<TourController>();
    tour.ready.then((_) {
      if (mounted) tour.maybeAutoStart('/strategies');
    });
  }

  Future<void> _fetchStrategies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchStrategies(),
        _service.fetchHiddenStrategyIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _strategies = results[0] as List<BettingStrategy>;
        _hiddenIds = (results[1] as List<String>).toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<BettingStrategy> get _visibleStrategies {
    return _strategies.where((s) {
      final id = s.id;
      if (id == null) return true;
      final hidden = _hiddenIds.contains(id);
      if (hidden && !_showHidden) return false;
      return true;
    }).toList();
  }

  Future<void> _handleDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Strategy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this strategy? This action cannot be undone.',
          style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Color(0xFFA0A0A0),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'DELETE',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteStrategy(id);
      if (!mounted) return;
      setState(() {
        _strategies.removeWhere((s) => s.id == id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  Future<void> _handleHideToggle(String id, bool currentlyHidden) async {
    // Optimistic update.
    setState(() {
      if (currentlyHidden) {
        _hiddenIds.remove(id);
      } else {
        _hiddenIds.add(id);
      }
    });
    try {
      await _service.setStrategyHidden(id, !currentlyHidden);
    } catch (e) {
      if (!mounted) return;
      // Revert on failure.
      setState(() {
        if (currentlyHidden) {
          _hiddenIds.add(id);
        } else {
          _hiddenIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  Future<void> _handleImport() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Could not read file contents.');
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      if (data['name'] == null ||
          data['wheel_type'] == null ||
          data['stages'] is! List) {
        _showSnack(
          'Invalid strategy file. Missing required fields (name, wheel_type, stages).',
          error: true,
        );
        return;
      }

      await _service.importStrategy(data);
      await _fetchStrategies();
      if (!mounted) return;
      _showSnack('Strategy "${data['name']}" imported successfully!');
    } catch (e) {
      _showSnack('Failed to import strategy: $e', error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? const Color(0xFFC0392B) : const Color(0xFF0F2E21),
      ),
    );
  }

  /// Funnel step "lib_welcome": tapping "+ New Strategy" advances the tour and
  /// opens the builder (the click-through drives its own navigation).
  void _handleNewStrategyTap() {
    final tour = context.read<TourController>();
    if (tour.currentStep?.id == 'lib_welcome') {
      tour.advanceStep('lib_welcome');
    }
    _openBuilder();
  }

  /// Open the strategy builder (new when [id] is null, edit otherwise) and
  /// refresh the library when the user returns.
  Future<void> _openBuilder({String? id}) async {
    final path = id != null && id.isNotEmpty
        ? '/strategies/build?id=$id'
        : '/strategies/build';
    await context.push(path);
    if (mounted) _fetchStrategies();
  }

  /// Open the Navigator / Debugger for a strategy (or the picker if none given).
  Future<void> _openNavigator({String? id}) async {
    final path = id != null && id.isNotEmpty
        ? '/strategies/debug?strategyId=$id'
        : '/strategies/debug';
    await context.push(path);
    if (mounted) _fetchStrategies();
  }

  /// Open the Simulation Engine setup (optionally pre-selecting a strategy).
  Future<void> _openSimulate({String? id}) async {
    final path = id != null && id.isNotEmpty
        ? '/simulation/setup?strategyId=$id'
        : '/simulation/setup';
    await context.push(path);
    if (mounted) _fetchStrategies();
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
            colors: [
              Color(0xFFFFDCA3),
              Color(0xFFDABB8B),
              Color(0xFF9E7F41),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GlowPainter()),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF0F2E21),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading strategies...',
                            style: TextStyle(
                              color: Color(0xFF6B5220),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFC0392B), size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load strategies',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPillButton(
                                label: 'RETRY',
                                icon: Icons.refresh,
                                onTap: _fetchStrategies,
                              ),
                            ],
                          ),
                        )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final visible = _visibleStrategies;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: visible.isEmpty ? _buildEmptyState() : _buildGrid(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return TourTarget(
      id: 'back-to-lobby',
      child: GestureDetector(
      onTap: () => context.go('/lobby'),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF113626).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF113626).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 14, color: Color(0xFF113626)),
            const SizedBox(width: 6),
            Text(
              'BACK TO LOBBY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFF113626).withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0, duration: 300.ms);
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackButton(),
              const SizedBox(height: 10),
              TourTarget(
                id: 'funnel-graduation-card',
                child: Text(
                  'Strategy Library',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1,
                    color: const Color(0xFF113626),
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'BUILD, SAVE, AND MANAGE YOUR CUSTOM BETTING PROGRESSIONS.',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B5220),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Header actions
        Flexible(
          flex: 3,
          child: TourTarget(
          id: 'header-actions',
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const TourHelpButton(tourId: 'library'),
              _buildShowHiddenToggle(),
              _buildPillButton(
                label: 'NAVIGATOR',
                icon: Icons.insights,
                onTap: () => _openNavigator(),
              ),
              _buildPillButton(
                label: 'SIMULATE',
                icon: Icons.play_arrow,
                onTap: () => _openSimulate(),
              ),
              _buildPillButton(
                label: _importing ? 'IMPORTING...' : 'IMPORT',
                icon: Icons.upload_file,
                onTap: _importing ? null : _handleImport,
              ),
              TourTarget(
                id: 'funnel-new-strategy',
                child: _buildPillButton(
                  label: 'NEW STRATEGY',
                  icon: Icons.add,
                  onTap: _handleNewStrategyTap,
                ),
              ),
            ],
          ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 100.ms);
  }

  Widget _buildShowHiddenToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showHidden = !_showHidden),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SHOW HIDDEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: const Color(0xFF113626).withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 20,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _showHidden
                  ? const Color(0xFF0F2E21)
                  : const Color(0xFF113626).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9999),
            ),
            alignment:
                _showHidden ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFC9A44C),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2E21),
            borderRadius: BorderRadius.circular(9999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x660F2E21),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFC9A44C)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC9A44C),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.15),
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_rounded,
            size: 40,
            color: Colors.black.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          const Text(
            'No strategies yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first staged betting strategy to use in Solo Play.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildPillButton(
            label: 'CREATE STRATEGY',
            icon: Icons.add,
            onTap: _openBuilder,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 500.ms,
          delay: 200.ms,
          curve: Curves.easeOutCubic,
        );

    // Center the card, but let it scroll if the (landscape) viewport is short.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: card),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<BettingStrategy> visible) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 500
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.6,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final strategy = visible[index];
            final hidden =
                strategy.id != null && _hiddenIds.contains(strategy.id);
            final card = _StrategyCard(
              strategy: strategy,
              index: index,
              isHidden: hidden,
              // First card doubles as the tour anchor for the library guide.
              tourAnchor: index == 0,
              onTap: () => _openBuilder(id: strategy.id),
              onNavigator: () => _openNavigator(id: strategy.id),
              onEdit: () => _openBuilder(id: strategy.id),
              onHideToggle: () {
                if (strategy.id != null) {
                  _handleHideToggle(strategy.id!, hidden);
                }
              },
              onDelete: () {
                if (strategy.id != null) _handleDelete(strategy.id!);
              },
            );
            return index == 0
                ? TourTarget(id: 'strategy-card', child: card)
                : card;
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Strategy Card
// ──────────────────────────────────────────────────────────────────────────────

class _StrategyCard extends StatefulWidget {
  final BettingStrategy strategy;
  final int index;
  final bool isHidden;
  final bool tourAnchor;
  final VoidCallback onTap;
  final VoidCallback onNavigator;
  final VoidCallback onEdit;
  final VoidCallback onHideToggle;
  final VoidCallback onDelete;

  const _StrategyCard({
    required this.strategy,
    required this.index,
    required this.isHidden,
    this.tourAnchor = false,
    required this.onTap,
    required this.onNavigator,
    required this.onEdit,
    required this.onHideToggle,
    required this.onDelete,
  });

  @override
  State<_StrategyCard> createState() => _StrategyCardState();
}

class _StrategyCardState extends State<_StrategyCard> {
  bool _isPressed = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconBtn(
          icon: Icons.insights,
          onTap: widget.onNavigator,
          tooltip: 'Open in Strategy Navigator',
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.edit_outlined,
          onTap: widget.onEdit,
          tooltip: 'Edit',
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: widget.isHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onTap: widget.onHideToggle,
          tooltip: widget.isHidden ? 'Unhide' : 'Hide',
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.delete_outline,
          onTap: widget.onDelete,
          isDanger: true,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strategy = widget.strategy;
    final stageCount = strategy.stages.length;

    return Opacity(
      opacity: widget.isHidden ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _isPressed ? 0.5 : 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isPressed ? 0.8 : 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.12 : 0.08),
                blurRadius: _isPressed ? 30 : 24,
                offset: Offset(0, _isPressed ? 12 : 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                strategy.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (strategy.isGlobal) ...[
                              const SizedBox(width: 4),
                              const Text('🌍', style: TextStyle(fontSize: 13)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strategy.wheelType} Wheel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2E21),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x660F2E21),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$stageCount STAGES',
                      style: const TextStyle(
                        color: Color(0xFFC9A44C),
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  strategy.description?.isNotEmpty == true
                      ? strategy.description!
                      : 'No description provided.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Updated: ${_formatDate(strategy.updatedAt ?? strategy.createdAt)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.45),
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    widget.tourAnchor
                        ? TourTarget(id: 'card-actions', child: _buildActions())
                        : _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (100 + widget.index * 80).ms,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 400.ms,
          delay: (100 + widget.index * 80).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Small icon button
// ──────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;
  final String? tooltip;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.isDanger = false,
    this.tooltip,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFEF4444);
    const normalColor = Color(0xFF111111);

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDanger
                    ? dangerColor.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1))
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.isDanger ? dangerColor : normalColor,
          ),
        ),
      ),
    );

    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Background glow painter
// ──────────────────────────────────────────────────────────────────────────────

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.7, 0.5),
        radius: 0.6,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRect(Offset.zero & size, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.7),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRect(Offset.zero & size, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
