class PlayerStats {
  final int tournamentsPlayed;
  final int tournamentsWon;
  final int bestFinish;

  PlayerStats({
    required this.tournamentsPlayed,
    required this.tournamentsWon,
    required this.bestFinish,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        tournamentsPlayed: json['tournaments_played'] ?? 0,
        tournamentsWon: json['tournaments_won'] ?? 0,
        bestFinish: json['best_finish'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'tournaments_played': tournamentsPlayed,
        'tournaments_won': tournamentsWon,
        'best_finish': bestFinish,
      };
}

class PlayerBadges {
  final bool champion;
  final bool eliteStatus;
  final bool allTimeChampion;
  final bool founder;

  PlayerBadges({
    required this.champion,
    required this.eliteStatus,
    required this.allTimeChampion,
    required this.founder,
  });

  factory PlayerBadges.fromJson(Map<String, dynamic> json) => PlayerBadges(
        champion: json['champion'] ?? false,
        eliteStatus: json['elite_status'] ?? false,
        allTimeChampion: json['all_time_champion'] ?? false,
        founder: json['founder'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'champion': champion,
        'elite_status': eliteStatus,
        'all_time_champion': allTimeChampion,
        'founder': founder,
      };
}

class SeasonInfo {
  final int year;
  final int points;
  final int rank;

  SeasonInfo({
    required this.year,
    required this.points,
    required this.rank,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> json) => SeasonInfo(
        year: json['year'] ?? DateTime.now().year,
        points: json['points'] ?? 0,
        rank: json['rank'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'year': year,
        'points': points,
        'rank': rank,
      };
}

class PlayerSubscription {
  final String? stripeCustomerId;
  final String? status;
  final String? plan;
  final String? stripeSubscriptionId;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEnd;
  final bool? cancelAtPeriodEnd;
  final DateTime? endedAt;

  PlayerSubscription({
    this.stripeCustomerId,
    this.status,
    this.plan,
    this.stripeSubscriptionId,
    this.currentPeriodEnd,
    this.trialEnd,
    this.cancelAtPeriodEnd,
    this.endedAt,
  });

  factory PlayerSubscription.fromJson(Map<String, dynamic> json) =>
      PlayerSubscription(
        stripeCustomerId: json['stripe_customer_id'],
        status: json['status'],
        plan: json['plan'],
        stripeSubscriptionId: json['stripe_subscription_id'],
        currentPeriodEnd: json['current_period_end'] != null
            ? DateTime.parse(json['current_period_end'])
            : null,
        trialEnd: json['trial_end'] != null
            ? DateTime.parse(json['trial_end'])
            : null,
        cancelAtPeriodEnd: json['cancel_at_period_end'],
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'stripe_customer_id': stripeCustomerId,
        'status': status,
        'plan': plan,
        'stripe_subscription_id': stripeSubscriptionId,
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'trial_end': trialEnd?.toIso8601String(),
        'cancel_at_period_end': cancelAtPeriodEnd,
        'ended_at': endedAt?.toIso8601String(),
      };
}

class Player {
  final String? id;
  final String supabaseId;
  final String username;
  final String email;
  final String avatarUrl;
  final double balance;
  final double startingBalance;
  final bool isSoundEnabled;
  final bool isTimerEnabled;
  final bool isPopupEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PlayerStats stats;
  final PlayerBadges badges;
  final SeasonInfo season;
  final bool annualChampionshipQualified;
  final String provider;
  final PlayerSubscription? subscription;
  final bool? hasSeenWelcomeVideo;

  Player({
    this.id,
    required this.supabaseId,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.balance,
    required this.startingBalance,
    required this.isSoundEnabled,
    required this.isTimerEnabled,
    required this.isPopupEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.stats,
    required this.badges,
    required this.season,
    required this.annualChampionshipQualified,
    required this.provider,
    this.subscription,
    this.hasSeenWelcomeVideo,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['_id']?.toString(),
        supabaseId: json['supabase_id'] ?? '',
        username: json['username'] ?? json['name'] ?? '',
        email: json['email'] ?? '',
        avatarUrl: json['avatar_url'] ?? '',
        balance: (json['balance'] ?? 0).toDouble(),
        startingBalance: (json['starting_balance'] ?? 0).toDouble(),
        isSoundEnabled: json['is_sound_enabled'] ?? true,
        isTimerEnabled: json['is_timer_enabled'] ?? true,
        isPopupEnabled: json['is_popup_enabled'] ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
        stats: PlayerStats.fromJson(json['stats'] ?? {}),
        badges: PlayerBadges.fromJson(json['badges'] ?? {}),
        season: SeasonInfo.fromJson(json['season'] ?? {}),
        annualChampionshipQualified:
            json['annual_championship_qualified'] ?? false,
        provider: json['provider'] ?? 'credentials',
        subscription: json['subscription'] != null
            ? PlayerSubscription.fromJson(json['subscription'])
            : null,
        hasSeenWelcomeVideo: json['has_seen_welcome_video'],
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'supabase_id': supabaseId,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'balance': balance,
        'starting_balance': startingBalance,
        'is_sound_enabled': isSoundEnabled,
        'is_timer_enabled': isTimerEnabled,
        'is_popup_enabled': isPopupEnabled,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'stats': stats.toJson(),
        'badges': badges.toJson(),
        'season': season.toJson(),
        'annual_championship_qualified': annualChampionshipQualified,
        'provider': provider,
        'subscription': subscription?.toJson(),
        'has_seen_welcome_video': hasSeenWelcomeVideo,
      };
}
