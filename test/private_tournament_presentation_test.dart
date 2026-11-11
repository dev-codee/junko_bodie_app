import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/logic/private_tournament_countdown.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/screens/private_tournament_lobby_screen.dart';
import 'package:junko_bodie/screens/private_tournament_screen.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/widgets/private_tournament_start_countdown.dart';

import 'private_tournament_test.dart' as fixtures;

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Tournament roster() => Tournament.fromJson({
  ...fixtures.session(status: 'active', players: 6),
  'players': List.generate(
    6,
    (i) => {
      'player_id': 'player$i',
      'username': 'Friend with a long name $i',
      'current_chips': 2000,
      'status': 'active',
    },
  ),
});

void main() {
  test(
    'countdown preserves every web beat boundary and skips expired starts',
    () {
      final cases = {
        -100: PrivateCountdownStep.ready,
        0: PrivateCountdownStep.ready,
        1499: PrivateCountdownStep.ready,
        1500: PrivateCountdownStep.three,
        2999: PrivateCountdownStep.three,
        3000: PrivateCountdownStep.two,
        4500: PrivateCountdownStep.one,
        6000: PrivateCountdownStep.go,
        7499: PrivateCountdownStep.go,
        7500: PrivateCountdownStep.done,
        60000: PrivateCountdownStep.done,
      };
      for (final entry in cases.entries) {
        expect(
          privateCountdownStep(Duration(milliseconds: entry.key)),
          entry.value,
        );
      }
    },
  );

  test('server clock gates first bets and resumes a match without restarting the countdown', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final api = fixtures.FakeApi()
      ..tournament = {
        ...fixtures.session(status: 'active'),
        'started_at': DateTime.fromMillisecondsSinceEpoch(
          now - 3000,
          isUtc: true,
        ).toIso8601String(),
        'server_time': now,
        'calculated_phase': 'betting',
        'betting_deadline': now + 34500,
        'active_round': {
          '_id': 'round1',
          'round_number': 1,
          'spins_completed': 0,
        },
      };
    final provider = TournamentProvider(
      tournamentService: TournamentService(api: api),
      userService: fixtures.FakeUserService(),
      initialize: false,
    );
    addTearDown(provider.dispose);
    await provider.openTournament(fixtures.id);
    expect(provider.isPrivateStarting, true);
    provider.placeBet('red');
    await provider.submitBets(provider.bets);
    expect(provider.bets, isEmpty);
    expect(api.calls, isEmpty);
    api.tournament['server_time'] = now + 8000;
    await provider.loadTournament();
    expect(provider.isPrivateStarting, false);
    provider.placeBet('red');
    expect(provider.bets['red']?.amount, provider.selectedChip);
    api.tournament.remove('started_at');
    await provider.loadTournament();
    expect(provider.isPrivateStarting, false);
  });

  testWidgets(
    'countdown reaches GO once with the relaxed cadence and beat audio',
    (tester) async {
      final beats = <int>[];
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateTournamentStartCountdown(
              tournament: roster(),
              elapsed: Duration.zero,
              onBeat: beats.add,
              onComplete: () => completed++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tournament starts in...'), findsOneWidget);
      expect(find.text('Ready?'), findsOneWidget);
      for (final label in ['3', '2', '1', 'GO!']) {
        await tester.pump(privateCountdownBeat);
        expect(find.text(label), findsOneWidget);
        expect(completed, 0);
      }
      await tester.pump(privateCountdownBeat);
      await tester.pump(const Duration(seconds: 5));
      expect(beats, [3, 2, 1, 0]);
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'joining partway through starts on the current beat and disposes cleanly',
    (tester) async {
      final beats = <int>[];
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateTournamentStartCountdown(
              tournament: roster(),
              elapsed: const Duration(milliseconds: 4700),
              onBeat: beats.add,
              onComplete: () => completed++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(beats, [1]);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('GO!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(completed, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(844, 390),
    const Size(568, 320),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'six-player countdown fits or scrolls at $size with larger text',
      (tester) async {
        viewport(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: PrivateTournamentStartCountdown(
                  tournament: roster(),
                  elapsed: const Duration(milliseconds: 3000),
                  onBeat: (_) {},
                  onComplete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Friend with a long name 5'));
        await tester.pump();
        expect(
          find.text('Friend with a long name 5').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'guest lobby keeps its waiting panel compact and footer reachable at $size',
      (tester) async {
        viewport(tester, size);
        final api = fixtures.FakeApi()
          ..tournament = fixtures.session(players: 6);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: PrivateTournamentLobbyScreen(
                tournamentId: fixtures.id,
                service: TournamentService(api: api),
                loadPlayerId: () async => 'guest1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = find.text('Waiting for the host to start…');
        expect(heading, findsOneWidget);
        expect(
          tester.widget<Text>(heading).style!.fontSize,
          lessThanOrEqualTo(28),
        );
        expect(find.text('Start tournament'), findsNothing);
        final leave = find.widgetWithText(OutlinedButton, 'Leave lobby');
        await tester.ensureVisible(leave);
        await tester.pumpAndSettle();
        expect(leave.hitTestable(), findsOneWidget);
        final footer = find.textContaining(
          'The lobby expires after two hours.',
        );
        await tester.ensureVisible(footer);
        await tester.pumpAndSettle();
        expect(footer.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'wide entry uses side-by-side options while narrow entry stacks without overflow',
    (tester) async {
      viewport(tester, const Size(1200, 900));
      final api = fixtures.FakeApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateTournamentScreen(service: TournamentService(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      final create = find.text('Create a Tournament').first;
      final join = find.text('Join a Tournament').first;
      expect(
        tester.getTopLeft(join).dx,
        greaterThan(tester.getTopLeft(create).dx),
      );
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(join).dy,
        greaterThan(tester.getTopLeft(create).dy),
      );
      await tester.enterText(find.byType(TextField), '012345');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Join a Tournament');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
