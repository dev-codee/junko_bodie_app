/// Login screen — Google OAuth + Email/Password.
///
/// Translated from `src/app/login/page.tsx`.
/// Premium dark/gold casino aesthetic.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Enforce portrait mode for Login
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (_isSignUp && password != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (_isSignUp && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      if (_isSignUp) {
        await auth.signUpWithEmail(email, password);
        if (mounted) {
          setState(() => _error = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check your email to confirm your account.'),
              backgroundColor: AppColors.gold,
            ),
          );
        }
      } else {
        await auth.signInWithEmail(email, password);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _isSignUp
            ? 'Sign up failed. Email may already be in use.'
            : 'Invalid email or password.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Text(
                      'JUNKO BODIE',
                      style: cinzelDecorative(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Roulette',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.gold.withValues(alpha: 0.7),
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Separator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 1,
                          color: AppColors.gold.withValues(alpha: 0.3),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 1,
                          color: AppColors.gold.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF5EDD5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Google Sign-In
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                        icon: const Text('G',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Email field
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        prefixIcon:
                            Icon(Icons.email_outlined, color: AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Password',
                        prefixIcon:
                            Icon(Icons.lock_outline, color: AppColors.gold),
                      ),
                    ),

                    // Confirm password (sign up only)
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline,
                              color: AppColors.gold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Error message
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.rouletteRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                AppColors.rouletteRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.rouletteRed,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleEmailSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.black,
                                ),
                              )
                            : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle sign up / sign in
                    GestureDetector(
                      onTap: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
                      child: Text.rich(
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Back to landing
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back to plans',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Legal consent notice
                    Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.35),
                          height: 1.5,
                        ),
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () async {
                                final url = Uri.parse('https://junkobodieroulette.com/terms');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: ' and ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () async {
                                final url = Uri.parse('https://junkobodieroulette.com/privacy');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: '.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
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

