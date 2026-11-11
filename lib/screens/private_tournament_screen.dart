import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/models/private_tournament_access.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/widgets/private_tournament_shell.dart';

class PrivateTournamentScreen extends StatefulWidget {
  final TournamentService? service;
  const PrivateTournamentScreen({super.key, this.service});
  @override
  State<PrivateTournamentScreen> createState() =>
      _PrivateTournamentScreenState();
}

class _PrivateTournamentScreenState extends State<PrivateTournamentScreen> {
  late final TournamentService _service = widget.service ?? TournamentService();
  final _code = TextEditingController();
  PrivateTournamentAccess? _access;
  String _wheel = 'american';
  String? _error;
  bool _loading = true;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _service.privateAccess();
      if (mounted) setState(() => _access = access);
    } catch (e) {
      if (mounted) {
        setState(() => _error = privateTournamentError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter(bool join) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tournament = join
          ? await _service.joinPrivate(_code.text.trim())
          : await _service.createPrivate(_wheel);
      if (!mounted) return;
      context.go(
        tournament.status == 'active'
            ? '/tournament/${tournament.id}'
            : '/tournament/private/${tournament.id}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = privateTournamentError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    return PrivateTournamentShell(
      title: 'Play with Friends',
      onBack: () => context.go('/lobby'),
      children: [
        const Text(
          'Your friends. Your table.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Invite 2–6 players with a six-digit code. No bots. Five rounds of five spins. With fewer than six players, eliminations begin later so the final is in round five. Virtual chips only.',
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(color: const Color(0xFF8B2920)),
            ),
          ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (access == null)
          FilledButton(onPressed: _load, child: const Text('Retry'))
        else if (access.currentTournamentId != null) ...[
          const Text(
            'You already have a private tournament. Return to play, or leave its waiting room before joining another.',
          ),
          FilledButton(
            onPressed: () =>
                context.go('/tournament/private/${access.currentTournamentId}'),
            child: const Text('Return to tournament'),
          ),
        ] else ...[
          Text(
            access.hasAccess
                ? 'Private tournaments are included in your membership.'
                : access.freeAvailable
                ? 'Your free entry is available. It is used only when the host starts.'
                : !access.freeEmailEligible
                ? 'A verified Gmail, Outlook, Hotmail, iCloud, or Proton Mail address is required for a free entry. Other emails can play with a membership.'
                : 'Your free entry has been used or reserved by another account with the same email.',
          ),
          if (!access.canEnter)
            FilledButton(
              onPressed: () => context.push('/subscribe'),
              child: const Text('View membership'),
            ),
          const SizedBox(height: 20),
          _entryOptions(access),
        ],
        const SizedBox(height: 24),
        const Text(
          'Free entry: one per eligible verified email, with no subscription, trial or card needed. Waiting rooms expire after two hours. Private matches do not award public championship points.',
        ),
        TextButton(
          onPressed: _loading || _busy ? null : _load,
          child: const Text('Refresh access'),
        ),
      ],
    );
  }

  Widget _entryOptions(PrivateTournamentAccess access) {
    final create = _entryCard('Create a Tournament', Icons.add_circle_outline, [
      const Text('Choose your wheel, then invite your friends.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _wheel,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Wheel'),
        items: const [
          DropdownMenuItem(
            value: 'american',
            child: Text('American (0 and 00)'),
          ),
          DropdownMenuItem(value: 'european', child: Text('European (0)')),
        ],
        onChanged: _busy || !access.canEnter
            ? null
            : (value) => setState(() => _wheel = value!),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: !_busy && access.canEnter ? () => _enter(false) : null,
        child: Text(_busy ? 'Connecting…' : 'Create a Tournament'),
      ),
    ]);
    final join = _entryCard('Join a Tournament', Icons.group_outlined, [
      const Text('Enter the six-digit code shared by your host.'),
      const SizedBox(height: 16),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        enabled: !_busy && access.canEnter,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Six-digit joining code',
          hintText: '000000',
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: !_busy && access.canEnter && _code.text.length == 6
            ? () => _enter(true)
            : null,
        child: const Text('Join a Tournament'),
      ),
    ]);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 680
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: create),
                const SizedBox(width: 20),
                Expanded(child: join),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [create, const SizedBox(height: 16), join],
            ),
    );
  }

  Widget _entryCard(String title, IconData icon, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          border: Border.all(color: const Color(0x80C9A44C)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF8B6914)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
}
