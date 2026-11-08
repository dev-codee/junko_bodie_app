bool isPrivateTournamentDestination(String path) =>
    path == '/tournament/private' ||
    RegExp(r'^/tournament/private/[a-fA-F0-9]{24}$').hasMatch(path);

bool isFreeTournamentRoute(String path) =>
    isPrivateTournamentDestination(path) ||
    RegExp(r'^/tournament/[a-fA-F0-9]{24}$').hasMatch(path);

String? privateLoginDestination(Uri uri) {
  final next = uri.queryParameters['next'];
  return next != null && isPrivateTournamentDestination(next) ? next : null;
}
