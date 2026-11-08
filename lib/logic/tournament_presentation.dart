import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/services/tournament_service.dart';

/// Keep a server round transition from interrupting the local wheel or popup.
TournamentDetails presentTournamentDetails(
  TournamentDetails incoming, {
  required TournamentDetails? previous,
  required String localPhase,
  required String? resultId,
  required bool showingResult,
  required Set<String> acknowledged,
  required bool wasActive,
}) {
  var round = incoming.activeRound;
  var spin = incoming.latestSpin;
  var number = incoming.tournament.currentRound;
  var phase = incoming.calculatedPhase;
  var deadline = incoming.bettingDeadline;
  if (spin != null &&
      round != null &&
      spin.roundId == round.id &&
      spin.spinNumber < round.spinsCompleted) {
    spin = null;
  }
  final watching =
      resultId != null &&
      !acknowledged.contains(resultId) &&
      (localPhase == 'spinning' || (localPhase == 'result' && showingResult));
  if (watching &&
      previous?.activeRound != null &&
      previous?.latestSpin?.id == resultId) {
    round = previous!.activeRound;
    spin = previous.latestSpin;
    number = round!.roundNumber;
    phase = localPhase;
    deadline = 0;
  } else if (wasActive &&
      incoming.roundEndRound != null &&
      incoming.roundEndSpin != null &&
      !acknowledged.contains(incoming.roundEndSpin!.id) &&
      incoming.roundEndRound!.roundNumber >=
          (previous?.activeRound?.roundNumber ?? 1) &&
      incoming.tournament.completionReason != 'forfeit') {
    round = incoming.roundEndRound;
    spin = incoming.roundEndSpin;
    number = round!.roundNumber;
    phase = 'result';
    deadline = 0;
  } else if (spin != null &&
      acknowledged.contains(spin.id) &&
      ['spinning', 'result'].contains(phase)) {
    phase = 'round_complete';
    deadline = 0;
  } else if (spin == null && ['spinning', 'result'].contains(phase)) {
    phase = 'locked';
    deadline = 0;
  }
  return TournamentDetails(
    tournament: Tournament.fromJson({
      ...incoming.tournament.toJson(),
      'current_round': number,
    }),
    activeRound: round,
    latestSpin: spin,
    roundEndRound: incoming.roundEndRound,
    roundEndSpin: incoming.roundEndSpin,
    history: incoming.history,
    serverTime: incoming.serverTime,
    calculatedPhase: phase,
    bettingDeadline: deadline,
  );
}
