import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'TERMS OF SERVICE',
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
              title: 'Terms',
              content: 'These terms summarize the intended simulator-only use of Junko Bodie Roulette and the public website.',
            ),
            _buildSection(
              title: 'Simulator access',
              content: 'Junko Bodie Roulette provides access to a play-money roulette simulator and tournament-style practice features.\n\nVirtual chips are for simulator use only and have no real-world cash value.',
            ),
            _buildSection(
              title: 'Membership',
              content: 'Membership provides simulator access according to the selected subscription plan and any active trial terms shown at checkout.\n\nSubscription checkout, billing updates, and cancellation flows are handled through the existing billing system.',
            ),
            _buildSection(
              title: 'Acceptable use',
              content: 'Users should not misuse the service, attempt to bypass account controls, or treat simulator results as guaranteed real-world outcomes.\n\nThe business should review this page before treating it as final legal terms.',
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
