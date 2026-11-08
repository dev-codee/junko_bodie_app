import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/services/api_service.dart';
import 'package:junko_bodie/widgets/private_tournament_shell.dart';

class PrivateTournamentLobbyScreen extends StatefulWidget {
  final String tournamentId;
  final TournamentService? service;
  final Future<String?> Function()? loadPlayerId;
  const PrivateTournamentLobbyScreen({
    super.key,
    required this.tournamentId,
    this.service,
    this.loadPlayerId,
  });
  @override
  State<PrivateTournamentLobbyScreen> createState() =>
      _PrivateTournamentLobbyScreenState();
}

class _PrivateTournamentLobbyScreenState
    extends State<PrivateTournamentLobbyScreen>
    with WidgetsBindingObserver {
  late final TournamentService _service = widget.service ?? TournamentService();
  Tournament? _tournament;
  String? _playerId, _error;
  Timer? _timer;
  bool _fetching = false, _busy = false, _copied = false, _navigating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadIdentity();
    _poll();
    _resumePolling();
  }

  Future<void> _loadIdentity() async {
    try {
      final id = widget.loadPlayerId != null
          ? await widget.loadPlayerId!()
          : (await UserService().getProfile()).id;
      if (mounted) setState(() => _playerId = id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load your profile. Tap Retry.');
      }
    }
  }

  void _resumePolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _resumePolling();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_fetching || _navigating) return;
    _fetching = true;
    try {
      final details = await _service.getTournamentDetails(widget.tournamentId);
      if (!mounted || _navigating) return;
      final t = details.tournament;
      if (!t.isPrivate || t.status == 'active' || t.status == 'completed') {
        _navigating = true;
        _timer?.cancel();
        context.go('/tournament/${widget.tournamentId}');
        return;
      }
      setState(() {
        _tournament = t;
        _error = null;
      });
      if (t.lobbyClosed) _timer?.cancel();
    } catch (e) {
      if (mounted) {
        setState(() => _error = privateTournamentError(e));
      }
      if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
        _timer?.cancel();
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _action(bool start) async {
    if (_busy || _navigating) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (start) {
        await _service.startPrivate(widget.tournamentId);
        await _poll();
      } else {
        await _service.leavePrivate(widget.tournamentId);
        if (mounted) {
          _navigating = true;
          _timer?.cancel();
          context.go('/tournament/private');
        }
      }
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
    final t = _tournament;
    final host = _playerId != null && t?.hostId == _playerId;
    return PrivateTournamentShell(
      title: 'Private tournament',
      onBack: () => context.go('/tournament/private'),
      children: [
        if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              _loadIdentity();
              _poll();
              _resumePolling();
            },
            child: const Text('Retry'),
          ),
        ],
        if (t == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (t != null && t.lobbyClosed) ...[
          const Text('This lobby is closed', style: TextStyle(fontSize: 26)),
          const Text(
            'No free entry was used. You can create or join another tournament.',
          ),
          FilledButton(
            onPressed: () => context.go('/tournament/private'),
            child: const Text('Play with Friends'),
          ),
        ] else if (t != null) ...[
          Text(
            '${t.wheelType == 'european' ? 'European' : 'American'} roulette · No bots',
          ),
          const SizedBox(height: 16),
          const Text('Share this code with your friends'),
          SelectableText(
            t.joinCode ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              letterSpacing: 6,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE1BD62),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: t.joinCode ?? ''));
                if (mounted) setState(() => _copied = true);
              } catch (_) {
                if (mounted) {
                  setState(
                    () => _error = 'Please select and copy the code above.',
                  );
                }
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(_copied ? 'Code copied' : 'Copy code'),
          ),
          Text(
            '${t.players.length}/${t.maxPlayers} players · Minimum ${t.minPlayers} to start',
          ),
          const Text(
            '5 rounds · 5 spins per round. With fewer than six players, eliminations begin later.',
          ),
          for (final p in t.players)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(p.username),
              trailing: Text(p.playerId == t.hostId ? 'Host' : 'Ready'),
            ),
          if (_playerId == null)
            TextButton(
              onPressed: _loadIdentity,
              child: const Text('Retry loading your profile'),
            ),
          if (host)
            FilledButton(
              onPressed: !_busy && t.players.length >= t.minPlayers
                  ? () => _action(true)
                  : null,
              child: Text(_busy ? 'Please wait…' : 'Start tournament'),
            )
          else
            const Text('Waiting for the host to start…'),
          OutlinedButton(
            onPressed: _busy || _playerId == null ? null : () => _action(false),
            child: Text(host ? 'Cancel tournament' : 'Leave lobby'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Free entries are used only when the host starts. Leaving or cancelling beforehand keeps them available. The lobby expires after two hours.',
          ),
        ],
      ],
    );
  }
}
