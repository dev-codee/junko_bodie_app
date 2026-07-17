import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/models/player.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/services/subscription_service.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Web parchment palette ─────────────────────────────────
const Color _kPage = Color(0xFFE8D9B8);
const Color _kCard = Color(0xFFF5EDD5);
const Color _kGold = Color(0xFFC9A44C);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kInk = Color(0xFF0F2318);

const List<String> availableAvatars = [
  'default',
  'crown',
  'diamond',
  'star',
  'spade',
  'heart',
  'club',
  'dice',
  'chip',
  'trophy',
  'bolt'
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final SubscriptionService _subService = SubscriptionService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _showSuccess = false;

  Player? _profile;
  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = 'default';
  SubscriptionStatus? _subStatus;
  int? _seasonRank;
  int _seasonPoints = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _userService.getProfile();
      final sub = await _subService.getStatus();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.username;
          _selectedAvatar =
              profile.avatarUrl.isNotEmpty ? profile.avatarUrl : 'default';
          _subStatus = sub;
          _seasonRank = profile.season.rank;
          _seasonPoints = profile.season.points;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load member profile';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final success = await _userService.updateProfile(
        name: name,
        avatarUrl: _selectedAvatar,
      );
      if (success && mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) context.go('/lobby');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to update registry. Please try again.';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _manageSubscription() async {
    final url = Uri.parse('https://junkobodieroulette.com/account/billing');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _subscribeNow() => context.push('/subscribe');

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse('https://junkobodieroulette.com/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTermsOfService() async {
    final url = Uri.parse('https://junkobodieroulette.com/terms');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text(
          'Sign Out',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: _kInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _kInk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kGoldDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: _kInk,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.go('/');
    }
  }

  Future<void> _handleDeleteAccount() async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 24),
            SizedBox(width: 10),
            Text(
              'Delete Account',
              style: TextStyle(
                fontFamily: 'Georgia',
                color: Color(0xFFC0392B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your account, including:\n\n'
          '• Your player profile and username\n'
          '• All play-money balance and session history\n'
          '• Tournament records and rankings\n'
          '• Saved strategies\n'
          '• Your subscription (if active)\n\n'
          'This action cannot be undone.',
          style: TextStyle(color: _kInk, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kGoldDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation — type "DELETE"
    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeleteConfirmDialog(
        cardColor: _kCard,
        inkColor: _kInk,
        goldColor: _kGold,
      ),
    );

    if (secondConfirm != true || !mounted) return;

    // Perform deletion
    try {
      setState(() => _isSaving = true);
      await context.read<AuthProvider>().deleteAccount();
      // GoRouter redirect automatically handles sign out routing.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to delete account. Please try again or contact support.';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kPage,
        body: Center(
          child: Text(
            'LOADING REGISTRY...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _kInk,
              letterSpacing: 2.0,
            ),
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: _kPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Failed to load member profile',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600, color: _kInk),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: _kInk,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildCard(profile),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dark green header bar ──────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _kInk,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 3, 16, 3),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/lobby'),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.chevron_left, color: _kGold, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'JUNKO BODIE',
            style: GoogleFonts.inter(
              color: const Color(0xFFF2E8D0),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Text('|', style: TextStyle(color: _kGold.withValues(alpha: 0.5))),
          const SizedBox(width: 10),
          Text(
            'MEMBER REGISTRY',
            style: GoogleFonts.inter(
              color: _kGold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cream parchment card ───────────────────────────────────
  Widget _buildCard(Player profile) {
    return Container(
      width: 1380,
      decoration: BoxDecoration(
        color: _kCard,
        border: Border.all(color: _kGold, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: _kGold.withValues(alpha: 0.18), spreadRadius: 5),
          const BoxShadow(color: Color(0x26000000), blurRadius: 40, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(64, 30, 64, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // OFFICIAL PROTOCOL ID
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 70, height: 1, color: _kGold.withValues(alpha: 0.3)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OFFICIAL PROTOCOL ID',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kGoldDark.withValues(alpha: 0.8),
                    letterSpacing: 5,
                  ),
                ),
              ),
              Container(width: 70, height: 1, color: _kGold.withValues(alpha: 0.3)),
            ],
          ),
          const SizedBox(height: 6),
          // MEMBER PROFILE title
          const Text(
            'Member Profile',
            style: TextStyle(
              fontFamily: 'Georgia',
              color: _kInk,
              fontSize: 46,
              fontWeight: FontWeight.w700,
              height: 1.0,
              fontFeatures: [FontFeature.enable('smcp')],
            ),
          ),
          const SizedBox(height: 22),
          // Two columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 360, child: _buildLeftColumn(profile)),
              const SizedBox(width: 36),
              Expanded(child: _buildRightColumn()),
            ],
          ),
          const SizedBox(height: 22),
          // Authorize button
          _buildSaveButton(),
          const SizedBox(height: 24),
          // Account actions (Sign Out, Delete Account, Legal Links)
          _buildAccountActions(),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(Player profile) {
    final isCustomAvatar =
        _selectedAvatar.startsWith('http') || _selectedAvatar.startsWith('/');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with camera badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF111722),
                border: Border.all(color: _kGold, width: 6),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: ClipOval(
                child: isCustomAvatar
                    ? Image.network(
                        _selectedAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, color: _kGold, size: 60),
                      )
                    : Center(child: _buildAvatarIcon(_selectedAvatar, size: 64, color: _kGold)),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kInk,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kGold, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: _kGold, size: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // IDENTITY NAME
        Text(
          'IDENTITY NAME',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kGoldDark.withValues(alpha: 0.6),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            maxLength: 20,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kInk.withValues(alpha: 0.05),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _kGold, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _kGoldDark, width: 2.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // MERITS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MERITS:',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kGoldDark.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 14),
            _buildBadgeIcon('Founder', profile.badges.founder),
            const SizedBox(width: 10),
            _buildBadgeIcon('Champion', profile.badges.champion),
            const SizedBox(width: 10),
            _buildBadgeIcon('Elite', profile.badges.eliteStatus),
            const SizedBox(width: 10),
            _buildBadgeIcon('All-Time', profile.badges.allTimeChampion),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Season standings
        _buildWhiteCard(
          icon: Icons.emoji_events_outlined,
          title: 'SEASON STANDINGS',
          child: Row(
            children: [
              Expanded(
                child: _buildStat(
                  'GLOBAL RANK',
                  _seasonRank != null && _seasonRank! > 0 ? '#$_seasonRank' : '#—',
                  const Color(0xFFB8892E),
                ),
              ),
              Container(width: 1, height: 48, color: _kGold.withValues(alpha: 0.15)),
              Expanded(
                child: _buildStat('TOTAL POINTS', _seasonPoints.toString(), _kInk),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Membership
        _buildMembershipCard(),
        const SizedBox(height: 14),
        // Icon picker
        Text(
          'SELECT PROTOCOL ICON',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kGoldDark.withValues(alpha: 0.6),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        _buildIconPicker(),
      ],
    );
  }

  Widget _buildWhiteCard({
    required IconData icon,
    required String title,
    Widget? badge,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _kInk),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge],
              ],
            ),
          ),
          Divider(height: 1, color: _kGold.withValues(alpha: 0.2)),
          child,
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kGoldDark.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard() {
    final bool hasPlan = _subStatus?.plan != null;
    return _buildWhiteCard(
      icon: Icons.credit_card_outlined,
      title: 'MEMBERSHIP STATUS',
      badge: _buildSubscriptionBadge(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              hasPlan
                  ? (_subStatus!.plan == 'monthly'
                      ? 'Monthly · \$4.99/mo'
                      : 'Annual · \$54.99/yr')
                  : "You don't have an active membership.\nSubscribe to unlock full simulator and tournament access.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                color: Color(0x99000000),
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: hasPlan ? _manageSubscription : _subscribeNow,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: hasPlan
                    ? _kInk.withValues(alpha: 0.04)
                    : _kGold.withValues(alpha: 0.12),
                border: Border(top: BorderSide(color: _kGold.withValues(alpha: 0.18))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasPlan ? 'MANAGE SUBSCRIPTION' : 'SUBSCRIBE NOW',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: 2,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 15, color: _kInk),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    final bool isActive = _subStatus?.hasAccess ?? false;
    final String text = (_subStatus?.status ?? 'inactive').toUpperCase();
    final Color color = isActive ? const Color(0xFF166534) : const Color(0xFF374151);
    final Color bg = isActive
        ? const Color(0xFF22C55E).withValues(alpha: 0.1)
        : const Color(0xFF6B7280).withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Icons.check_circle : Icons.cancel, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: availableAvatars.map((avatar) {
          final isSelected = _selectedAvatar == avatar;
          return GestureDetector(
            onTap: () => setState(() => _selectedAvatar = avatar),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? _kGold : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(color: _kGold.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
              child: Center(
                child: _buildAvatarIcon(
                  avatar,
                  size: 22,
                  color: isSelected ? _kInk : _kInk.withValues(alpha: 0.3),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: 480,
      height: 60,
      child: GestureDetector(
        onTap: (_isSaving || _showSuccess) ? null : _handleSave,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: _showSuccess
                ? const LinearGradient(colors: [Color(0xFF2E9E5B), Color(0xFF1B6E3C)])
                : const LinearGradient(
                    colors: [
                      Color(0xFFF9E7B9),
                      Color(0xFFD4AC4A),
                      Color(0xFFC9941E),
                      Color(0xFF8A5E0A),
                    ],
                    stops: [0.0, 0.45, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0x66FFFFFF)),
            // Sharp dark bottom edge + soft drop shadow (uniform border is
            // required when a borderRadius is set).
            boxShadow: const [
              BoxShadow(color: Color(0xFF6B4A08), offset: Offset(0, 5)),
              BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Text(
            _isSaving
                ? 'VERIFYING IDENTITY...'
                : _showSuccess
                    ? 'IDENTITY VERIFIED ✓'
                    : 'AUTHORIZE & UPDATE REGISTRY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _showSuccess ? Colors.white : _kInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    return Column(
      children: [
        // Divider
        Container(
          width: 200,
          height: 1,
          color: _kGold.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 18),
        // Sign Out & Delete Account Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sign Out
            GestureDetector(
              onTap: _handleSignOut,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: _kInk.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kInk.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, size: 16, color: _kInk.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Delete Account
            GestureDetector(
              onTap: _handleDeleteAccount,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC0392B).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_forever, size: 16, color: const Color(0xFFC0392B).withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Account',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC0392B).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Legal Links
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _openPrivacyPolicy,
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kGoldDark.withValues(alpha: 0.6),
                  decoration: TextDecoration.underline,
                  decorationColor: _kGoldDark.withValues(alpha: 0.4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '·',
                style: TextStyle(
                  color: _kGoldDark.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openTermsOfService,
              child: Text(
                'Terms of Service',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kGoldDark.withValues(alpha: 0.6),
                  decoration: TextDecoration.underline,
                  decorationColor: _kGoldDark.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'v1.0.0',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: _kGoldDark.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeIcon(String label, bool active) {
    IconData iconData;
    switch (label) {
      case 'Founder':
        iconData = Icons.star_rounded;
        break;
      case 'Champion':
        iconData = Icons.emoji_events_rounded;
        break;
      case 'Elite':
        iconData = Icons.shield_rounded;
        break;
      default:
        iconData = Icons.verified_rounded;
    }
    return Tooltip(
      message: label,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? _kGold.withValues(alpha: 0.12) : _kInk.withValues(alpha: 0.05),
          border: Border.all(
            color: active ? _kGold : _kInk.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
        child: Icon(
          iconData,
          size: 18,
          color: active ? _kGoldDark : _kInk.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildAvatarIcon(String type, {required double size, Color? color}) {
    final c = color ?? _kInk;
    switch (type) {
      case 'default':
        return Icon(Icons.person, size: size, color: c);
      case 'crown':
        return Icon(Icons.workspace_premium, size: size, color: c);
      case 'diamond':
        return Icon(Icons.diamond, size: size, color: c);
      case 'star':
        return Icon(Icons.star, size: size, color: c);
      case 'spade':
        return Text('♠', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'heart':
        return Text('♥', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'club':
        return Text('♣', style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w900));
      case 'dice':
        return Icon(Icons.casino, size: size, color: c);
      case 'chip':
        return Icon(Icons.album, size: size, color: c);
      case 'trophy':
        return Icon(Icons.emoji_events, size: size, color: c);
      case 'bolt':
        return Icon(Icons.bolt, size: size, color: c);
      default:
        return Icon(Icons.person, size: size, color: c);
    }
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  final Color cardColor;
  final Color inkColor;
  final Color goldColor;

  const _DeleteConfirmDialog({
    required this.cardColor,
    required this.inkColor,
    required this.goldColor,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.cardColor,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      title: const Text(
        'Final Confirmation',
        style: TextStyle(
          fontFamily: 'Georgia',
          color: Color(0xFFC0392B),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type DELETE to confirm account deletion:',
              style: TextStyle(color: widget.inkColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: widget.inkColor, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.65),
                hintText: 'DELETE',
                hintStyle: TextStyle(color: widget.inkColor.withValues(alpha: 0.4), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.goldColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.goldColor.withValues(alpha: 0.5), width: 1),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFC0392B), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B6914))),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().toUpperCase() == 'DELETE') {
              Navigator.of(context).pop(true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC0392B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Delete My Account'),
        ),
      ],
    );
  }
}
