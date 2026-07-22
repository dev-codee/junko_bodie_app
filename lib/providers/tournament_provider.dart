import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/models/round.dart';
import 'package:junko_bodie/models/spin.dart';
import 'package:junko_bodie/models/player.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/logic/bets.dart';

const List<String> playerColors = [
  '#2563EB', // Sapphire Blue
  '#059669', // Emerald Green
  '#991B1B', // Deep Crimson
  '#7C3AED', // Amethyst Purple
  '#0D9488', // Deep Teal
  '#475569', // Storm Slate
];

class TournamentProvider extends ChangeNotifier {
  final TournamentService _tournamentService = TournamentService();
  final UserService _userService = UserService();

  Player? currentUserProfile;
  TournamentDetails? _details;

  int currentRound = 1;
  int currentSpin = 1;
  final int totalSpins = 5;
  String phase = 'waiting';

  List<dynamic> scores = [];
  int timeRemaining = 45;
  List<dynamic> botBets = [];
  String? roundId;
  dynamic lastSpinResult;
  List<dynamic> allSpinBets = [];
  dynamic lastPlayerPayout;
  TournamentPlayer? eliminatedPlayer;
  int lobbyTimeRemaining = 30;

  Map<String, PlacedBet> bets = {};
  Map<String, PlacedBet> lastSpinBets = {};
  List<dynamic> history = [];
  bool showResult = false;
  List<Map<String, dynamic>> events = [];
  String wheelType = 'american';
  String connectionStatus = 'connected';
  bool isLoading = true;
  String? error;

  double selectedChip = 5.0;
  final List<Map<String, dynamic>> _betPlacementHistory = [];
  bool deleteMode = false;
  String? fundError;

  // Timers and internal state
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  Timer? _lobbyTimer;
  final List<Timer> _botTimers = [];
  int _serverTimeOffset = 0;
  int _bettingDeadline = 0;
  String? _dismissedSpinId;
  String? _spinSubmittedKey;
  String? _lastResetKey;
  String? _generatedKey;
  bool _hasRestoredBets = false;
  bool _isFetching = false;
  int _consecutiveErrors = 0;
  final Map<String, Set<String>> _otherPlayerBets = {};
  bool _requestingFirstRound = false;
  String? _announcedLeaderId;
  String? _announcedElimId;
  final List<String> _announcedBettingSpins = [];

  double get totalBet => bets.values.fold(0.0, (sum, b) => sum + b.amount);

  Tournament? get tournament => _details?.tournament;
  Round? get activeRound => _details?.activeRound;
  Spin? get latestSpin => _details?.latestSpin;

  List<TournamentPlayer> get activePlayers =>
      tournament?.players.where((p) => p.status == 'active').toList() ?? [];

  List<TournamentPlayer> get eliminatedPlayers =>
      tournament?.players.where((p) => p.status == 'eliminated').toList() ?? [];

  TournamentPlayer? get me {
    if (tournament == null || currentUserProfile == null) return null;
    final String myId = currentUserProfile!.id ?? '';
    final String myUsername = currentUserProfile!.username;

    // Find the player entry that matches user ID or username
    for (var p in tournament!.players) {
      if (!p.isBot) {
        if ((myId.isNotEmpty && p.playerId == myId) ||
            p.username == myUsername) {
          return p;
        }
      }
    }
    // Fallback: first non-bot player
    return tournament!.players.firstWhere(
      (p) => !p.isBot,
      orElse: () => tournament!.players.first,
    );
  }

  TournamentProvider() {
    _init();
  }

