import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Lifecycle Observer specifically for managing game audio state.
class AppAudioLifecycleObserver extends WidgetsBindingObserver {
  final AudioEngine _audioEngine;
  AppAudioLifecycleObserver(this._audioEngine);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _audioEngine.handleAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      _audioEngine.handleAppForeground();
    }
  }
}

/// AudioEngine — Manages all game sound effects and music.
/// Replaces the React/Howler.js implementation with Flutter native tools.
class AudioEngine {
  bool _enabled = true;
  bool _musicEnabled = true;
  bool _blocked = false;
  String? _activeBackground;
  bool _isDucked = false;

  // Sound effects player pool
  static const int _sfxPoolSize = 6;
  final List<AudioPlayer> _sfxPlayers = List.generate(
    _sfxPoolSize,
    (_) => AudioPlayer(),
  );
  int _nextSfxIndex = 0;
  // Background music player
  final AudioPlayer _bgMusicPlayer = AudioPlayer();

  // Spin sound effect player
  final AudioPlayer _spinPlayer = AudioPlayer();

  // Text-To-Speech (TTS)
  final FlutterTts flutterTts = FlutterTts();
  final List<Map<String, String>> _speechQueue = [];
  bool _isProcessingQueue = false;

  // Trackers for TTS callbacks & async tasks
  Completer<void>? _ttsCompleter;

  // Getters for settings states
  bool get isEnabled => _enabled;
  bool get isMusicEnabled => _musicEnabled;
  bool get isBlocked => _blocked;
  String? get activeBackground => _activeBackground;

  // Audio asset paths
  static const Map<String, String> _paths = {
    'chip': 'sounds/soundreality-pen-click-411629.mp3',
    'spin': 'sounds/spin.mp3',
    'win': 'sounds/win.mp3',
    'loss': 'sounds/lose.mp3',
    'click': 'sounds/click.mp3',
    'swoosh':
        'sounds/dheerajakam4jor-swoosh-sound-effect-for-fight-scenes-or-transitions-1-149889.mp3',
    'btnSpin':
        'sounds/skyscraper_seven-click-buttons-ui-menu-sounds-effects-button-7-203601.mp3',
    'btn2X': 'sounds/universfield-new-notification-026-380249.mp3',
    'lock': 'sounds/lock.mp3',
    'thump':
        'sounds/skyscraper_seven-click-buttons-ui-menu-sounds-effects-button-7-203601.mp3',
    'denied': 'sounds/denied.mp3',
    'placeBets': 'sounds/placeBets.mp3',
    'background': 'sounds/background.mp3',
    'waitingBackground': 'sounds/waiting_background.mp3',
    'tourneyBackground': 'sounds/tourney_background.mp3',
    'entryBackground': 'sounds/background_entery.mp3',
  };

  // Base volumes matching Howler.js configuration
  static const Map<String, double> _volumes = {
    'chip': 0.45,
    'spin': 0.25,
    'win': 0.5,
    'loss': 0.4,
    'click': 0.4,
    'swoosh': 0.7,
    'btnSpin': 0.7,
    'btn2X': 0.7,
    'lock': 0.6,
    'thump': 0.8,
    'denied': 0.5,
    'placeBets': 0.8,
    'background': 0.5,
    'waitingBackground': 0.6,
    'tourneyBackground': 0.65,
    'entryBackground': 0.3,
  };

