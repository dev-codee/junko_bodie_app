import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/logic/tournament_presentation.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/services/api_service.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/widgets/private_tournament_finish_overlay.dart';
import 'private_tournament_test.dart' as fixtures;

Map<String, dynamic> round(int n, {int spins = 5}) => {
  '_id': 'round$n',
  'round_number': n,
  'spins_completed': spins,
  'betting_ends_at': '2026-11-08T00:00:00Z',
};
Map<String, dynamic> spin(int n, {int number = 5}) => {
  '_id': 'spin$n-$number',
  'round_id': 'round$n',
  'spin_number': number,
  'result': {'number': 7, 'displayNumber': '7', 'color': 'red'},
  'player_results': [],
};
Map<String, dynamic> payload(
  int n,
  String phase, {
  String kind = 'private',
  bool next = false,
}) => {
  ...fixtures.session(status: phase == 'completed' ? 'completed' : 'active'),
  'kind': kind,
  'current_round': next && n < 5 ? n + 1 : n,
  'calculated_phase': phase,
  'active_round': next ? (n < 5 ? round(n + 1, spins: 0) : null) : round(n),
  'latest_spin': next ? null : spin(n),
  if (next) 'round_end': {'round': round(n), 'spin': spin(n)},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['private', 'public']) {
    test(
      '$kind preserves the fifth spin and popup through all round transitions',
      () {
        final acknowledged = <String>{};
        for (var n = 1; n <= 5; n++) {
          final playing = TournamentDetails.fromJson(
            payload(n, 'spinning', kind: kind),
          );
          final next = TournamentDetails.fromJson(
            payload(
              n,
              n == 5 ? 'completed' : 'betting',
              kind: kind,
              next: true,
            ),
          );
          final resultId = playing.latestSpin!.id!;
          final held = presentTournamentDetails(
            next,
            previous: playing,
            localPhase: 'spinning',
            resultId: resultId,
            showingResult: false,
            acknowledged: acknowledged,
            wasActive: true,
          );
          expect(held.calculatedPhase, 'spinning');
          expect(held.tournament.currentRound, n);
          expect(held.latestSpin!.id, resultId);
          final popup = presentTournamentDetails(
            next,
            previous: held,
            localPhase: 'result',
            resultId: resultId,
            showingResult: true,
            acknowledged: acknowledged,
            wasActive: true,
          );
          expect(popup.calculatedPhase, 'result');
          expect(popup.tournament.currentRound, n);
          acknowledged.add(resultId);
          final advanced = presentTournamentDetails(
            next,
            previous: popup,
            localPhase: 'round_complete',
            resultId: resultId,
            showingResult: false,
            acknowledged: acknowledged,
            wasActive: true,
          );
          expect(advanced.calculatedPhase, n == 5 ? 'completed' : 'betting');
          expect(advanced.tournament.currentRound, n == 5 ? 5 : n + 1);
        }
      },
    );
  }
  test(
    'late polls recover results; fresh completed matches do not replay them',
    () {
      final incoming = TournamentDetails.fromJson(
        payload(3, 'betting', next: true),
      );
      final recovered = presentTournamentDetails(
        incoming,
        previous: null,
        localPhase: 'locked',
        resultId: null,
        showingResult: false,
        acknowledged: {},
        wasActive: true,
      );
      expect(recovered.calculatedPhase, 'result');
      expect(recovered.latestSpin!.spinNumber, 5);
      expect(recovered.tournament.currentRound, 3);
      final completed = TournamentDetails.fromJson(
        payload(5, 'completed', next: true),
      );
      expect(
        presentTournamentDetails(
          completed,
          previous: null,
          localPhase: 'waiting',
          resultId: null,
          showingResult: false,
          acknowledged: {},
          wasActive: false,
        ).calculatedPhase,
        'completed',
      );
    },
  );
  test(
    'a reserved fifth spin waits for its result; forfeit does not replay the previous spin',
    () {
      final missing = TournamentDetails.fromJson({
        ...payload(1, 'spinning'),
        'latest_spin': spin(1, number: 4),
      });
      expect(
        presentTournamentDetails(
          missing,
          previous: null,
          localPhase: 'betting',
          resultId: null,
          showingResult: false,
          acknowledged: {},
          wasActive: true,
        ).calculatedPhase,
        'locked',
      );
      final forfeit = TournamentDetails.fromJson({
        ...payload(1, 'completed', next: true),
        'completion_reason': 'forfeit',
      });
      expect(
        presentTournamentDetails(
          forfeit,
          previous: null,
          localPhase: 'betting',
          resultId: null,
          showingResult: false,
          acknowledged: {},
          wasActive: true,
        ).calculatedPhase,
        'completed',
      );
    },
  );
  test(
    'provider finishes the local wheel before advancing to the next round',
    () async {
      final api = fixtures.FakeApi()..tournament = payload(1, 'spinning');
      final provider = TournamentProvider(
        tournamentService: TournamentService(api: api),
        userService: fixtures.FakeUserService(),
        initialize: false,
      );
      await provider.openTournament(fixtures.id);
      expect(provider.phase, 'spinning');
      api.tournament = payload(1, 'betting', next: true);
      await provider.loadTournament();
      expect(provider.phase, 'spinning');
      expect(provider.currentRound, 1);
      provider.completeSpin();
      expect(provider.showResult, true);
      await provider.loadTournament();
      expect(provider.phase, 'result');
      expect(provider.currentRound, 1);
      provider.dismissResult();
      await Future<void>.delayed(Duration.zero);
      expect(provider.showResult, false);
      expect(provider.phase, 'betting');
      expect(provider.currentRound, 2);
      provider.phase = 'waiting';
      provider.dispose();
    },
  );
  test(
    'failed leave preserves the session; successful leave clears it and allows another',
    () async {
      final api = fixtures.FakeApi()
        ..tournament = fixtures.session(status: 'active');
      final provider = TournamentProvider(
        tournamentService: TournamentService(api: api),
        userService: fixtures.FakeUserService(),
        initialize: false,
      );
      await provider.openTournament(fixtures.id);
      api.failure = ApiException(statusCode: 503, message: 'Try again');
      await expectLater(
        provider.leaveTournament(),
        throwsA(isA<ApiException>()),
      );
      expect(provider.tournament!.id, fixtures.id);
      api.failure = null;
      await provider.leaveTournament();
      expect(provider.tournament, null);
      expect(provider.showResult, false);
      expect(api.calls.last.$1, '/api/tournament/${fixtures.id}/leave');
      api.tournament = {...fixtures.session(), '_id': 'new-match'};
      await provider.openTournament('new-match');
      expect(provider.tournament!.id, 'new-match');
      provider.dispose();
    },
  );
  test('departure and completion reason survive model round trips', () {
    final t = Tournament.fromJson({
      ...fixtures.session(status: 'completed'),
      'completion_reason': 'forfeit',
      'players': [
        {
          'player_id': 'guest1',
          'status': 'eliminated',
          'forfeited_at': '2026-11-08T00:00:00Z',
        },
      ],
    });
    final copy = Tournament.fromJson(t.toJson());
    expect(copy.completionReason, 'forfeit');
    expect(copy.players.single.forfeitedAt, isNotNull);
  });
  testWidgets(
    'private trophy fits a landscape phone and opens final standings',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateTournamentFinishOverlay(
              tournament: Tournament.fromJson({
                ...fixtures.session(status: 'completed'),
                'completion_reason': 'forfeit',
              }),
              currentPlayerId: 'host',
              onContinue: () => continued = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You take the crown!'), findsOneWidget);
      expect(
        find.text('Won by forfeit. The last remaining player wins.'),
        findsOneWidget,
      );
      final button = find.text('View final standings');
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(continued, true);
      expect(tester.takeException(), null);
    },
  );
}
