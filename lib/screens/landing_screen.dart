/// Landing / Pricing screen.
///
/// Translated from `src/app/page.tsx`.
/// Shows the subscription plans and CTA for new users.
/// Authenticated users with subscription are redirected to /lobby by the router.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/config/theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String _plan = 'monthly'; // 'monthly' or 'annual'

  @override
  void initState() {
    super.initState();
    // Enforce portrait mode for Landing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  String get _priceLabel => _plan == 'monthly' ? '\$4.99' : '\$54.99';
  String get _cadenceLabel => _plan == 'monthly' ? '/ month' : '/ year';
  String get _membershipLabel =>
      _plan == 'monthly' ? 'MONTHLY MEMBERSHIP' : 'ANNUAL MEMBERSHIP';

  void _handleAction() {
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.15),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Join Junko Bodie Roulette',
                      style: playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF5EDD5),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Unlimited simulator play, tournament practice, and strategy testing for one simple membership.',
                      style: TextStyle(
                        color: const Color(0xFFF5EDD5).withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Plan toggle
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PlanTab(
                              label: 'Monthly',
                              active: _plan == 'monthly',
                              onTap: () => setState(() => _plan = 'monthly'),
                            ),
                            _PlanTab(
                              label: 'Annual · save 8%',
                              active: _plan == 'annual',
                              onTap: () => setState(() => _plan = 'annual'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Plan card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.18),
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _membershipLabel,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.gold,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _priceLabel,
                                  key: ValueKey(_priceLabel),
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _cadenceLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFFF5EDD5)
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Trial badge
                          const Text(
                            'INCLUDES 7-DAY FREE TRIAL',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Features
                          ...[
                            'Unlimited solo play',
                            'Tournament access',
                            'American & European roulette modes',
                            'Strategy testing tools',
                            'Cancel anytime',
                          ].map((feature) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.gold, width: 1),
                                      ),
                                      child: const Center(
                                        child: Text('✓',
                                            style: TextStyle(
                                                color: AppColors.gold,
                                                fontSize: 9)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFFF5EDD5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),

                          const SizedBox(height: 16),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 8,
                                shadowColor:
                                    AppColors.gold.withValues(alpha: 0.25),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sign up to subscribe',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Disclaimer
                    Center(
                      child: Text(
                        'Secure checkout. No chips. No gambling.\nSimulator access only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFF5EDD5)
                              .withValues(alpha: 0.4),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login link
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFF5EDD5)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/login'),
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PlanTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: active
                ? AppColors.black
                : const Color(0xFFF5EDD5).withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
