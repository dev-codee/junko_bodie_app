import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2E21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4BC81)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'PRIVACY POLICY',
          style: TextStyle(
            color: Color(0xFFD4BC81),
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            _buildSection(
              title: 'Privacy Policy',
              content: 'This public privacy overview explains the types of information used to operate the simulator website and membership experience.',
            ),
            _buildSection(
              title: 'Account and membership data',
              content: 'The website may use account information, authentication status, membership status, and profile settings to provide simulator access.\n\nBilling actions are handled through Stripe checkout and customer portal flows.',
            ),
            _buildSection(
              title: 'Website analytics',
              content: 'The site may support analytics and webmaster verification tools to understand public-page performance, search visibility, and technical health.\n\nAnalytics should be configured without changing simulator, checkout, or account behavior.',
            ),
            _buildSection(
              title: 'Final legal review',
              content: 'This page is implementation-ready website copy. The business should review legal language before relying on it as final legal policy.',
            ),
            const SizedBox(height: 16),
            const Text(
              'No real-money wagering\n'
              'Unlimited practice chips\n'
              'Built by Roulette Author Junko Bodie\n'
              'Practice. Learn. Improve. Play smarter.',
              style: TextStyle(
                color: Color(0xFFD4BC81),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
