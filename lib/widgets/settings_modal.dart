import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/providers/game_provider.dart';

/// Modal dialog for user preferences and settings.
/// Matches the web app's visual style and options.
class SettingsModal extends StatefulWidget {
  final VoidCallback? onResetSession;
  final bool tournamentMode;

  const SettingsModal({
    super.key,
    this.onResetSession,
    this.tournamentMode = false,
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  final UserService _userService = UserService();
  final SubscriptionService _subService = SubscriptionService();
  final TextEditingController _customBankrollController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  // Local settings state
  bool _isSoundEnabled = true;
  bool _isMusicEnabled = true;
  bool _isTimerEnabled = true;
  bool _isPopupEnabled = true;
  double _startingBalance = 1000.0;
  String _tableAppearance = 'classic';
  SubscriptionStatus? _subStatus;

  // Actions state
  bool _isResettingBalance = false;
  bool _isClearingStats = false;
  bool _resetBalanceSuccess = false;
  bool _clearStatsSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final profile = await _userService.getProfile();
      final sub = await _subService.getStatus();
      if (mounted) {
        setState(() {
          _isSoundEnabled = profile.isSoundEnabled;
          _isMusicEnabled = soundEngine.isMusicEnabled;
          _isTimerEnabled = profile.isTimerEnabled;
          _isPopupEnabled = profile.isPopupEnabled;
          _startingBalance = profile.startingBalance;
          _tableAppearance = profile.tableAppearance;
          _customBankrollController.text = profile.startingBalance.toStringAsFixed(0);
          _subStatus = sub;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load preferences';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customBankrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleSetting(String key, bool value) async {
    soundEngine.playClick();
    setState(() {
      if (key == 'sound') _isSoundEnabled = value;
      if (key == 'timer') _isTimerEnabled = value;
      if (key == 'popup') _isPopupEnabled = value;
    });

    try {
      if (key == 'sound') {
        await soundEngine.setEnabled(value);
      }
      if (key == 'timer') {
        try {
          Provider.of<GameProvider>(context, listen: false).setTimerEnabled(value);
        } catch (_) {}
      }
      await _userService.updateProfile(
        isSoundEnabled: key == 'sound' ? value : null,
        isTimerEnabled: key == 'timer' ? value : null,
        isPopupEnabled: key == 'popup' ? value : null,
      );
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          if (key == 'sound') {
            _isSoundEnabled = !value;
            soundEngine.setEnabled(!value);
          }
          if (key == 'timer') {
            _isTimerEnabled = !value;
            try {
              Provider.of<GameProvider>(context, listen: false).setTimerEnabled(!value);
            } catch (_) {}
          }
          if (key == 'popup') _isPopupEnabled = !value;
        });
      }
    }
  }

  void _changeStartingBalance(double amount) {
    soundEngine.playClick();
    // Update the selection locally and keep it — mirrors the web app, where
    // startingBalance is pure client state. Persist to the server in the
    // background; a failed sync must NOT revert the selection (otherwise the
    // control snaps back to the default whenever the profile call fails).
    setState(() => _startingBalance = amount);

    unawaited(
      _userService.updateProfile(startingBalance: amount).catchError((e) {
        debugPrint('SettingsModal: Error persisting starting balance: $e');
        return false;
      }),
    );
  }

  void _changeTableAppearance(String appearance) {
    soundEngine.playClick();
    setState(() => _tableAppearance = appearance);
    try {
      Provider.of<GameProvider>(context, listen: false)
          .setTableAppearance(appearance);
    } catch (_) {
      unawaited(_userService.updateProfile(tableAppearance: appearance));
    }
  }

  Future<void> _handleResetBalance() async {
    soundEngine.playClick();
    setState(() {
      _isResettingBalance = true;
      _resetBalanceSuccess = false;
    });

    try {
      // Brief "thinking" delay to match the web app's premium feel.
      await Future.delayed(const Duration(milliseconds: 600));

      // Update the live game balance directly so the player's chips change
      // immediately (this also syncs the new balance to the server). This
      // mirrors the web app's `setBalance(startingBalance)` behaviour — the
      // previous implementation only hit the server, so the in-game chips
      // never actually updated.
      if (mounted) {
        Provider.of<GameProvider>(context, listen: false)
            .setBalance(_startingBalance);
      }

      if (mounted) {
        setState(() {
          _isResettingBalance = false;
          _resetBalanceSuccess = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _resetBalanceSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResettingBalance = false);
      }
    }
  }

  Future<void> _handleResetSession() async {
    if (widget.onResetSession == null) return;
    soundEngine.playClick();
    setState(() {
      _isClearingStats = true;
      _clearStatsSuccess = false;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onResetSession!();
      if (mounted) {
        setState(() {
          _isClearingStats = false;
          _clearStatsSuccess = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _clearStatsSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearingStats = false);
      }
    }
  }

  Future<void> _manageSubscription() async {
    final url = Uri.parse('https://junkobodieroulette.com/account/billing');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTourney = widget.tournamentMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F17),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GAME SETTINGS',
                          style: playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preferences & Options',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFF5EDD5).withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        soundEngine.playClick();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close, color: AppColors.gold, size: 24),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0x1Ac9a44c), height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null) ...[
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.rouletteRed),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Sound Effects Toggle
                            _buildToggleRow(
                              title: 'Sound Effects',
                              description: 'Game audio & clicks',
                              value: _isSoundEnabled,
                              onChanged: (val) => _toggleSetting('sound', val),
                            ),
                            const SizedBox(height: 16),

                            // Background Music Toggle
                            _buildToggleRow(
                              title: 'Background Music',
                              description: 'Continuous casino ambiance',
                              value: _isMusicEnabled,
                              onChanged: (val) async {
                                soundEngine.playClick();
                                setState(() => _isMusicEnabled = val);
                                await soundEngine.setMusicEnabled(val);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Subscription Row
                            if (_subStatus?.isAuthenticated ?? false) ...[
                              _buildSubscriptionRow(),
                              const SizedBox(height: 16),
                            ],

                            if (!isTourney) ...[
                              // Betting Timer Toggle
                              _buildToggleRow(
                                title: 'Betting Timer',
                                description: 'Auto-spin protection',
                                value: _isTimerEnabled,
                                onChanged: (val) => _toggleSetting('timer', val),
                              ),
                              const SizedBox(height: 16),

                              // Popup Screen Toggle
                              _buildToggleRow(
                                title: 'Popup Screen',
                                description: 'Winning number result screen',
                                value: _isPopupEnabled,
                                onChanged: (val) => _toggleSetting('popup', val),
                              ),
                              const SizedBox(height: 20),

                              // Starting Bankroll Segmented Control
                              Text(
                                'STARTING BANKROLL',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildSegmentedControl(),
                              const SizedBox(height: 10),
                              _buildCustomBankrollControl(),
                              const SizedBox(height: 24),

                              _buildTableAppearanceControl(),
                              const SizedBox(height: 24),

                              // Reset Account Balance Action
                              _buildActionRow(
                                title: 'Reset Account Balance',
                                description: 'Set balance back to starting amount (\$$_startingBalance)',
                                buttonText: _isResettingBalance
                                    ? 'Resetting...'
                                    : _resetBalanceSuccess
                                        ? 'Done!'
                                        : 'Reset Now',
                                isSuccess: _resetBalanceSuccess,
                                onPressed: _isResettingBalance ? null : _handleResetBalance,
                              ),
                              const SizedBox(height: 12),

                              // Reset Session Stats Action
                              if (widget.onResetSession != null)
                                _buildActionRow(
                                  title: 'Reset Session Stats',
                                  description: 'Clear session win/loss totals',
                                  buttonText: _isClearingStats
                                      ? 'Clearing...'
                                      : _clearStatsSuccess
                                          ? 'Done!'
                                          : 'Clear Now',
                                  isSuccess: _clearStatsSuccess,
                                  onPressed: _isClearingStats ? null : _handleResetSession,
                                ),
                            ],
                          ],
                        ),
                      ),
              ),

              const Divider(color: Color(0x1Ac9a44c), height: 1),

              // Footer Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      soundEngine.playClick();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFF5EDD5).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.gold,
          activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
          inactiveThumbColor: const Color(0xFFF5EDD5).withValues(alpha: 0.3),
          inactiveTrackColor: Colors.black.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSubscriptionRow() {
    final plan = _subStatus?.plan;
    final planText = plan == 'monthly'
        ? 'Monthly · \$4.99/mo'
        : plan == 'annual'
            ? 'Annual · \$54.99/yr'
            : 'No active plan';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                planText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFF5EDD5).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _manageSubscription,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(
            plan != null ? 'MANAGE' : 'SUBSCRIBE',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    final amounts = [100.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: amounts.map((amount) {
        final isSelected = _startingBalance == amount;
        final label = amount >= 1000 ? '\$${(amount / 1000).toInt()}k' : '\$${amount.toInt()}';

        return SizedBox(
          width: 72,
          child: GestureDetector(
            onTap: () {
              _customBankrollController.text = amount.toInt().toString();
              _changeStartingBalance(amount);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppColors.black : Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomBankrollControl() {
    return Row(
      children: [
        Text('Custom \$', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _customBankrollController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyCustomBankroll(),
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: _applyCustomBankroll, child: const Text('Apply')),
      ],
    );
  }

  void _applyCustomBankroll() {
    final amount = int.tryParse(_customBankrollController.text.trim());
    if (amount != null && amount > 0) _changeStartingBalance(amount.toDouble());
  }

  Widget _buildTableAppearanceControl() {
    const options = [
      ('classic', 'Classic', 'Round · Serif'),
      ('modern', 'Modern', 'Soft square · Sans'),
      ('minimal', 'Minimal', 'No badge · Clean'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TABLE APPEARANCE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Change number colors and type style. Bet areas work the same.',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final selected = _tableAppearance == option.$1;
                return InkWell(
                  onTap: () => _changeTableAppearance(option.$1),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.gold.withOpacity(0.12) : Colors.white.withOpacity(0.035),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected ? AppColors.gold : Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['17', '8', '0'].asMap().entries.map((entry) {
                            final index = entry.key;
                            final text = entry.value;
                            final isMinimal = option.$1 == 'minimal';
                            final isClassic = option.$1 == 'classic';
                            return Container(
                              width: isMinimal ? 20 : 23,
                              height: isMinimal ? 20 : 23,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isMinimal
                                    ? Colors.transparent
                                    : [const Color(0xFF9F3438), const Color(0xFF20252B), const Color(0xFF17634E)][index],
                                borderRadius: BorderRadius.circular(isClassic ? 50 : option.$1 == 'modern' ? 6 : 0),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontFamily: isClassic ? 'Georgia' : 'Arial',
                                  color: isMinimal
                                      ? [const Color(0xFFFFAAA6), Colors.white, const Color(0xFF7FE3A1)][index]
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 7),
                        Text(option.$2, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(option.$3, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 9, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required String title,
    required String description,
    required String buttonText,
    required bool isSuccess,
    required VoidCallback? onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFF5EDD5).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : AppColors.gold.withValues(alpha: 0.1),
              foregroundColor: isSuccess ? Colors.white : AppColors.gold,
              side: BorderSide(
                color: isSuccess ? Colors.green : AppColors.gold.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
