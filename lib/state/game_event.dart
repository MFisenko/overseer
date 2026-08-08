import '../core/economy.dart';
import '../models/unlockable.dart';
import '../models/cosmetic.dart';

/// Things worth putting on screen the instant they happen.
///
/// The whole premise of the app is that doing something real produces visible
/// feedback *right now*, so every state change that a person should feel emits
/// one of these rather than silently updating a number.
sealed class GameEvent {
  const GameEvent();
}

/// The instant hit. Fires on every completion without exception.
class XpGained extends GameEvent {
  final int xp;
  final String source;
  const XpGained(this.xp, this.source);
}

/// The burst. Only ever fires on crossing a tier — never from a task directly.
class TierCrossed extends GameEvent {
  final LevelUpResult result;

  /// Credits diverted to arrears before the user saw them, if any.
  final int garnished;
  const TierCrossed(this.result, {this.garnished = 0});
}

/// The deliberate tap that turns an earned thing into a held thing.
class QuestCollected extends GameEvent {
  final String title;
  final int credits;
  const QuestCollected(this.title, this.credits);
}

class CreditsSpent extends GameEvent {
  final int credits;
  final String on;
  const CreditsSpent(this.credits, this.on);
}

class CosmeticUnlocked extends GameEvent {
  final Cosmetic cosmetic;
  const CosmeticUnlocked(this.cosmetic);
}

class MasteryLevelUp extends GameEvent {
  final String trackName;
  final int level;
  const MasteryLevelUp(this.trackName, this.level);
}

class StreakChanged extends GameEvent {
  final int streak;
  final bool broken;
  const StreakChanged(this.streak, this.broken);
}

/// The bill for staying alive, settled for one or more elapsed days.
class UpkeepAccrued extends GameEvent {
  final double burned;
  final double levy;
  final int days;
  final bool enteredArrears;
  const UpkeepAccrued(this.burned, this.levy, this.days, this.enteredArrears);
}

class IncomeLogged extends GameEvent {
  final double euro;
  final double toFund;
  const IncomeLogged(this.euro, this.toFund);
}

class SeasonRolled extends GameEvent {
  final String name;
  const SeasonRolled(this.name);
}

/// Something went wrong in a way the user should hear about, phrased in the
/// overseer's voice rather than as a stack trace.
class GameNotice extends GameEvent {
  final String message;
  const GameNotice(this.message);
}

/// One or more long-range goals have come within reach of a season, because
/// the user's cashflow moved.
///
/// This is the payoff of banding goals by horizon rather than hiding the
/// expensive ones: a raise should visibly pull distant things closer instead of
/// leaving the user to work it out for themselves.
class GoalsPromoted extends GameEvent {
  final List<String> names;
  const GoalsPromoted(this.names);
}

/// Shards arrived. The in-app currency, off the euro peg entirely.
class ShardsGained extends GameEvent {
  final int shards;
  const ShardsGained(this.shards);
}

/// A streak crossed a milestone and paid a shard lump. The single most
/// productive thing a user can do, and worth saying so loudly.
class StreakMilestone extends GameEvent {
  final int days;
  final int shards;
  const StreakMilestone(this.days, this.shards);
}

/// An appearance option was acquired, bought or pulled.
class UnlockAcquired extends GameEvent {
  final Unlockable unlockable;
  final bool fromBox;
  const UnlockAcquired(this.unlockable, {required this.fromBox});
}

/// What a lootbox produced. A duplicate is never nothing — it pays dust.
class BoxResult {
  final Unlockable unlockable;
  final bool duplicate;
  final int dust;
  const BoxResult(this.unlockable, {required this.duplicate, required this.dust});
}

class BoxOpened extends GameEvent {
  final BoxResult result;
  const BoxOpened(this.result);
}