  /// Initialize AudioEngine preferences, observe visibility state, and configure TTS.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('is_sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('is_music_enabled') ?? true;
    } catch (e) {
      debugPrint('AudioEngine: Error loading preferences: $e');
    }

    // Add App Lifecycle Observer
    WidgetsBinding.instance.addObserver(AppAudioLifecycleObserver(this));

    // Initialize TTS
    await _configureVoice();
  }

  Future<void> _configureVoice() async {
    try {
      await flutterTts.setLanguage("en-GB");
      final List<dynamic>? voices = await flutterTts.getVoices;
      if (voices != null) {
        dynamic selectedVoice;
        for (var v in voices) {
          if (v is Map) {
            final String name = (v['name'] ?? '').toString().toLowerCase();
            final String locale = (v['locale'] ?? '').toString().toLowerCase();
            final bool isEnglish = locale.startsWith('en');
            final bool isFeminine =
                name.contains('female') ||
                name.contains('samantha') ||
                name.contains('victoria') ||
                name.contains('hazel') ||
                name.contains('zira') ||
                name.contains('serena') ||
                name.contains('susan') ||
                name.contains('moira');
            if (isEnglish && isFeminine) {
              selectedVoice = v;
              break;
            }
          }
        }
        if (selectedVoice != null) {
          await flutterTts.setVoice({
            "name": selectedVoice["name"],
            "locale": selectedVoice["locale"],
          });
        }
      }
    } catch (e) {
      debugPrint('AudioEngine: Error configuring voice: $e');
    }
  }

  // ── Chip / Tick ────────────────────────────────────────────────────────────

  void playChipSound() {
    _playSFX('chip');
  }

  void playWheelTick() {
    // Match the web exactly: the web's `tick` sound is never defined, so
    // playWheelTick() is a no-op there. We keep it silent for parity (the
    // spin loop from startSpinSound already provides the spinning audio).
  }

  // ── Advanced Betting Sounds ────────────────────────────────────────────────

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      // Stop all sounds immediately
      for (var player in _sfxPlayers) {
        await player.stop();
      }
      await _spinPlayer.stop();
      await flutterTts.stop();
      _speechQueue.clear();
      _isProcessingQueue = false;
      unduckBackgroundMusic();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_sound_enabled', enabled);
    } catch (e) {
      debugPrint('AudioEngine: Error saving sound preference: $e');
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    if (!enabled) {
      await _bgMusicPlayer.stop();
    } else if (_activeBackground != null) {
      await _playBackgroundTrack(_activeBackground!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_music_enabled', enabled);
    } catch (e) {
      debugPrint('AudioEngine: Error saving music preference: $e');
    }
  }

  void setBlocked(bool blocked) {
    _blocked = blocked;
    if (blocked) {
      stopAll();
    } else if (_activeBackground != null && _musicEnabled) {
      _playBackgroundTrack(_activeBackground!);
    }
  }

  bool isCommentaryActive() {
    return _isProcessingQueue || _speechQueue.isNotEmpty;
  }

  void play2XClick() {
    _playSFX('btn2X');
  }

  void playClick() {
    _playSFX('click');
  }

  void playSwoosh() {
    _playSFX('swoosh');
  }

  void playSpinClick() {
    _playSFX('btnSpin');
  }

  void playLockSound() {
    _playSFX('lock');
  }

  void playThump() {
    _playSFX('thump');
  }

  void playRebetSound() {
    _playSFX('swoosh');
  }

  void playDeniedSound() {
    _playSFX('denied');
  }

  Future<void> playPlaceBetsSound() async {
    if (!_enabled || _blocked) return;
    duckBackgroundMusic();
    await _playSFX('placeBets');
    // Unduck after clip length (~1.4s)
    Future.delayed(const Duration(milliseconds: 1400), () {
      unduckBackgroundMusic();
    });
  }

  // ── Win / Loss ─────────────────────────────────────────────────────────────

  void playWinSound() {
    _playSFX('win');
  }

  void playLossSound() {
    _playSFX('loss');
  }

  // ── Spin sound (looping, with real-time volume/rate control) ───────────────

  Future<void> startSpinSound() async {
    if (!_enabled || _blocked) return;

    // Interrupt TTS commentary
    await flutterTts.stop();
    _speechQueue.clear();
    _isProcessingQueue = false;

    duckBackgroundMusic();

    try {
      await _spinPlayer.stop();
      await _spinPlayer.setReleaseMode(ReleaseMode.loop);
      await _spinPlayer.setVolume(_volumes['spin'] ?? 0.25);
      await _spinPlayer.setPlaybackRate(1.0);
      await _spinPlayer.play(AssetSource(_paths['spin']!));
    } catch (e) {
      debugPrint('AudioEngine: Error starting spin sound: $e');
    }
  }

  Future<void> setSpinEffect(double volume, double rate) async {
    if (!_enabled || _blocked) return;
    try {
      final double targetVol = volume.clamp(0.0, 1.0);
      final double targetRate = rate.clamp(0.1, 2.0);
      await _spinPlayer.setVolume(targetVol);
      await _spinPlayer.setPlaybackRate(targetRate);
    } catch (e) {
      debugPrint('AudioEngine: Error adjusting spin effect: $e');
    }
  }

  Future<void> stopSpinSound() async {
    try {
      await _spinPlayer.stop();
    } catch (e) {
      debugPrint('AudioEngine: Error stopping spin sound: $e');
    }
    unduckBackgroundMusic();
  }

  void resumeTourneyBackgroundMusic() {
    unduckBackgroundMusic();
  }

  // ── Verbal Announcements (Speech Synthesis) ───────────────────────────────

  Future<void> announce(String text) async {
    if (_blocked || !_enabled) return;
    try {
      await flutterTts.stop();
      await flutterTts.setVolume(0.95);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.05);
      await flutterTts.speak(text);
    } catch (e) {
      debugPrint('AudioEngine: Error speaking announcement: $e');
    }
  }

  void announceNewLeader(String name) {
    playTournamentCommentary([
      {'type': 'sound', 'value': 'chime'},
      {'type': 'speak', 'value': 'New leader, $name!'},
    ]);
  }

  void announceElimination(String name) {
    announce('$name has been eliminated.');
    playLossSound();
  }

  Future<void> _processSpeechQueue() async {
    if (_speechQueue.isEmpty) {
      _isProcessingQueue = false;
      unduckBackgroundMusic();
      return;
    }
    _isProcessingQueue = true;

    final item = _speechQueue.removeAt(0);
    final String type = item['type'] ?? '';
    final String value = item['value'] ?? '';

    if (type == 'sound') {
      int delayMs = 700;
      if (value == 'loss') {
        playLossSound();
      } else if (value == 'swoosh') {
        playSwoosh();
      } else if (value == 'chime') {
        play2XClick();
        delayMs = 350;
      } else if (value == 'placeBets') {
        await _playSFX('placeBets');
        delayMs = 1200;
      }
      Future.delayed(
        Duration(milliseconds: delayMs),
        () => _processSpeechQueue(),
      );
    } else if (type == 'speak') {
      if (!_enabled || _blocked) {
        _isProcessingQueue = false;
        _speechQueue.clear();
        unduckBackgroundMusic();
        return;
      }

      try {
        await flutterTts.stop();
        await flutterTts.setVolume(0.95);
        await flutterTts.setSpeechRate(0.5);
        await flutterTts.setPitch(1.05);

        _ttsCompleter = Completer<void>();

        flutterTts.setCompletionHandler(() {
          if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
            _ttsCompleter!.complete();
          }
        });

        flutterTts.setErrorHandler((_) {
          if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
            _ttsCompleter!.complete();
          }
        });

        await flutterTts.speak(value);

        // Await TTS to finish, or fail-safe timeout after 6 seconds
        await Future.any([
          _ttsCompleter!.future,
          Future.delayed(const Duration(seconds: 6)),
        ]);
      } catch (e) {
        debugPrint('AudioEngine: Speech error in queue: $e');
      }

      // 100ms breathing room before next queue item
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _processSpeechQueue(),
      );
    }
  }

  void playTournamentCommentary(List<Map<String, String>> sequence) {
    if (_blocked || !_enabled) return;
    flutterTts.stop();
    _speechQueue.clear();

    duckBackgroundMusic();

    _speechQueue.addAll(sequence);
    _processSpeechQueue();
  }

  void announceRoundEnd({
    required String eliminatedName,
    required int roundNumber,
    required bool isMe,
    required int nextRoundNumber,
    String? newLeaderName,
  }) {
    if (isMe) {
      playLossSound();
    } else {
      playSwoosh();
    }

    final List<Map<String, String>> sequence = [];
    final String elimText = isMe
        ? 'You have been eliminated.'
        : '$eliminatedName has been eliminated.';
    sequence.add({
      'type': 'speak',
      'value': 'End of Round $roundNumber. $elimText',
    });

    if (newLeaderName != null && newLeaderName.isNotEmpty) {
      sequence.add({'type': 'sound', 'value': 'chime'});
      sequence.add({'type': 'speak', 'value': 'New leader, $newLeaderName!'});
    }

    if (!isMe) {
      sequence.add({
        'type': 'speak',
        'value': 'Starting Round $nextRoundNumber.',
      });
    }

    playTournamentCommentary(sequence);
  }

  void announceMatchFound() {
    playTournamentCommentary([
      {'type': 'speak', 'value': 'Match found!'},
      {'type': 'sound', 'value': 'placeBets'},
    ]);
  }

  // ── Global background music controls ───────────────────────────────────────

  void playBackgroundMusic() {
    _playBackgroundTrack('background');
  }

  void stopBackgroundMusic() {
    if (_activeBackground == 'background') {
      _activeBackground = null;
    }
    _bgMusicPlayer.stop();
  }

  void playEntryBackgroundMusic() {
    _playBackgroundTrack('entryBackground');
  }

  void stopEntryBackgroundMusic() {
    if (_activeBackground == 'entryBackground') {
      _activeBackground = null;
    }
    _bgMusicPlayer.stop();
  }

  void playWaitingBackgroundMusic() {
    _playBackgroundTrack('waitingBackground');
  }

  void stopWaitingBackgroundMusic() {
    if (_activeBackground == 'waitingBackground') {
      _activeBackground = null;
    }
    _bgMusicPlayer.stop();
  }

  void playTourneyBackgroundMusic() {
    _playBackgroundTrack('tourneyBackground');
  }

  void stopTourneyBackgroundMusic() {
    if (_activeBackground == 'tourneyBackground') {
      _activeBackground = null;
    }
    _bgMusicPlayer.stop();
  }

  // ── Background Music Ducking ──────────────────────────────────────────────

  void duckBackgroundMusic() {
    if (_isDucked) return;
    _isDucked = true;
    if (_activeBackground != null && _musicEnabled) {
      final baseVol = _volumes[_activeBackground!] ?? 0.5;
      _bgMusicPlayer.setVolume(baseVol * 0.15);
    }
  }

  void unduckBackgroundMusic() {
    if (!_isDucked) return;
    _isDucked = false;
    if (_activeBackground != null && _musicEnabled) {
      final baseVol = _volumes[_activeBackground!] ?? 0.5;
      _bgMusicPlayer.setVolume(baseVol);
    }
  }

  Future<void> stopAll() async {
    for (var player in _sfxPlayers) {
      await player.stop();
    }
    await _bgMusicPlayer.stop();
    await _spinPlayer.stop();
    await flutterTts.stop();
    _speechQueue.clear();
    _isProcessingQueue = false;
    _isDucked = false;
  }

  Future<bool> toggleSound() async {
    final bool nextVal = !_enabled;
    await setEnabled(nextVal);
    return nextVal;
  }

  // ── App Lifecycle Handlers ────────────────────────────────────────────────

  void handleAppBackground() {
    // Stop all audio players when app is sent to background
    for (var player in _sfxPlayers) {
      player.stop();
    }
    _bgMusicPlayer.stop();
    _spinPlayer.stop();
    flutterTts.stop();
    _isDucked = false;
  }

  void handleAppForeground() {
    if (_blocked) return;
    if (_activeBackground != null && _musicEnabled) {
      _playBackgroundTrack(_activeBackground!);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Future<void> _playSFX(String id, {bool randomizeRate = false}) async {
    if (!_enabled || _blocked) return;
    final path = _paths[id];
    final volume = _volumes[id] ?? 1.0;
    if (path == null) return;

    try {
      final player = _sfxPlayers[_nextSfxIndex % _sfxPoolSize];
      _nextSfxIndex++;

      await player.stop();
      await player.setVolume(volume);
      if (randomizeRate) {
        // Randomize rate slightly between 0.8 and 1.2
        final double randomRate = 0.8 + (math.Random().nextDouble() * 0.4);
        await player.setPlaybackRate(randomRate);
      } else {
        await player.setPlaybackRate(1.0);
      }
      await player.play(AssetSource(path));
    } catch (e) {
      debugPrint('AudioEngine: Error playing SFX $id: $e');
    }
  }

  Future<void> _playBackgroundTrack(String track) async {
    if (_blocked) return;
    _activeBackground = track;

    if (!_musicEnabled) return;

    final path = _paths[track];
    var volume = _volumes[track] ?? 0.5;
    if (_isDucked) {
      volume *= 0.15;
    }
    if (path == null) return;

    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer.setVolume(volume);
      await _bgMusicPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('AudioEngine: Error playing music track $track: $e');
    }
  }
}

/// Global singleton instance of AudioEngine
final AudioEngine soundEngine = AudioEngine();