  Future<void> _init() async {
    await fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      currentUserProfile = await _userService.getProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentProvider: Error fetching user profile: $e');
    }
  }

  void selectChip(double chipValue) {
    selectedChip = chipValue;
    soundEngine.playThump();
    notifyListeners();
  }

  void placeBet(String betId) {
    if (phase != 'betting' && phase != 'waiting') return;

    final mePlayer = me;
    if (mePlayer == null) return;

    final double myBalance = mePlayer.currentChips;
    final double projectedTotalBet = totalBet + selectedChip;

    if (projectedTotalBet > myBalance) {
      fundError = 'Insufficient chips for this bet';
      soundEngine.playDeniedSound();
      notifyListeners();
      return;
    }

    final existing = bets[betId];
    if (existing != null) {
      bets[betId] = PlacedBet(
        betId: betId,
        amount: existing.amount + selectedChip,
        chips: [...existing.chips, selectedChip],
      );
    } else {
      bets[betId] = PlacedBet(
        betId: betId,
        amount: selectedChip,
        chips: [selectedChip],
      );
    }

    _betPlacementHistory.add({'betId': betId, 'amount': selectedChip});
    fundError = null;

    // Surface my own bet in the live feed (mirrors the web's handlePlaceBet,
    // which pushes an event so the player sees their own bets in the feed too).
    _addEvent({
      'username': mePlayer.username,
      'amount': selectedChip,
      'betId': betId,
      'betZone': betId,
      'color': _myColor(),
    });

    notifyListeners();

    // Sync intermediate bets with the server
    _syncBetsDebounced();
  }

  /// The current player's assigned feed/marker color, looked up from the live
  /// scores (falls back to gold). Mirrors the web's `myColor`.
  String _myColor() {
    final String? myId = me?.playerId;
    final String? myUsername = me?.username;
    for (final s in scores) {
      if (s is! Map) continue;
      final bool isMe =
          (myId != null && s['player_id']?.toString() == myId) ||
          (myUsername != null &&
              s['username'] == myUsername &&
              s['is_bot'] != true);
      if (isMe) return (s['color'] ?? '#c9a44c').toString();
    }
    return '#c9a44c';
  }

  void removeBet(String betId) {
    if (phase != 'betting' && phase != 'waiting') return;

    final existing = bets[betId];
    if (existing == null || existing.chips.isEmpty) return;

    final chips = List<double>.from(existing.chips);
    final removedChip = chips.removeLast();
    final newAmount = existing.amount - removedChip;

    if (chips.isEmpty) {
      bets.remove(betId);
    } else {
      bets[betId] = PlacedBet(betId: betId, amount: newAmount, chips: chips);
    }

    notifyListeners();
    _syncBetsDebounced();
  }

  void clearBets() {
    if (phase != 'betting' && phase != 'waiting') return;
    bets.clear();
    _betPlacementHistory.clear();
    deleteMode = false;
    notifyListeners();
    _syncBetsDebounced();
  }

  /// Toggle delete mode — while active, tapping a bet zone removes its bet.
  void toggleDeleteMode() {
    if (phase != 'betting' && phase != 'waiting') return;
    deleteMode = !deleteMode;
    soundEngine.playSwoosh();
    notifyListeners();
  }

  /// Remove all chips from a single bet zone (used by delete mode).
  void clearZone(String betId) {
    if (phase != 'betting' && phase != 'waiting') return;
    if (!bets.containsKey(betId)) return;
    bets.remove(betId);
    _betPlacementHistory.removeWhere((e) => e['betId'] == betId);
    if (bets.isEmpty) deleteMode = false;
    soundEngine.playSwoosh();
    notifyListeners();
    _syncBetsDebounced();
  }

  void undo() {
    if (phase != 'betting' && phase != 'waiting') return;
    if (_betPlacementHistory.isEmpty) return;

    final lastAction = _betPlacementHistory.removeLast();
    final String betId = lastAction['betId'];
    final double amount = lastAction['amount'];

    final existing = bets[betId];
    if (existing != null) {
      final chips = List<double>.from(existing.chips);
      if (chips.isNotEmpty && chips.last == amount) {
        chips.removeLast();
        final newAmount = existing.amount - amount;
        if (chips.isEmpty) {
          bets.remove(betId);
        } else {
          bets[betId] = PlacedBet(
            betId: betId,
            amount: newAmount,
            chips: chips,
          );
        }
      }
    }
    notifyListeners();
    _syncBetsDebounced();
  }

  void doubleAllBets() {
    if (phase != 'betting' && phase != 'waiting') return;

    final mePlayer = me;
    if (mePlayer == null) return;

    final double myBalance = mePlayer.currentChips;
    final double projectedTotalBet = totalBet * 2;

    if (projectedTotalBet > myBalance) {
      fundError = 'Insufficient chips to double bets';
      soundEngine.playDeniedSound();
      notifyListeners();
      return;
    }

    final String myColor = _myColor();
    final newBets = <String, PlacedBet>{};
    bets.forEach((betId, existing) {
      newBets[betId] = PlacedBet(
        betId: betId,
        amount: existing.amount * 2,
        chips: [...existing.chips, ...existing.chips],
      );
      // Broadcast the added amount to the live feed (mirrors the web).
      _addEvent({
        'username': mePlayer.username,
        'amount': existing.amount,
        'betId': betId,
        'betZone': betId,
        'color': myColor,
      });
    });
    bets = newBets;
    fundError = null;
    notifyListeners();
    _syncBetsDebounced();
  }

  void rebet() {
    if (phase != 'betting' && phase != 'waiting') return;
    if (lastSpinBets.isEmpty) return;

    final mePlayer = me;
    if (mePlayer == null) return;

    final double myBalance = mePlayer.currentChips;
    final double lastTotal = lastSpinBets.values.fold(
      0.0,
      (sum, b) => sum + b.amount,
    );

    if (lastTotal > myBalance) {
      fundError = 'Insufficient chips to rebet';
      soundEngine.playDeniedSound();
      notifyListeners();
      return;
    }

    bets = Map<String, PlacedBet>.from(lastSpinBets);
    fundError = null;
    soundEngine.playRebetSound();

    // Broadcast each rebet zone to the live feed (mirrors the web).
    final String myColor = _myColor();
    bets.forEach((betId, bet) {
      _addEvent({
        'username': mePlayer.username,
        'amount': bet.amount,
        'betId': betId,
        'betZone': betId,
        'color': myColor,
      });
    });

    notifyListeners();
    _syncBetsDebounced();
  }

  Timer? _debounceSyncTimer;
  void _syncBetsDebounced() {
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(milliseconds: 500), () {
      final tournamentId = tournament?.id;
      final mePlayer = me;
      if (tournamentId != null && mePlayer != null) {
        final formattedBets = bets.values
            .map(
              (b) => {'betId': b.betId, 'amount': b.amount, 'chips': b.chips},
            )
            .toList();
        _tournamentService.syncBets(
          tournamentId,
          mePlayer.playerId,
          formattedBets,
        );
      }
    });
  }

  Future<void> createOrJoinTournament(String type) async {
    // Guard: if we're already in a tournament that's running or active,
    // don't spin up a second polling loop. Reuse the existing one.
    if (tournament != null &&
        (tournament!.status == 'waiting' || tournament!.status == 'active') &&
        _pollingTimer != null &&
        _pollingTimer!.isActive) {
      debugPrint(
        '[TournamentProvider] createOrJoinTournament skipped — already in tournament ${tournament!.id} (status=${tournament!.status})',
      );
      return;
    }

    // Cancel any leftover timers from a previous tournament before starting
    // a fresh one. Prevents two polling loops fighting over state.
    stopPolling();

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await fetchUserProfile();

      final Tournament tourney = await _tournamentService
          .createOrJoinTournament(type);
      wheelType = tourney.wheelType ?? 'american';

      // Clear local state
      bets.clear();
      lastSpinBets.clear();
      events.clear();
      botBets.clear();
      scores.clear();
      _betPlacementHistory.clear();
      _spinSubmittedKey = null;
      _lastResetKey = null;
      _generatedKey = null;
      _hasRestoredBets = false;
      _announcedLeaderId = null;
      _announcedElimId = null;
      _announcedBettingSpins.clear();

      await loadTournament(tourneyId: tourney.id);
      _startPolling(tourney.id!);
      _startLobbyTimer();
    } catch (e) {
      error = _friendlyError(e);
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  static String _friendlyError(Object e) {
    final String raw = e.toString();
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'You need to be signed in to start a tournament. Please sign out and sign in again, or make sure the backend server is reachable.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Cannot reach the tournament server. Check your connection or start the Next.js backend.';
    }
    return 'Failed to start matchmaking: $raw';
  }

  void _startPolling(String tourneyId) {
    _pollingTimer?.cancel();
    debugPrint('[TournamentProvider] startPolling tourneyId=$tourneyId');
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Background adaptive frequency check
      final isOffline = connectionStatus == 'offline';
      final int interval = isOffline ? 3 : 1;

      if (timer.tick % interval == 0) {
        loadTournament(tourneyId: tourneyId);
      }
    });
  }

  /// Public entry point for screens to ensure polling is running for a given
  /// tournament id. Idempotent — calling twice is safe.
  void ensurePolling(String tourneyId) {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _startPolling(tourneyId);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lobbyTimer?.cancel();
    _lobbyTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cancelBotTimers();
  }

  void _cancelBotTimers() {
    for (var t in _botTimers) {
      t.cancel();
    }
    _botTimers.clear();
  }

  Future<void> loadTournament({String? tourneyId}) async {
    final tId = tourneyId ?? tournament?.id;
    if (tId == null || _isFetching) return;

    _isFetching = true;
    final wasOffline =
        connectionStatus == 'offline' || connectionStatus == 'reconnecting';
    if (wasOffline) {
      connectionStatus = 'reconnecting';
      notifyListeners();
    }

    try {
      final data = await _tournamentService.getTournamentDetails(tId);
      _details = data;

      // Diagnostic: confirm the polling loop is actually receiving data and
      // help pinpoint where the timer / bot reveals / events stop flowing.
      assert(() {
        debugPrint(
          '[TournamentProvider] poll tId=$tId serverPhase=${data.calculatedPhase} '
          'status=${data.tournament.status} round=${data.tournament.currentRound} '
          'spinsDone=${data.activeRound?.spinsCompleted ?? 0} '
          'bettingDeadline=${data.bettingDeadline} '
          'botBets=${(data.activeRound?.botBets as List?)?.length ?? 0}',
        );
        return true;
      }());

      final String serverPhase = data.calculatedPhase;
      currentRound = data.tournament.currentRound;
      wheelType = data.tournament.wheelType ?? 'american';
      history = data.history;
      _serverTimeOffset =
          data.serverTime - DateTime.now().millisecondsSinceEpoch;

      // Reconnect recovery
      if (wasOffline) {
        phase = serverPhase;
        _spinSubmittedKey = null;
        _lastResetKey = null;
        _generatedKey = null;
        _hasRestoredBets = false;
        showResult = false;
        _dismissedSpinId = null;
        botBets.clear();
        bets.clear();
        allSpinBets.clear();
        lastPlayerPayout = null;
        _otherPlayerBets.clear();
        connectionStatus = 'connected';
        _consecutiveErrors = 0;
      } else {
        _consecutiveErrors = 0;
        connectionStatus = 'connected';
      }

      // Restore local bets once on load
      final mePlayer = me;
      if (!_hasRestoredBets &&
          bets.isEmpty &&
          mePlayer != null &&
          phase == 'betting') {
        final List<dynamic>? serverPendingBets = mePlayer.pendingBets;
        if (serverPendingBets != null && serverPendingBets.isNotEmpty) {
          _hasRestoredBets = true;
          bets.clear();
          for (var b in serverPendingBets) {
            final String betId = b['betId'] ?? '';
            final double amount = (b['amount'] ?? 0.0).toDouble();
            final List<double> chips =
                (b['chips'] as List<dynamic>?)
                    ?.map((c) => (c as num).toDouble())
                    .toList() ??
                [amount];

            final existing = bets[betId];
            if (existing != null) {
              bets[betId] = PlacedBet(
                betId: betId,
                amount: existing.amount + amount,
                chips: [...existing.chips, ...chips],
              );
            } else {
              bets[betId] = PlacedBet(
                betId: betId,
                amount: amount,
                chips: chips,
              );
            }
          }
        }
      }

      // Lobby countdown
      if (data.tournament.status == 'waiting') {
        final createdTime = data.tournament.createdAt.millisecondsSinceEpoch;
        final serverTimeNow =
            DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
        final int elapsed = ((serverTimeNow - createdTime) / 1000).floor();
        lobbyTimeRemaining = math.max(0, 30 - elapsed);
      }

      // Sync spins completed
      int spinsDone = data.activeRound?.spinsCompleted ?? 0;
      int actualSpin = spinsDone + 1;

      if ((phase == 'spinning' ||
              phase == 'result' ||
              serverPhase == 'spinning' ||
              serverPhase == 'result') &&
          data.latestSpin != null) {
        if (data.latestSpin!.roundId.toString() ==
            data.activeRound?.id.toString()) {
          actualSpin = data.latestSpin!.spinNumber;
        }
      }
      currentSpin = math.min(5, actualSpin);

      // Betting deadlines
      if (serverPhase == 'betting') {
        _bettingDeadline = data.bettingDeadline;
      } else {
        _bettingDeadline = 0;
        timeRemaining = 0;
      }

      // ── Auto-start the first round ──────────────────────────────────
      // Mirrors the web client (TournamentContext.tsx): when the server
      // says the tournament is active but no round document exists yet,
      // POST /round/start to create round 1. The watchdog in the GET
      // handler activates the tournament but does NOT create the round —
      // that's the client's job, identical on web and mobile.
      if (data.tournament.status == 'active' &&
          serverPhase == 'betting' &&
          data.activeRound == null &&
          !_requestingFirstRound) {
        _requestingFirstRound = true;
        unawaited(
          _tournamentService
              .startRound(tId)
              .then((_) {
                debugPrint(
                  '[TournamentProvider] First round /round/start succeeded',
                );
              })
              .catchError((e) {
                debugPrint('[TournamentProvider] /round/start failed: $e');
              })
              .whenComplete(() {
                _requestingFirstRound = false;
              }),
        );
      }

      // Phase changes & priority logic
      _syncPhaseAndTimer(serverPhase, data);
      _updateScores(data);
      _updateOtherPlayersBets(data);
      _scheduleBotReveals(data);

      error = null;
      isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _consecutiveErrors++;
      error = e.toString();
      debugPrint(
        '[TournamentProvider] loadTournament error #$_consecutiveErrors: $e',
      );
      assert(() {
        debugPrint('$st');
        return true;
      }());
      if (_consecutiveErrors >= 2 && connectionStatus == 'connected') {
        connectionStatus = 'offline';
      }
      isLoading = false;
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  void _syncPhaseAndTimer(String serverPhase, TournamentDetails data) {
    const Map<String, double> phasePriority = {
      'waiting': 0,
      'betting': 1,
      'locked': 2,
      'spinning': 3,
      'round_complete': 3.5,
      'result': 4,
      'elimination': 5,
      'completed': 6,
    };

    final double currentPriority = phasePriority[phase] ?? 0;
    final double serverPriority = phasePriority[serverPhase] ?? 0;

    // Transitioning from betting/locked -> spinning: Save bets for rebet, clear current wagers
    if ((serverPhase == 'spinning' || serverPhase == 'result') &&
        (phase == 'betting' || phase == 'locked')) {
      if (bets.isNotEmpty) {
        lastSpinBets = Map<String, PlacedBet>.from(bets);
        bets.clear();
        _hasRestoredBets = true;
      }
    }

    if (serverPhase == 'betting' &&
        (phase == 'spinning' || phase == 'result')) {
      // Keep wheel animating/result active until manual dismissal
      if (activeRound?.bettingEndsAt != null) {
        final deadlineTime = activeRound!.bettingEndsAt.millisecondsSinceEpoch;
        final serverTimeNow =
            DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
        if (deadlineTime - serverTimeNow < 40000) {
          phase = 'betting';
        }
      }
    } else if (serverPhase == 'betting' && phase == 'locked') {
      // Wait for server to advance
    } else if (serverPhase == 'result' && phase == 'spinning') {
      // Local spin plays until completeSpin is called
    } else if (serverPriority > currentPriority || serverPhase == 'betting') {
      final spinId =
          data.latestSpin?.id ??
          '${data.latestSpin?.roundId}-${data.latestSpin?.spinNumber}';
      if (serverPhase == 'result' && _dismissedSpinId == spinId) {
        phase = currentSpin == 5 ? 'result' : 'betting';
      } else {
        phase = serverPhase;
        if (serverPhase == 'result' &&
            data.latestSpin != null &&
            data.latestSpin!.roundId == data.activeRound?.id) {
          // Sync spin result
          _captureSpinResult(data.latestSpin!);
        }
      }
    }

    // Result popup visibility
    if (serverPhase == 'spinning') {
      if (phase != 'result') showResult = false;
      if (data.latestSpin != null &&
          data.latestSpin!.roundId == data.activeRound?.id) {
        _captureSpinResult(data.latestSpin!);
      }
    } else if (serverPhase == 'result') {
      final spinId =
          data.latestSpin?.id ??
          '${data.latestSpin?.roundId}-${data.latestSpin?.spinNumber}';
      if (spinId != _dismissedSpinId && phase != 'spinning') {
        showResult = true;
      }
    }

    // Capture spin results for late joiners or refreshes
    if ((serverPhase == 'spinning' || serverPhase == 'result') &&
        data.latestSpin != null &&
        phase != 'result' &&
        phase != 'spinning') {
      if (data.latestSpin!.roundId == data.activeRound?.id) {
        _captureSpinResult(data.latestSpin!);
      }
    }

    // Announce leader / phase events
    _triggerSoundAnnouncements();
    _startCountdownTimer();
  }

  void _captureSpinResult(Spin spin) {
    final newSpinId = spin.id ?? '${spin.roundId}-${spin.spinNumber}';
    if (lastSpinResult == null || lastSpinResult['id'] != newSpinId) {
      lastSpinResult = {
        'id': newSpinId,
        // spin.result is a SpinResult object; consumers read ['number'] as an
        // int (e.g. RNG.getDisplayNumber). Store the winning number, not the
        // whole object, or the int cast throws at build time.
        'number': spin.result.number,
        'displayNumber': spin.result.displayNumber,
        'spin_number': spin.spinNumber,
        'round_id': spin.roundId,
        'player_results': spin.playerResults,
      };

      final List<dynamic> combinedBets = [];
      for (var pr in spin.playerResults) {
        combinedBets.addAll(pr.betsPlaced);
      }
      allSpinBets = combinedBets;

      // Deduce my payout if page refreshed into result phase
      if (phase == 'result') {
        final myResult = _findMyPlayerResult(spin.playerResults);
        if (myResult != null) {
          final double netChange = myResult.netChange;
          final double totalWagered = myResult.betsPlaced.fold<double>(
            0.0,
            (sum, b) => sum + ((b is Map ? b['amount'] : b) ?? 0.0).toDouble(),
          );
          lastPlayerPayout = {
            'netResult': netChange,
            'totalWagered': totalWagered,
            'totalReturned': netChange + totalWagered,
          };
        }
      }
    }
  }

  PlayerResult? _findMyPlayerResult(List<PlayerResult>? results) {
    if (results == null || currentUserProfile == null) return null;
    final String myId = currentUserProfile!.id ?? '';
    final String myUsername = currentUserProfile!.username;

    for (var pr in results) {
      final String pid = pr.playerId;
      if (myId.isNotEmpty && pid == myId) {
        return pr;
      }

      // Lookup in tournament players as fallback
      final tp = tournament?.players.firstWhere(
        (p) => p.playerId == pid,
        orElse: () => TournamentPlayer(
          playerId: '',
          username: '',
          avatarUrl: '',
          isBot: false,
          startingChips: 0,
          currentChips: 0,
          status: '',
        ),
      );
      if (tp != null && !tp.isBot && tp.username == myUsername) {
        return pr;
      }
    }
    return null;
  }

  void _triggerSoundAnnouncements() {
    final spinKey = '$currentRound-$currentSpin';

    // Clear and trigger place bets audio
    if (phase == 'betting') {
      if (_lastResetKey != spinKey) {
        _lastResetKey = spinKey;
        bets.clear();
        allSpinBets.clear();
        lastSpinResult = null;
        _hasRestoredBets = true;
        events.clear();
        _otherPlayerBets.clear();
        notifyListeners();
      }

      if (!_announcedBettingSpins.contains(spinKey)) {
        _announcedBettingSpins.add(spinKey);
        if (_announcedBettingSpins.length > 10)
          _announcedBettingSpins.removeAt(0);

        final bool isVeryStart = currentRound == 1 && currentSpin == 1;
        final bool isNewRound = currentRound > 1 && currentSpin == 1;
        final int delay = isVeryStart ? 2800 : (isNewRound ? 2500 : 500);

        Future.delayed(Duration(milliseconds: delay), () {
          final mePlayer = me;
          if (phase == 'betting' &&
              (mePlayer == null || mePlayer.status == 'active') &&
              !isVeryStart) {
            soundEngine.playPlaceBetsSound();
          }
        });
      }
    }

    // Leader announcements
    final isEndOfRound = currentSpin == 5;
    if (phase == 'betting' || (phase == 'result' && !isEndOfRound)) {
      final leader = _findLeader(scores);
      if (leader != null &&
          leader['player_id'].toString() != _announcedLeaderId) {
        if (_announcedLeaderId != null) {
          if (phase == 'betting') {
            Future.delayed(const Duration(milliseconds: 1800), () {
              if (phase == 'betting') {
                soundEngine.announceNewLeader(leader['username']);
              }
            });
          } else {
            soundEngine.announceNewLeader(leader['username']);
          }
        }
        _announcedLeaderId = leader['player_id'].toString();
      }
    }

    // Elimination announcements
    if (eliminatedPlayer != null && phase == 'elimination') {
      final expectedElimRound = currentRound == 5
          ? (tournament?.status == 'completed' ? 5 : 4)
          : (currentRound - 1);
      if (eliminatedPlayer!.eliminatedRound == expectedElimRound) {
        final elimId = eliminatedPlayer!.playerId;
        if (_announcedElimId != elimId) {
          final int roundNumber =
              eliminatedPlayer!.eliminatedRound ?? (currentRound - 1);
          final bool isMe =
              currentUserProfile != null &&
              ((currentUserProfile!.id != null &&
                      elimId == currentUserProfile!.id) ||
                  (eliminatedPlayer!.username == currentUserProfile!.username &&
                      !eliminatedPlayer!.isBot));

          final leader = _findLeader(scores);
          String? newLeaderName;
          if (leader != null &&
              leader['player_id'].toString() != _announcedLeaderId) {
            if (_announcedLeaderId != null) {
              newLeaderName = leader['username'];
            }
            _announcedLeaderId = leader['player_id'].toString();
          }

          soundEngine.announceRoundEnd(
            eliminatedName: eliminatedPlayer!.username,
            roundNumber: roundNumber,
            isMe: isMe,
            nextRoundNumber: currentRound,
            newLeaderName: newLeaderName,
          );
          _announcedElimId = elimId;
        }
      }
    } else if (phase == 'betting') {
      _announcedElimId = null;
    }
  }

  void _updateScores(TournamentDetails data) {
    final players = List<TournamentPlayer>.from(data.tournament.players);

    // Sort active players by chips desc, eliminated by rank position asc
    final active = players.where((p) => p.status == 'active').toList()
      ..sort((a, b) => b.currentChips.compareTo(a.currentChips));
    final eliminated = players.where((p) => p.status == 'eliminated').toList()
      ..sort(
        (a, b) => (a.finalPosition ?? 10).compareTo(b.finalPosition ?? 10),
      );

    final sortedList = [...active, ...eliminated];

    scores = sortedList.asMap().entries.map((entry) {
      final index = entry.key;
      final p = entry.value;

      // Color based on original index in server players list
      final originalIndex = data.tournament.players.indexWhere(
        (tp) => tp.playerId == p.playerId,
      );
      final String color =
          playerColors[originalIndex >= 0
              ? originalIndex % playerColors.length
              : index % playerColors.length];

      // Current wagers
      double currentWager = 0.0;
      final bool isMe =
          currentUserProfile != null &&
          ((currentUserProfile!.id != null &&
                  p.playerId == currentUserProfile!.id) ||
              (p.username == currentUserProfile!.username && !p.isBot));

      if (p.isBot) {
        currentWager = botBets
            .where((bb) => bb['player_id'] == p.playerId)
            .fold<double>(
              0.0,
              (sum, bb) => sum + (bb['amount'] ?? 0.0).toDouble(),
            );
      } else if (isMe) {
        currentWager = totalBet;
      } else {
        currentWager =
            p.pendingBets?.fold<double>(
              0.0,
              (sum, b) => sum + ((b as Map)['amount'] ?? 0.0).toDouble(),
            ) ??
            0.0;
      }

      return {
        'player_id': p.playerId,
        'username': p.username,
        'chips': p.currentChips,
        'rank': p.status == 'active' ? index + 1 : (p.finalPosition ?? 0),
        'is_bot': p.isBot,
        'status': p.status,
        'final_position': p.finalPosition,
        'has_champion_badge': p.hasChampionBadge,
        'color': color,
        'currentWager': currentWager,
        'points_earned': p.pointsEarned,
        'avatar_url': p.avatarUrl,
        'eliminated_round': p.eliminatedRound,
      };
    }).toList();

    // Eliminated player tracker
    final elims = players.where((p) => p.status == 'eliminated').toList()
      ..sort(
        (a, b) => (b.eliminatedRound ?? 0).compareTo(a.eliminatedRound ?? 0),
      );
    if (elims.isNotEmpty) {
      eliminatedPlayer = elims.first;
    }
  }

  void _updateOtherPlayersBets(TournamentDetails data) {
    if (phase != 'betting' && phase != 'locked') {
      _otherPlayerBets.clear();
      return;
    }

    for (var p in data.tournament.players) {
      if (p.isBot) continue;

      final bool isMe =
          currentUserProfile != null &&
          ((currentUserProfile!.id != null &&
                  p.playerId == currentUserProfile!.id) ||
              (p.username == currentUserProfile!.username && !p.isBot));
      if (isMe) continue;

      final serverBets = p.pendingBets;
      if (serverBets == null || serverBets.isEmpty) continue;

      final String pid = p.playerId;
      if (!_otherPlayerBets.containsKey(pid)) {
        _otherPlayerBets[pid] = {};
      }
      final seenSet = _otherPlayerBets[pid]!;

      // Compare indexes
      final List<String> currentKeys = [];
      for (int i = 0; i < serverBets.length; i++) {
        final b = serverBets[i];
        currentKeys.add('${b['betId']}::${b['amount']}::$i');
      }

      final newBets = currentKeys.where((k) => !seenSet.contains(k)).toList();
      final originalPlayers = data.tournament.players;
      final pIdx = originalPlayers.indexWhere((tp) => tp.playerId == pid);
      final String playerColor =
          playerColors[pIdx >= 0 ? pIdx % playerColors.length : 0];

      for (var key in newBets) {
        seenSet.add(key);
        final int idx = currentKeys.indexOf(key);
        final b = serverBets[idx];

        _addEvent({
          'username': p.username,
          'amount': (b['amount'] ?? 0.0).toDouble(),
          'betId': b['betId'] ?? '',
          'color': playerColor,
          'betZone': b['betId'],
        });
      }
    }
  }

  void _scheduleBotReveals(TournamentDetails data) {
    if (phase != 'betting' || data.activeRound?.botBets == null) return;

    final spinKey = '$currentRound-$currentSpin';
    if (_generatedKey == spinKey) return;
    _generatedKey = spinKey;

    _cancelBotTimers();
    botBets.clear();

    // Filters bots bets for current spin & active bots
    final rawBotBets = (data.activeRound!.botBets as List<dynamic>).where((b) {
      final int spinNum = b['spin_number'] ?? 1;
      if (spinNum != currentSpin) return false;
      final botPlayer = data.tournament.players.firstWhere(
        (p) => p.playerId.toString() == b['player_id'].toString(),
        orElse: () => TournamentPlayer(
          playerId: '',
          username: '',
          avatarUrl: '',
          isBot: true,
          startingChips: 0,
          currentChips: 0,
          status: 'eliminated',
        ),
      );
      return botPlayer.status == 'active' && botPlayer.currentChips > 0;
    }).toList();

    // Clamps bot wagers to their current balance
    final playerBetMap = <String, Map<String, dynamic>>{};
    for (var b in rawBotBets) {
      final String pid = b['player_id'].toString();
      if (!playerBetMap.containsKey(pid)) {
        // Use orElse to avoid a StateError when the player_id isn't in the
        // current roster (can happen briefly during round transitions).
        final botPlayer = data.tournament.players.firstWhere(
          (p) => p.playerId.toString() == pid,
          orElse: () => TournamentPlayer(
            playerId: pid,
            username: '',
            avatarUrl: '',
            isBot: true,
            startingChips: 0,
            currentChips: 0,
            status: 'eliminated',
          ),
        );
        playerBetMap[pid] = {'bets': [], 'balance': botPlayer.currentChips};
      }
      playerBetMap[pid]!['bets'].add(b);
    }

    final List<Map<String, dynamic>> spinBotBets = [];
    playerBetMap.forEach((pid, map) {
      final List<dynamic> betsList = map['bets'];
      final double balance = map['balance'];
      final double totalWager = betsList.fold(
        0.0,
        (sum, b) => sum + (b['amount'] ?? 0.0),
      );

      if (totalWager <= balance) {
        spinBotBets.addAll(betsList.map((e) => Map<String, dynamic>.from(e)));
      } else {
        double remaining = balance;
        for (var b in betsList) {
          if (remaining <= 0) break;
          final double amount = (b['amount'] ?? 0.0).toDouble();
          final double clamped = math.min(amount, remaining);
          spinBotBets.add({
            ...Map<String, dynamic>.from(b),
            'amount': clamped,
            'chips': [clamped],
          });
          remaining -= clamped;
        }
      }
    });

    final int serverNow =
        DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
    final int startTime = _bettingDeadline - 30000;
    final int elapsed = math.max(0, serverNow - startTime);

    for (var bet in spinBotBets) {
      final int intendedDelay = bet['reveal_at_ms'] ?? 0;
      final int remainingDelay = math.max(0, intendedDelay - elapsed);
      final int finalDelay = remainingDelay > 0
          ? remainingDelay
          : (math.Random().nextDouble() * 1000).floor();

      final timer = Timer(Duration(milliseconds: finalDelay), () {
        final String pid = bet['player_id'].toString();
        final pIdx = data.tournament.players.indexWhere(
          (tp) => tp.playerId.toString() == pid,
        );
        final String playerColor =
            playerColors[pIdx >= 0 ? pIdx % playerColors.length : 0];

        // Add to botBets layout
        if (!botBets.any((b) => b['betId'] == bet['betId'])) {
          botBets.add({
            'player_id': bet['player_id'],
            'username': bet['username'],
            'betId': bet['betId'],
            'amount': bet['amount'],
            'chips': bet['chips'],
          });

          _addEvent({
            'username': bet['username'],
            'amount': (bet['amount'] ?? 0.0).toDouble(),
            'betId': bet['betId'] ?? '',
            'color': playerColor,
            'betZone': bet['betId'],
          });
          notifyListeners();
        }
      });
      _botTimers.add(timer);
    }
  }

  void _addEvent(Map<String, dynamic> event) {
    final newEvent = {
      ...event,
      'id':
          '${event['betId']}-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(100000)}',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    events.insert(0, newEvent);
    if (events.length > 20) {
      events.removeLast();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_bettingDeadline <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      final int serverNow =
          DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
      final int remaining = math.max(
        0,
        ((_bettingDeadline - serverNow) / 1000).ceil(),
      );

      if (remaining != timeRemaining) {
        timeRemaining = remaining;
        notifyListeners();

        // Auto lock at zero
        if (remaining == 0 && phase == 'betting') {
          final spinKey = '$currentRound-$currentSpin';
          if (_spinSubmittedKey != spinKey) {
            submitBets(bets);
          }
        }
      }
    });
  }

  void _startLobbyTimer() {
    _lobbyTimer?.cancel();
    // Local fallback start time so the countdown ticks even when the server
    // response is missing or the tournament object hasn't materialized yet.
    final int fallbackStart = DateTime.now().millisecondsSinceEpoch;
    lobbyTimeRemaining = 30;
    notifyListeners();

    _lobbyTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Stop once we've moved past the waiting phase (e.g. tournament went active).
      if (tournament != null && tournament!.status != 'waiting') {
        _lobbyTimer?.cancel();
        return;
      }

      final int referenceStart = tournament?.createdAt != null
          ? tournament!.createdAt.millisecondsSinceEpoch
          : fallbackStart;
      final int nowMs =
          DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
      final int elapsed = ((nowMs - referenceStart) / 1000).floor();
      final int remaining = math.max(0, 30 - elapsed);

      if (remaining != lobbyTimeRemaining) {
        lobbyTimeRemaining = remaining;
        notifyListeners();
      }
    });
  }

  Future<void> submitBets(Map<String, PlacedBet> currentBets) async {
    final tourneyId = tournament?.id;
    final rId = activeRound?.id;
    if (tourneyId == null || rId == null || me == null) return;

    final spinKey = '$currentRound-$currentSpin';
    if (_spinSubmittedKey == spinKey) return;
    _spinSubmittedKey = spinKey;

    phase = 'locked';
    soundEngine.playLockSound();
    notifyListeners();

    try {
      final formattedBets = currentBets.values
          .map((b) => {'betId': b.betId, 'amount': b.amount, 'chips': b.chips})
          .toList();

      final success = await _tournamentService.lockBets(
        tourneyId,
        me!.playerId,
        formattedBets,
        rId,
      );
      if (!success) {
        // Fallback
        phase = 'betting';
        _spinSubmittedKey = null;
        notifyListeners();
      }
    } catch (e) {
      phase = 'betting';
      _spinSubmittedKey = null;
      notifyListeners();
    }
  }

  void completeSpin() {
    phase = 'result';
    showResult = true;
    _bettingDeadline = 0;

    final myResult = _findMyPlayerResult(
      lastSpinResult?['player_results'] as List<PlayerResult>?,
    );
    if (myResult != null) {
      final double netChange = myResult.netChange;
      final double totalWagered = myResult.betsPlaced.fold<double>(
        0.0,
        (sum, b) => sum + ((b is Map ? b['amount'] : b) ?? 0.0).toDouble(),
      );

      lastPlayerPayout = {
        'netResult': netChange,
        'totalWagered': totalWagered,
        'totalReturned': netChange + totalWagered,
      };

      if (netChange > 0) {
        soundEngine.playWinSound();
      } else if (netChange < 0) {
        soundEngine.playLossSound();
      }
    }

    notifyListeners();
  }

  void dismissResult() {
    if (lastSpinResult?['id'] != null) {
      _dismissedSpinId = lastSpinResult['id'];
    }
    showResult = false;

    if (phase == 'result') {
      if (currentSpin == totalSpins) {
        loadTournament(); // Poll to trigger elimination
      } else {
        phase = 'betting';
      }
    }
    notifyListeners();
  }

  Future<void> declareWinner() async {
    final tourneyId = tournament?.id;
    if (tourneyId == null) return;

    try {
      phase = 'completed';
      notifyListeners();
    } catch (_) {
      phase = 'completed';
      notifyListeners();
    }
  }

  Future<void> updateWheelType(String type) async {
    final tourneyId = tournament?.id;
    if (tourneyId == null) return;

    wheelType = type;
    notifyListeners();

    try {
      await _tournamentService.updateWheelType(tourneyId, type);
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

/// Find the active first-place entry in a loosely-typed scores list.
///
/// Returns `null` if no such entry exists. Avoids
/// `firstWhere(..., orElse: () => null)` which fails Dart's strict type
/// inference on a non-nullable element type.
Map<String, dynamic>? _findLeader(List<dynamic> scores) {
  for (final s in scores) {
    if (s is Map && s['rank'] == 1 && s['status'] == 'active') {
      return Map<String, dynamic>.from(s);
    }
  }
  return null;
}
