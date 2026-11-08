class PrivateTournamentAccess {
  final bool hasAccess;
  final bool freeAvailable;
  final bool freeEmailEligible;
  final String? currentTournamentId;
  const PrivateTournamentAccess({
    required this.hasAccess,
    required this.freeAvailable,
    required this.freeEmailEligible,
    this.currentTournamentId,
  });
  bool get canEnter => hasAccess || freeAvailable;
  factory PrivateTournamentAccess.fromJson(Map<String, dynamic> json) =>
      PrivateTournamentAccess(
        hasAccess: json['hasAccess'] == true,
        freeAvailable: json['freeAvailable'] == true,
        freeEmailEligible: json['freeEmailEligible'] == true,
        currentTournamentId: json['currentTournamentId']?.toString(),
      );
}
