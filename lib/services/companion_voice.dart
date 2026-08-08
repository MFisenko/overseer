import 'dart:math';

import '../core/lexicon.dart';
import '../models/companion.dart';
import '../state/game_state.dart';

/// A compact description of the world, handed to whoever is writing the line.
///
/// The local bank reads it directly; the Gemini writer gets it serialised. Both
/// go through the same struct so the two voices cannot drift apart.
class CompanionContext {
  final int credits;
  final int level;
  final int xpIntoLevel;
  final int xpForNext;
  final int streak;
  final int activeQuests;
  final int collectable;
  final String? urgentQuest;
  final Duration? urgentIn;
  final String? neglectedGoal;
  final int neglectedDays;
  final bool inArrears;
  final int arrearsCredits;
  final int daysLeftInSeason;
  final String title;

  const CompanionContext({
    required this.credits,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNext,
    required this.streak,
    required this.activeQuests,
    required this.collectable,
    this.urgentQuest,
    this.urgentIn,
    this.neglectedGoal,
    this.neglectedDays = 0,
    this.inArrears = false,
    this.arrearsCredits = 0,
    this.daysLeftInSeason = 0,
    this.title = 'SUBJECT',
  });

  /// Built straight off live state so the overseer always speaks to what is
  /// actually happening rather than reciting something generic.
  factory CompanionContext.of(GameState game) {
    final w = game.wallet;
    final urgent = game.activeQuests.where((q) => q.isUrgent).toList();

    // "Neglected" means a wish that has sat in the manifest untouched for a
    // month or more. Those are exactly the ones worth an unprompted remark.
    final now = DateTime.now();
    final stale = game.rewards
        .where((r) => !r.isOwned && now.difference(r.createdAt).inDays >= 30)
        .toList()
      ..sort((a, b) => b.coinCost.compareTo(a.coinCost));

    return CompanionContext(
      credits: w.coins,
      level: w.level,
      xpIntoLevel: w.xpIntoLevel,
      xpForNext: w.xpForNextLevel(game.plan),
      streak: game.profile.streakAsOf(now),
      activeQuests: game.activeQuests.length,
      collectable: game.collectable.length,
      urgentQuest: urgent.isEmpty ? null : urgent.first.title,
      urgentIn: urgent.isEmpty ? null : urgent.first.timeLeft,
      neglectedGoal: stale.isEmpty ? null : stale.first.name,
      neglectedDays: stale.isEmpty ? 0 : now.difference(stale.first.createdAt).inDays,
      inArrears: game.upkeep.inArrears,
      arrearsCredits: game.upkeep.arrearsCredits.round(),
      daysLeftInSeason: game.season.daysLeft,
      title: game.equippedTitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'credits': credits,
        'tier': level,
        'xp_into_tier': xpIntoLevel,
        'xp_for_next_tier': xpForNext,
        'streak_days': streak,
        'active_directives': activeQuests,
        'awaiting_collection': collectable,
        if (urgentQuest != null) 'most_urgent_directive': urgentQuest,
        if (urgentIn != null) 'urgent_expires_in_hours': urgentIn!.inHours,
        if (neglectedGoal != null) 'longest_neglected_goal': neglectedGoal,
        if (neglectedGoal != null) 'neglected_for_days': neglectedDays,
        'in_arrears': inArrears,
        if (inArrears) 'arrears_credits': arrearsCredits,
        'days_left_in_season': daysLeftInSeason,
        'equipped_title': title,
      };
}

/// The overseer's local voice.
///
/// Cold, clipped, faintly ominous — but the menace is theatrical. Underneath
/// the delivery every line is steering the user toward something they
/// themselves said they wanted. It never genuinely demeans them, because the
/// point is motivation, not cruelty, and a person who feels mocked closes the
/// app.
///
/// This bank is also the fallback whenever the model is unreachable, so the
/// companion is never mute.
class CompanionVoice {
  CompanionVoice({Random? rng}) : _rng = rng ?? Random();
  final Random _rng;

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  String line(MessageKind kind, CompanionContext c) => switch (kind) {
        MessageKind.greeting => _greeting(c),
        MessageKind.nudge => _nudge(c),
        MessageKind.levelUp => _levelUp(c),
        MessageKind.collect => _collect(c),
        MessageKind.streak => _streak(c),
        MessageKind.expiryWarning => _expiry(c),
        MessageKind.suggestion => _suggestion(c),
        MessageKind.neglectedGoal => _neglected(c),
        MessageKind.observation => _observation(c),
      };

  String _greeting(CompanionContext c) {
    if (c.collectable > 0) {
      return _pick([
        '${c.collectable} reward${c.collectable == 1 ? '' : 's'} unclaimed. They will not collect themselves.',
        'Something is waiting to be collected. I notice you have not.',
      ]);
    }
    if (c.streak > 2) {
      return _pick([
        'Day ${c.streak}. The pattern holds. For now.',
        '${c.streak} consecutive days logged. Continue.',
      ]);
    }
    return _pick([
      'You are observed. Proceed.',
      'I have been waiting. Begin.',
      'Tier ${c.level}. ${c.xpForNext - c.xpIntoLevel} XP outstanding.',
      'Status: nominal. Ambition: unverified.',
    ]);
  }

