import 'dart:async';
import 'package:flutter/material.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/models/player.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/config/private_tournament_routes.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/services/api_service.dart';
import 'package:junko_bodie/services/tournament_service.dart';
import 'package:junko_bodie/screens/private_tournament_screen.dart';
import 'package:junko_bodie/screens/private_tournament_lobby_screen.dart';
import 'package:junko_bodie/widgets/private_tournament_results.dart';

const id = '0123456789abcdef01234567';
Map<String, dynamic> session({String status = 'waiting', int players = 2}) => {
  '_id': id,
  'kind': 'private',
  'status': status,
  'host_id': 'host',
  'join_code': '012345',
  'created_at': '2026-11-07T00:00:00Z',
  'total_rounds': 5,
  'rules': {'min_players': 2, 'max_players': 6},
  'winner_id': 'host',
  'players': List.generate(
    players,
    (i) => {
      'player_id': i == 0 ? 'host' : 'guest$i',
      'username': 'Friend $i',
      'current_chips': 2000,
      'status': 'active',
    },
  ),
};

class FakeApi implements ApiService {
  Map<String, dynamic> access = {
    'hasAccess': false,
    'freeAvailable': true,
    'freeEmailEligible': true,
  };
  Map<String, dynamic> tournament = session();
  final List<(String, dynamic)> calls = [];
  ApiException? failure;
  @override
  Future<dynamic> get(String path) async {
    if (failure != null) throw failure!;
    return path == '/api/tournament/private' ? access : tournament;
  }

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    calls.add((path, body));
    if (failure != null) throw failure!;
    if (path.endsWith('/start')) tournament = session(status: 'active');
    return tournament;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserService implements UserService {
  @override
  Future<Player> getProfile() async =>
      Player.fromJson({'_id': 'guest1', 'username': 'Friend 0'});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedApi extends FakeApi {
  final pending = Completer<dynamic>();
  @override
  Future<dynamic> get(String path) =>
      path.endsWith('/old') ? pending.future : super.get(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'provider matches profile ID and ignores previous-session responses',
    () async {
      final api = DelayedApi();
      final provider = TournamentProvider(
        tournamentService: TournamentService(api: api),
        userService: FakeUserService(),
        initialize: false,
      );
      final old = provider.openTournament('old');
      await Future<void>.delayed(Duration.zero);
      await provider.openTournament(id);
      expect(provider.me?.playerId, 'guest1');
      expect(provider.me?.username, 'Friend 1');
      api.pending.complete({...session(), '_id': 'old'});
      await old;
      expect(provider.tournament?.id, id);
      provider.dispose();
    },
  );
  test('private model preserves code, rules and legacy defaults', () {
    final t = Tournament.fromJson(session());
    expect(t.isPrivate, true);
    expect(t.joinCode, '012345');
    expect(t.totalRounds, 5);
    expect(
      Tournament.fromJson({...session(), 'total_rounds': 1}).totalRounds,
      1,
    );
    expect(t.minPlayers, 2);
    expect(t.maxPlayers, 6);
    expect(Tournament.fromJson(t.toJson()).joinCode, '012345');
    expect(Tournament.fromJson({}).isPrivate, false);
    expect(Tournament.fromJson({}).totalRounds, 5);
    expect(
      Tournament.fromJson({...session(), 'status': 'cancelled'}).lobbyClosed,
      true,
    );
  });
  test(
    'free routes are narrow and login destinations reject external paths',
    () {
      expect(isFreeTournamentRoute('/tournament/private'), true);
      expect(isFreeTournamentRoute('/tournament/private/$id'), true);
      expect(isFreeTournamentRoute('/tournament/$id'), true);
      for (final path in [
        '/game',
        '/tournament',
        '/strategies',
        '/tournament/invalid',
      ]) {
        expect(isFreeTournamentRoute(path), false);
      }
      expect(
        privateLoginDestination(Uri.parse('/login?next=/tournament/private')),
        '/tournament/private',
      );
      expect(
        privateLoginDestination(Uri.parse('/login?next=https://example.com')),
        null,
      );
    },
  );
  test(
    'service uses private API contract and preserves leading zeros',
    () async {
      final api = FakeApi();
      final service = TournamentService(api: api);
      expect((await service.privateAccess()).canEnter, true);
      await service.createPrivate('european');
      await service.joinPrivate('012345');
      await service.startPrivate(id);
      await service.leavePrivate(id);
      expect(api.calls.map((c) => c.$1), [
        '/api/tournament/private',
        '/api/tournament/private/join',
        '/api/tournament/$id/start',
        '/api/tournament/$id/leave',
      ]);
      expect(api.calls[1].$2, {'code': '012345'});
      await expectLater(service.joinPrivate('12345'), throwsFormatException);
      api.failure = ApiException(statusCode: 429, message: 'Please wait');
      await expectLater(
        service.joinPrivate('123456'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
      );
    },
  );
  testWidgets('free user can join and denied user sees membership recovery', (
    tester,
  ) async {
    final api = FakeApi();
    final service = TournamentService(api: api);
    final router = GoRouter(
      initialLocation: '/tournament/private',
      routes: [
        GoRoute(
          path: '/tournament/private',
          builder: (_, _) => PrivateTournamentScreen(service: service),
        ),
        GoRoute(
          path: '/tournament/private/:id',
          builder: (_, _) => const Scaffold(body: Text('Joined lobby')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    final join = find.widgetWithText(FilledButton, 'Join a Tournament');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.ensureVisible(join);
    await tester.pumpAndSettle();
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.text('Joined lobby'), findsOneWidget);
    expect(api.calls.last.$2, {'code': '012345'});
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    api.access = {
      'hasAccess': false,
      'freeAvailable': false,
      'freeEmailEligible': false,
    };
    await tester.pumpWidget(
      MaterialApp(home: PrivateTournamentScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('View membership'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create a Tournament'),
    );
    expect(create.onPressed, isNull);
  });
  testWidgets('host can start with two humans; guest cannot', (tester) async {
    final api = FakeApi();
    final service = TournamentService(api: api);
    api.tournament = session(players: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateTournamentLobbyScreen(
          tournamentId: id,
          service: service,
          loadPlayerId: () async => 'host',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start tournament'),
          )
          .onPressed,
      isNull,
    );
    api.tournament = session();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start tournament'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('012345'), findsOneWidget);
    expect(find.text('Cancel tournament'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateTournamentLobbyScreen(
          tournamentId: id,
          service: service,
          loadPlayerId: () async => 'guest1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start tournament'), findsNothing);
    expect(find.text('Leave lobby'), findsOneWidget);
    api.tournament = {...session(), 'lobby_closed': true};
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('This lobby is closed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('private results do not advertise public rewards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateTournamentResults(
          tournament: Tournament.fromJson(session(status: 'completed')),
        ),
      ),
    );
    expect(find.text('Friend 0 wins!'), findsOneWidget);
    expect(
      find.text(
        'Private matches do not award public championship points or badges.',
      ),
      findsOneWidget,
    );
  });
}