  String _nudge(CompanionContext c) {
    if (c.activeQuests == 0) {
      return _pick([
        'Nothing is being tracked. That is not the same as nothing needing doing.',
        'An empty log. Convenient, isn\'t it.',
      ]);
    }
    return _pick([
      '${c.activeQuests} open. The bar does not move on its own.',
      '${c.xpForNext - c.xpIntoLevel} XP to tier ${c.level + 1}. Closer than you think.',
      'One directive. That is all I am asking for today.',
    ]);
  }

  String _levelUp(CompanionContext c) => _pick([
        'Tier ${c.level}. Noted. Do it again.',
        'Advancement logged. ${Lex.currency.toLowerCase()} released.',
        'Tier ${c.level}. You are becoming predictable. In the good way.',
      ]);

  String _collect(CompanionContext c) => _pick([
        'Collected. Recorded permanently.',
        'Acknowledged.',
        'Filed. The archive grows.',
      ]);

  String _streak(CompanionContext c) {
    if (c.streak <= 1) {
      return _pick([
        'The streak is broken. Streaks are rebuilt the same way they were built.',
        'Back to one. Unfortunate, not fatal.',
      ]);
    }
    return _pick([
      '${c.streak} days unbroken. I am keeping count.',
      'Day ${c.streak}. Consistency is the only thing I actually respect.',
    ]);
  }

  String _expiry(CompanionContext c) {
    final t = c.urgentIn;
    final left = t == null
        ? 'shortly'
        : t.inHours >= 1
            ? 'in ${t.inHours}h'
            : 'in ${t.inMinutes}m';
    return _pick([
      '"${c.urgentQuest}" expires $left. Then it is simply gone.',
      '$left remaining on "${c.urgentQuest}". I will not remind you again. I will, actually.',
      'Timer running: "${c.urgentQuest}". $left.',
    ]);
  }

  String _suggestion(CompanionContext c) {
    if (c.inArrears) {
      return _pick([
        'You are ${c.arrearsCredits} in ${Lex.deficit.toLowerCase()}. Payouts are being withheld until that changes.',
        '${Lex.deficit} standing at ${c.arrearsCredits}. The levy compounds daily. Log income.',
      ]);
    }
    if (c.collectable > 0) return 'Collect what you have earned. Then continue.';
    return _pick([
      'Log an hour against a craft. It pays nothing and it is worth more than most things that do.',
      'Something small. Momentum is cheaper to keep than to restart.',
    ]);
  }

  String _neglected(CompanionContext c) => _pick([
        '"${c.neglectedGoal}" has sat untouched for ${c.neglectedDays} days. You wanted it once.',
        'Reminder: ${c.neglectedDays} days ago you decided you wanted "${c.neglectedGoal}". I have not forgotten. You have.',
        '"${c.neglectedGoal}" is still on the manifest. Still unfunded.',
      ]);

  String _observation(CompanionContext c) {
    if (const [1, 2, 3, 7].contains(c.daysLeftInSeason)) {
      return 'Season closes in ${c.daysLeftInSeason} days. Unclaimed tiers do not carry over.';
    }
    return _pick([
      '${c.credits} ${Lex.currency.toLowerCase()} held. Held is not spent.',
      'Tier ${c.level}. ${c.daysLeftInSeason} days remain in the season.',
      'I have nothing to report. That is itself a report.',
    ]);
  }

  /// Picks what the overseer should bring up unprompted, in priority order.
  /// Pressure first, then encouragement, then idle observation.
  MessageKind chooseKind(CompanionContext c) {
    if (c.urgentQuest != null) return MessageKind.expiryWarning;
    if (c.inArrears) return MessageKind.suggestion;
    if (c.collectable > 0) return MessageKind.greeting;
    if (c.neglectedGoal != null && _rng.nextDouble() < 0.45) {
      return MessageKind.neglectedGoal;
    }
    if (c.activeQuests == 0) return MessageKind.nudge;
    if (c.streak >= 3 && _rng.nextDouble() < 0.3) return MessageKind.streak;
    return _rng.nextBool() ? MessageKind.observation : MessageKind.nudge;
  }

  /// Mood follows the same priority: the eye should already look how the next
  /// line is going to sound.
  CompanionMood moodFor(CompanionContext c) {
    if (c.urgentQuest != null || c.inArrears) return CompanionMood.alert;
    if (c.neglectedGoal != null && c.neglectedDays > 60) return CompanionMood.ominous;
    if (c.collectable > 0 || c.streak >= 3) return CompanionMood.pleased;
    if (c.activeQuests > 0) return CompanionMood.watching;
    return CompanionMood.idle;
  }
}
