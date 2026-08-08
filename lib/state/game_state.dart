import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show ChangeNotifier, ThemeMode;
import 'package:uuid/uuid.dart';

import '../core/economy.dart';
import '../core/horizon.dart';
import '../data/repository.dart';
import '../data/snapshot.dart';
import '../models/calibration.dart';
import '../models/appearance.dart';
import '../models/companion.dart';
import '../models/cosmetic.dart';
import '../models/mastery.dart';
import '../models/profile.dart';
import '../models/quest.dart';
import '../models/reward.dart';
import '../models/season.dart';
import '../models/taste.dart';
import '../models/upkeep.dart';
import '../models/wallet.dart';
import 'game_event.dart';

/// Owns the world and every rule that changes it.
///
/// The UI reads from here and calls methods on here; it never computes game
/// maths of its own. Persistence goes out through [OverseerRepository], so
/// swapping local storage for Supabase changes nothing above this class.
class GameState extends ChangeNotifier {
  GameState(this._repo);

  OverseerRepository _repo;
  final _uuid = const Uuid();

  GameSnapshot _snap = GameSnapshot.fresh();
  bool _loading = true;

  /// Events the UI animates. Broadcast so the home screen, the companion and
  /// the dashboard can all react to the same tick.
  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  // ------------------------------------------------------------- accessors
  bool get isLoading => _loading;
  GameSnapshot get snapshot => _snap;
  Profile get profile => _snap.profile;
  Wallet get wallet => _snap.wallet;
  Fund get fund => _snap.fund;
  Upkeep get upkeep => _snap.upkeep;
  Calibration get calibration => _snap.calibration;
  List<StatementEntry> get statements => _snap.statements;

  /// The live ladder: XP costs and payouts, derived from the user's real
  /// income and chosen difficulty. Rebuilt whenever either changes.
  LadderPlan get plan => LadderPlan.from(
        calibration: _snap.calibration,
        fundPercent: _snap.fund.percent,
      );

  /// Credits the season will pay in total if the pass is cleared. Equal, by
  /// construction, to what the reserve should accumulate over the same period.
  int get seasonCreditBudget => _snap.season.totalPayout;

  /// How far issuance has run ahead of the money actually set aside.
  ///
  /// Zero or negative is healthy. A positive number means the user is holding
  /// credits their reserve cannot yet back — not a bug, but something the app
  /// states plainly rather than letting them discover it at the claim gate.
  int get unbackedCredits {
    final backed = Economy.euroToCoins(_snap.fund.balanceEuro);
    final held = _snap.wallet.coins;
    return held > backed ? held - backed : 0;
  }
  CompanionState get companion => _snap.companion;
  TasteProfile get taste => _snap.taste;
  Season get season => _snap.season;
  List<Quest> get quests => _snap.quests;
  List<Reward> get rewards => _snap.rewards;
  List<Bucket> get buckets => _snap.buckets;
  List<Obligation> get obligations => _snap.obligations;
  List<MasteryTrack> get tracks => _snap.tracks;
  List<HourLog> get hourLogs => _snap.hourLogs;
  List<Cosmetic> get cosmetics => _snap.cosmetics;
  List<IncomeEntry> get income => _snap.income;

  /// Quests that are live right now: not expired, not already collected.
  List<Quest> get activeQuests => _snap.quests
      .where((q) => !q.isExpired && q.status != QuestStatus.collected)
      .toList()
    ..sort((a, b) {
      // Collectable first — a finished directive waiting on a tap is the single
      // most valuable thing to put in front of someone.
      if (a.isCollectable != b.isCollectable) return a.isCollectable ? -1 : 1;
      final ae = a.expiresAt, be = b.expiresAt;
      if (ae == null && be == null) return 0;
      if (ae == null) return 1;
      if (be == null) return -1;
      return ae.compareTo(be);
    });

  List<Quest> questsOf(Cadence c) =>
      activeQuests.where((q) => q.cadence == c).toList();

  List<Quest> get collectable =>
      _snap.quests.where((q) => q.isCollectable && !q.isExpired).toList();

  /// Total daily cost of simply existing, in credits.
  double get dailyBurnCredits => _snap.obligations
      .where((o) => o.active)
      .fold(0.0, (sum, o) => sum + o.dailyCredits);

  double get dailyBurnEuro => _snap.obligations
      .where((o) => o.active)
      .fold(0.0, (sum, o) => sum + o.dailyEuro);

  /// The next rung that actually hands something over.
  ///
  /// Most of the ladder is advancement only, so pointing "next up" at the
  /// literal next tier would usually promise nothing. This skips forward to
  /// the next rung with a payout or a named prize, which is the thing worth
  /// putting in front of someone.
  PassTier? get nextTier {
    final season = _snap.season;
    for (var t = _snap.wallet.level + 1; t <= season.tiers.length; t++) {
      final tier = season.tierAt(t);
      if (tier == null) continue;
      if (tier.coinPayout > 0 || tier.hasNamedPrize) return tier;
    }
    return season.tierAt(_snap.wallet.level);
  }

  /// How many rungs away [nextTier] is, for the "in N tiers" readout.
  int get tiersToNextPrize {
    final next = nextTier;
    if (next == null) return 0;
    return (next.tier - _snap.wallet.level).clamp(0, Economy.seasonTiers);
  }

  /// Cheapest wish the user can afford right now, for the "next reward" slot
  /// when the ladder has nothing named attached.
  Reward? get nextAffordableReward {
    final candidates = _snap.rewards
        .where((r) => r.status == RewardStatus.available || r.status == RewardStatus.locked)
        .toList()
      ..sort((a, b) => a.coinCost.compareTo(b.coinCost));
    for (final r in candidates) {
      if (r.coinCost > _snap.wallet.coins) return r;
    }
    return candidates.isEmpty ? null : candidates.last;
  }

  List<Cosmetic> get unlockedCosmetics =>
      _snap.cosmetics.where((c) => c.unlocked).toList();

  /// Euros that reach the reserve in a year at the current calibration. The
  /// yardstick every horizon is measured against.
  double get annualReserveEuro =>
      _snap.calibration.monthlyIncome * 12 * (_snap.fund.percent / 100);

  /// Where a goal sits in time, given what is already put by for it.
  Horizon horizonOf(Reward r) => bandFor(
        priceEuro: r.priceEuro,
        annualReserveEuro: annualReserveEuro,
        alreadySavedEuro: r.savedEuro,
        covered: canClaim(r),
      );

  /// Years until this goal funds itself, or null if never at the current rate.
  ///
  /// An earmarked goal accrues at its own share; an un-earmarked one is
  /// measured against the whole reserve, which is the honest best case.
  double? yearsAwayFor(Reward r) => yearsRemaining(
        priceEuro: r.priceEuro,
        alreadySavedEuro: r.savedEuro,
        annualRateEuro: r.isEarmarked
            ? annualReserveEuro * (r.earmarkPercent / 100)
            : annualReserveEuro,
      );

  /// What the user would have to earn monthly to pull this inside [years].
  double incomeToReach(Reward r, {double years = 5}) => incomeNeededFor(
        priceEuro: r.priceEuro,
        alreadySavedEuro: r.savedEuro,
        fundPercent: _snap.fund.percent,
        // An un-earmarked goal is costed as though it had the whole reserve.
        earmarkPercent: r.isEarmarked ? r.earmarkPercent : 100,
        targetYears: years,
      );

  /// Goals too far out for a season. The vault.
  List<Reward> get longRangeGoals {
    final list = _snap.rewards
        .where((r) => !r.isOwned && horizonOf(r).isLongRange)
        .toList()
      ..sort((a, b) {
        // Earmarked first — those are the ones actually being worked on.
        if (a.isEarmarked != b.isEarmarked) return a.isEarmarked ? -1 : 1;
        final ay = yearsAwayFor(a) ?? double.infinity;
        final by = yearsAwayFor(b) ?? double.infinity;
        return ay.compareTo(by);
      });
    return list;
  }

  /// Total share of the reserve already spoken for by long goals.
  double get earmarkedPercent => _snap.rewards
      .where((r) => !r.isOwned)
      .fold(0.0, (sum, r) => sum + r.earmarkPercent);

  double get unearmarkedPercent => (100 - earmarkedPercent).clamp(0, 100);

  Reward? rewardById(String id) {
    for (final r in _snap.rewards) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Everything spendable, real and in-app together, cheapest first. This is
  /// the store's shelf.
  /// The shelf: everything spendable that is actually reachable. Long-range
  /// goals live in the vault instead, so a €40,000 deposit does not sit at the
  /// bottom of the store making everything above it feel pointless.
  List<Reward> get storeStock {
    final list = _snap.rewards
        .where((r) => !r.isOwned && !horizonOf(r).isLongRange)
        .toList()
      ..sort((a, b) => a.coinCost.compareTo(b.coinCost));
    return list;
  }

  List<Reward> get archive =>
      _snap.rewards.where((r) => r.isOwned).toList()
        ..sort((a, b) =>
            (b.claimedAt ?? b.createdAt).compareTo(a.claimedAt ?? a.createdAt));

  ThemeMode get themeMode => switch (_snap.profile.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(String mode) async {
    final p = _snap.profile.copyWith(themeMode: mode);
    _snap = _snap.copyWith(profile: p);
    await _repo.saveProfile(p);
    notifyListeners();
  }

  Cosmetic? equippedOf(CosmeticType type) {
    final id = _snap.profile.equippedIn(type.slot);
    if (id == null) return null;
    for (final c in _snap.cosmetics) {
      if (c.id == id) return c;
    }
    return null;
  }

  String get equippedTitle => equippedOf(CosmeticType.title)?.name ?? 'SUBJECT';

  // ------------------------------------------------------------- lifecycle
  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _snap = await _repo.load();
    _loading = false;
    // Settle the bill and roll the calendar before the first frame paints, so
    // the user never sees a stale number flicker to a real one.
    await _rolloverSeasonIfNeeded();
    await _expireStaleQuests();
    await accrueUpkeep();
    await _refreshCosmetics();
    await syncPassPrizes();
    notifyListeners();
  }

  /// Swaps the backing store — used when a user signs in and the anonymous
  /// local repository is replaced by their Supabase one.
  Future<void> switchRepository(OverseerRepository repo) async {
    _repo = repo;
    await load();
  }

  /// Pushes any buffered writes to storage. Called when the app is
  /// backgrounded or closing, so a burst of completions is never lost.
  Future<void> flush() => _repo.flush();

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }

  void _emit(GameEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  // ----------------------------------------------------------- core loop
  /// Grants XP, rolls the level as far as it carries, and pays the tier's
  /// credits on each crossing.
  ///
  /// This is the only path by which credits are ever minted. Tasks feed XP into
  /// it; they never mint credits themselves.
  /// Live streak, recomputed against today rather than trusted from storage.
  int get currentStreak => _snap.profile.streakAsOf(DateTime.now());

  /// How much a completion is currently worth, as a multiplier.
  double get streakMultiplier => Economy.streakMultiplier(currentStreak);

  /// The next streak length that raises the multiplier, for the readout.
  int? get nextStreakStep => Economy.nextStreakStep(currentStreak);

  /// Grants XP scaled by the streak.
  ///
  /// Only *completion* XP is scaled. Capture is not — see [_grantFlatXp] —
  /// because writing things down must never become the efficient way to farm
  /// the bar.
  Future<LevelUpResult> _grantScaledXp(int xp, String source) =>
      _grantXp((xp * streakMultiplier).round(), source);

  Future<LevelUpResult> _grantXp(int xp, String source) async {
    final (nextWallet, result) = _snap.wallet.grantXp(xp, plan);
    var w = nextWallet;
    var up = _snap.upkeep;
    var garnished = 0;

    // A debt is collected before the subject sees a credit of the payout.
    if (result.coinsAwarded > 0 && up.inArrears) {
      garnished = (result.coinsAwarded * up.garnishRate).round();
      // Never garnish more than clears the debt.
      final maxUseful = up.arrearsCredits.ceil();
      if (garnished > maxUseful) garnished = maxUseful;
      if (garnished > 0) {
        w = w.copyWith(coins: w.coins - garnished);
        up = up.credit(garnished.toDouble()).copyWith(
              lifetimeGarnishedCredits: up.lifetimeGarnishedCredits + garnished,
            );
      }
    }

    _snap = _snap.copyWith(wallet: w, upkeep: up);
    await _repo.saveWallet(w);
    if (garnished > 0) await _repo.saveUpkeep(up);

    _emit(XpGained(xp, source));
    if (result.shardsAwarded > 0) _emit(ShardsGained(result.shardsAwarded));
    if (result.leveledUp) {
      _emit(TierCrossed(result, garnished: garnished));
      await _refreshCosmetics();
    }
    notifyListeners();
    return result;
  }

  /// Marks a directive done. Grants XP immediately — always, no exceptions,
  /// including for things that earn no money at all. The credits, if any, wait
  /// for the collect tap.
  Future<LevelUpResult?> completeQuest(String id) async {
    final i = _snap.quests.indexWhere((q) => q.id == id);
    if (i < 0) return null;
    final q = _snap.quests[i];
    if (q.status == QuestStatus.collected) return null;

    final progress = (q.progressCount + 1).clamp(0, q.targetCount);
    final nowComplete = progress >= q.targetCount;
    final updated = q.copyWith(
      progressCount: progress,
      status: nowComplete ? QuestStatus.done : QuestStatus.open,
      completedAt: nowComplete ? DateTime.now() : null,
    );
    await _replaceQuest(i, updated);

    // A repeating target pays a proportional slice per tick, so "dishes twice"
    // still moves the bar the first time rather than only at the end.
    final xp = q.isRepeating ? (q.xpValue / q.targetCount).round() : q.xpValue;
    final result = await _grantScaledXp(xp, q.title);

    if (q.masteryTrackId != null) {
      // A directive tied to a craft logs a nominal half hour toward it.
      await logMasteryHours(q.masteryTrackId!, 0.5, note: q.title, grantXp: false);
    }
    return result;
  }

  /// The deliberate second step. Earning and claiming stay separate because the
  /// tap is what makes it feel active — and because an expiry that can strand
  /// an uncollected reward is what makes it urgent.
  Future<void> collectQuest(String id) async {
    final i = _snap.quests.indexWhere((q) => q.id == id);
    if (i < 0) return;
    final q = _snap.quests[i];
    if (q.status != QuestStatus.done || q.isExpired) return;

    final updated = q.copyWith(
      status: QuestStatus.collected,
      collectedAt: DateTime.now(),
    );
    await _replaceQuest(i, updated);

    if (q.coinValue > 0) {
      final w = _snap.wallet.addCoins(q.coinValue);
      _snap = _snap.copyWith(wallet: w);
      await _repo.saveWallet(w);
    }

    final before = _snap.profile.streakAsOf(DateTime.now());
    final (p, broken) = _snap.profile.touch(DateTime.now());
    final profile = p.copyWith(questsCollected: p.questsCollected + 1);
    _snap = _snap.copyWith(profile: profile);
    await _repo.saveProfile(profile);

    // A shard per collection, plus a lump whenever the streak crosses a
    // milestone. Holding a streak is by far the most productive way to earn
    // them, which is the intended lesson.
    var shards = Economy.shardsPerCollect;
    if (profile.streak > before) {
      shards += Economy.streakShardMilestones[profile.streak] ?? 0;
      if (Economy.streakShardMilestones.containsKey(profile.streak)) {
        _emit(StreakMilestone(
            profile.streak, Economy.streakShardMilestones[profile.streak]!));
      }
    }
    await _awardShards(shards);

    _emit(QuestCollected(q.title, q.coinValue));
    if (broken || profile.streak != _snap.profile.streak) {
      _emit(StreakChanged(profile.streak, broken));
    }
    await _refreshCosmetics();
    notifyListeners();
  }

  Future<void> _replaceQuest(int index, Quest q) async {
    final next = [..._snap.quests];
    next[index] = q;
    _snap = _snap.copyWith(quests: next);
    await _repo.upsertQuest(q);
  }

  Future<Quest> addQuest({
    required String title,
    String? notes,
    int xpValue = Economy.xpSmall,
    int coinValue = 0,
    Cadence cadence = Cadence.once,
    bool earnsIncome = false,
    int targetCount = 1,
    String? masteryTrackId,
  }) async {
    final q = Quest(
      id: _uuid.v4(),
      title: title.trim(),
      notes: notes,
      xpValue: xpValue,
      coinValue: coinValue,
      cadence: cadence,
      earnsIncome: earnsIncome,
      targetCount: targetCount,
      masteryTrackId: masteryTrackId,
      createdAt: DateTime.now(),
      expiresAt: expiryFor(cadence),
    );
    _snap = _snap.copyWith(quests: [..._snap.quests, q]);
    await _repo.upsertQuest(q);
    // Writing a thing down is the step people skip, and an unrecorded
    // intention cannot be completed later. Acknowledge it — tinily.
    await _rewardCapture(Economy.xpForCapture, Economy.creditsForCapture);
    notifyListeners();
    return q;
  }

  /// Pays the small, unscaled acknowledgement for capturing something.
  ///
  /// Never multiplied by the streak, and never large enough that logging noise
  /// beats doing the work.
  Future<void> _rewardCapture(int xp, int credits) async {
    if (credits > 0) {
      final w = _snap.wallet.addCoins(credits);
      _snap = _snap.copyWith(wallet: w);
      await _repo.saveWallet(w);
    }
    if (xp > 0) await _grantXp(xp, 'CAPTURE');
  }

  /// Public capture hooks, used by the braindump and the manifest.
  Future<void> rewardBraindump(int itemCount) =>
      _rewardCapture(Economy.xpForDumpItem * itemCount, 0);

  Future<void> _awardShards(int amount) async {
    if (amount <= 0) return;
    final w = _snap.wallet.addShards(amount);
    _snap = _snap.copyWith(wallet: w);
    await _repo.saveWallet(w);
    _emit(ShardsGained(amount));
  }

  /// Spends shards on an in-app unlock. Returns false when short.
  Future<bool> spendShards(int amount, String on) async {
    if (!_snap.wallet.canAffordShards(amount)) {
      _emit(GameNotice('SHORT ${amount - _snap.wallet.shards} SHARDS'));
      return false;
    }
    final w = _snap.wallet.spendShards(amount);
    _snap = _snap.copyWith(wallet: w);
    await _repo.saveWallet(w);
    notifyListeners();
    return true;
  }

  Future<void> updateQuest(Quest q) async {
    final i = _snap.quests.indexWhere((e) => e.id == q.id);
    if (i < 0) return;
    await _replaceQuest(i, q);
    notifyListeners();
  }

  Future<void> deleteQuest(String id) async {
    _snap = _snap.copyWith(quests: _snap.quests.where((q) => q.id != id).toList());
    await _repo.deleteQuest(id);
    notifyListeners();
  }

  /// When a cadence's window closes. Daily quests die at midnight; weekly ones
  /// at the end of the week, whether or not they were finished — an uncollected
  /// reward is simply gone, and that is the point.
  static DateTime? expiryFor(Cadence c, {DateTime? from}) {
    final now = from ?? DateTime.now();
    return switch (c) {
      Cadence.once => null,
      Cadence.daily => DateTime(now.year, now.month, now.day + 1),
      Cadence.weekly =>
        DateTime(now.year, now.month, now.day + (8 - now.weekday)),
      Cadence.monthly => DateTime(now.year, now.month + 1, 1),
      Cadence.quarterly =>
        DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 4, 1),
    };
  }

  /// Rolls recurring directives into their next window and clears the ones that
  /// ran out of time uncollected.
  Future<void> _expireStaleQuests() async {
    final now = DateTime.now();
    final next = <Quest>[];
    var changed = false;

    for (final q in _snap.quests) {
      final expired = q.expiresAt != null && now.isAfter(q.expiresAt!);
      if (!expired) {
        next.add(q);
        continue;
      }
      if (q.cadence == Cadence.once) {
        // A one-off that expired is just gone.
        changed = true;
        await _repo.deleteQuest(q.id);
        continue;
      }
      // Recurring: reset progress and re-arm for the new window. Anything not
      // collected in the old window is forfeit.
      final rolled = q.copyWith(
        status: QuestStatus.open,
        progressCount: 0,
        expiresAt: expiryFor(q.cadence, from: now),
      );
      next.add(rolled);
      await _repo.upsertQuest(rolled);
      changed = true;
    }

    if (changed) _snap = _snap.copyWith(quests: next);
  }

  // ------------------------------------------------------------- upkeep
  /// Settles the cost of being alive for every day that has passed since the
  /// last accrual, then applies the levy on whatever debt is left.
  Future<AccrualResult> accrueUpkeep() async {
    final now = DateTime.now();
    var up = _snap.upkeep;
    final last = up.lastAccruedAt;
    if (last == null) {
      up = up.copyWith(lastAccruedAt: now);
      _snap = _snap.copyWith(upkeep: up);
      await _repo.saveUpkeep(up);
      return const AccrualResult();
    }

    // Whole days only; the remainder stays on the clock for tomorrow.
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    if (days <= 0) return const AccrualResult();

    // A phone left in a drawer for a year should not spend a second grinding
    // through 365 iterations of compound interest on launch.
    final steps = days.clamp(0, 400);
    final burnPerDay = dailyBurnCredits;
    final wasInArrears = up.inArrears;

    var burned = 0.0;
    var levy = 0.0;
    var balance = up.balanceCredits;
    for (var d = 0; d < steps; d++) {
      balance -= burnPerDay;
      burned += burnPerDay;
      if (balance < 0) {
        final l = -balance * up.arrearsDailyRate;
        balance -= l;
        levy += l;
      }
    }

    up = up.copyWith(
      balanceCredits: balance,
      lastAccruedAt: DateTime(now.year, now.month, now.day),
      lifetimeLevyCredits: up.lifetimeLevyCredits + levy,
    );
    _snap = _snap.copyWith(upkeep: up);
    await _repo.saveUpkeep(up);

    final result = AccrualResult(
      days: days,
      burnedCredits: burned,
      levyCredits: levy,
      enteredArrears: !wasInArrears && up.inArrears,
    );
    if (burned > 0 || levy > 0) {
      _emit(UpkeepAccrued(burned, levy, days, result.enteredArrears));
    }
    notifyListeners();
    return result;
  }

  Future<void> addObligation({
    required String name,
    required double amountEuro,
    required ObligationCadence cadence,
  }) async {
    final o = Obligation(
      id: _uuid.v4(),
      name: name.trim(),
      amountEuro: amountEuro,
      cadence: cadence,
      createdAt: DateTime.now(),
    );
    _snap = _snap.copyWith(obligations: [..._snap.obligations, o]);
    await _repo.upsertObligation(o);
    notifyListeners();
  }

  Future<void> updateObligation(Obligation o) async {
    final next = [..._snap.obligations];
    final i = next.indexWhere((e) => e.id == o.id);
    if (i < 0) return;
    next[i] = o;
    _snap = _snap.copyWith(obligations: next);
    await _repo.upsertObligation(o);
    notifyListeners();
  }

  Future<void> deleteObligation(String id) async {
    _snap = _snap.copyWith(
        obligations: _snap.obligations.where((o) => o.id != id).toList());
    await _repo.deleteObligation(id);
    notifyListeners();
  }

  Future<void> setArrearsRate(double rate) async {
    final up = _snap.upkeep.copyWith(arrearsDailyRate: rate);
    _snap = _snap.copyWith(upkeep: up);
    await _repo.saveUpkeep(up);
    notifyListeners();
  }

  Future<void> setGarnishRate(double rate) async {
    final up = _snap.upkeep.copyWith(garnishRate: rate.clamp(0.0, 1.0));
    _snap = _snap.copyWith(upkeep: up);
    await _repo.saveUpkeep(up);
    notifyListeners();
  }

  // -------------------------------------------------------------- income
  /// Logs real money coming in.
  ///
  /// The reward share goes to the reserve, which is the only thing a real
  /// reward can ever be claimed against. The rest credits upkeep, because that
  /// is what actually pays rent. XP is granted for the work behind it, so a
  /// paid win moves the bar like anything else does.
  Future<void> logIncome({
    required double amountEuro,
    String source = '',
    int xp = Economy.xpBigWin,
  }) async {
    if (amountEuro <= 0) return;
    final toFund = amountEuro * (_snap.fund.percent / 100);
    final toUpkeep = amountEuro - toFund;

    // Long goals take their earmarked share off the top, into their own pots.
    // What is left is the general reserve everything else claims against.
    var rewards = _snap.rewards;
    var earmarked = 0.0;
    final earmarks = rewards.where((r) => r.isEarmarked && !r.isOwned).toList();
    if (earmarks.isNotEmpty) {
      final updated = <String, Reward>{};
      for (final r in earmarks) {
        // Never put by more than the goal still needs.
        final share = (toFund * (r.earmarkPercent / 100))
            .clamp(0.0, r.outstandingEuro);
        if (share <= 0) continue;
        earmarked += share;
        updated[r.id] = r.copyWith(savedEuro: r.savedEuro + share);
      }
      if (updated.isNotEmpty) {
        rewards = [for (final r in rewards) updated[r.id] ?? r];
        for (final r in updated.values) {
          await _repo.upsertReward(r);
        }
      }
    }

    final f = _snap.fund.deposit(toFund - earmarked);
    final up = _snap.upkeep.credit(Economy.euroToCoins(toUpkeep).toDouble());
    final entry = IncomeEntry(
      id: _uuid.v4(),
      source: source.trim(),
      amountEuro: amountEuro,
      toFundEuro: toFund,
      loggedAt: DateTime.now(),
    );

    _snap = _snap.copyWith(
        fund: f, upkeep: up, rewards: rewards, income: [entry, ..._snap.income]);
    await _repo.saveFund(f);
    await _repo.saveUpkeep(up);
    await _repo.insertIncome(entry);

    _emit(IncomeLogged(amountEuro, toFund));
    if (xp > 0) await _grantScaledXp(xp, source.isEmpty ? 'INCOME' : source);
    notifyListeners();
  }

  Future<void> setFundPercent(double percent) async {
    final f = _snap.fund.copyWith(percent: percent.clamp(0, 100));
    _snap = _snap.copyWith(fund: f);
    await _repo.saveFund(f);
    // The season's credit budget is income × this share, so moving it moves
    // the whole ladder.
    await _replanSeason();
  }

  // ------------------------------------------------------------- rewards
  /// Why a claim was refused, so the UI can say something specific rather than
  /// greying a button out with no explanation.
  String? claimBlockReason(Reward r) {
    if (r.isOwned) return 'ALREADY HELD';
    if (_snap.wallet.coins < r.coinCost) {
      final short = r.coinCost - _snap.wallet.coins;
      return 'SHORT $short ${_fmtPlain(short)}';
    }
    // An earmarked goal is paid for out of its own pot first, then whatever
    // the general reserve can add.
    final available = _snap.fund.balanceEuro + r.savedEuro;
    if (available + 1e-9 < r.priceEuro) {
      final short = r.priceEuro - available;
      return 'RESERVE SHORT €${short.toStringAsFixed(2)}';
    }
    return null;
  }

  String _fmtPlain(int n) => n == 1 ? 'CREDIT' : 'CREDITS';

  bool canClaim(Reward r) => claimBlockReason(r) == null;

  /// Burns the credits and moves the reward into the archive.
  ///
  /// Guarded by the reserve on purpose: a reward the user's real money cannot
  /// cover can never be claimed, no matter how many credits they have ground
  /// out. That constraint is the whole reason the numbers mean anything.
  Future<bool> claimReward(String id) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    final r = _snap.rewards[i];
    if (!canClaim(r)) {
      _emit(GameNotice(claimBlockReason(r) ?? 'DENIED'));
      return false;
    }

    final w = _snap.wallet.spendCoins(r.coinCost);
    final updated = r.copyWith(status: RewardStatus.claimed, claimedAt: DateTime.now());
    final rewards = [..._snap.rewards]..[i] = updated;
    final profile = _snap.profile.copyWith(rewardsClaimed: _snap.profile.rewardsClaimed + 1);
    final taste = _snap.taste.withClaim(r.name);

    _snap = _snap.copyWith(wallet: w, rewards: rewards, profile: profile, taste: taste);
    await _repo.saveWallet(w);
    await _repo.upsertReward(updated);
    await _repo.saveProfile(profile);
    await _repo.saveTaste(taste);

    _emit(CreditsSpent(r.coinCost, r.name));
    await _refreshCosmetics();
    notifyListeners();
    return true;
  }

  /// The real-world half. No bank, no card, no automation — a button the user
  /// presses when they actually went and got the thing, which takes the euros
  /// out of the reserve and gives the same feeling of money leaving.
  ///
  /// The seam for automated spend detection sits exactly here.
  Future<void> markBought(String id) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _snap.rewards[i];
    if (r.status == RewardStatus.bought) return;

    // A reward bought without being claimed first still burns its credits.
    var w = _snap.wallet;
    if (r.status != RewardStatus.claimed) {
      if (w.coins < r.coinCost || !_snap.fund.covers(r.priceEuro)) {
        _emit(GameNotice(claimBlockReason(r) ?? 'DENIED'));
        return;
      }
      w = w.spendCoins(r.coinCost);
      _emit(CreditsSpent(r.coinCost, r.name));
    }

    final f = _snap.fund.withdraw(r.priceEuro);
    final updated = r.copyWith(status: RewardStatus.bought, boughtAt: DateTime.now());
    final rewards = [..._snap.rewards]..[i] = updated;

    _snap = _snap.copyWith(wallet: w, fund: f, rewards: rewards);
    await _repo.saveWallet(w);
    await _repo.saveFund(f);
    await _repo.upsertReward(updated);
    notifyListeners();
  }

  /// Commits to a long-term goal. After this its price and details stop being
  /// editable — a motivated past-self protecting itself from a lazy future-self.
  Future<void> lockReward(String id) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final updated = _snap.rewards[i].copyWith(status: RewardStatus.locked);
    final rewards = [..._snap.rewards]..[i] = updated;
    _snap = _snap.copyWith(rewards: rewards);
    await _repo.upsertReward(updated);
    notifyListeners();
  }

  /// Commits a share of every future reserve deposit to one goal.
  ///
  /// Capped so the earmarks can never exceed the reserve itself — a plan that
  /// allocates 140% of your savings is not a plan.
  Future<void> setEarmark(String id, double percent) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _snap.rewards[i];
    final others = earmarkedPercent - r.earmarkPercent;
    final capped = percent.clamp(0.0, (100 - others).clamp(0.0, 100.0));

    final updated = r.copyWith(earmarkPercent: capped);
    final rewards = [..._snap.rewards]..[i] = updated;
    _snap = _snap.copyWith(rewards: rewards);
    await _repo.upsertReward(updated);
    await syncPassPrizes();
    notifyListeners();
  }

  /// Re-bands every goal against the current cashflow and reports anything that
  /// has just come within reach of a season.
  ///
  /// Called whenever income, the reserve share or a price changes — which is
  /// the point: a raise should visibly pull distant things closer rather than
  /// leaving the user to notice on their own.
  Future<List<Reward>> _promoteReachableGoals() async {
    final promoted = <Reward>[];
    for (final r in _snap.rewards) {
      if (r.isOwned) continue;
      if (!horizonOf(r).eligibleForSeason) continue;
      // Only interesting if it was previously out of a season's reach; a goal
      // big enough to have carried an earmark is one the user was saving for.
      if (r.priceEuro > annualReserveEuro / 4 || r.isEarmarked) {
        promoted.add(r);
      }
    }
    if (promoted.isNotEmpty) {
      _emit(GoalsPromoted(promoted.map((r) => r.name).toList()));
    }
    return promoted;
  }

  Future<void> starReward(String id, bool starred) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final updated = _snap.rewards[i].copyWith(starred: starred);
    final rewards = [..._snap.rewards]..[i] = updated;
    final taste =
        starred ? _snap.taste.withClaim(updated.name) : _snap.taste;
    _snap = _snap.copyWith(rewards: rewards, taste: taste);
    await _repo.upsertReward(updated);
    if (starred) await _repo.saveTaste(taste);
    notifyListeners();
  }

  /// Dismissing is the strongest taste signal there is — it is the only one
  /// that tells the generator what to stop doing.
  Future<void> dismissReward(String id) async {
    final i = _snap.rewards.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _snap.rewards[i];
    final taste = _snap.taste.withDismissal(r.name);
    _snap = _snap.copyWith(
      rewards: _snap.rewards.where((e) => e.id != id).toList(),
      taste: taste,
    );
    await _repo.deleteReward(id);
    await _repo.saveTaste(taste);
    notifyListeners();
  }

  Future<Reward> addReward(Reward r) async {
    _snap = _snap.copyWith(rewards: [r, ..._snap.rewards]);
    await _repo.upsertReward(r);
    await _rewardCapture(Economy.xpForWish, Economy.creditsForWish);
    // A wish added today should appear on the ladder today.
    await syncPassPrizes();
    notifyListeners();
    return r;
  }

  Future<void> updateReward(Reward r) async {
    final i = _snap.rewards.indexWhere((e) => e.id == r.id);
    if (i < 0) return;
    final rewards = [..._snap.rewards]..[i] = r;
    _snap = _snap.copyWith(rewards: rewards);
    await _repo.upsertReward(r);
    notifyListeners();
  }

  Future<Bucket> ensureBucket(String name) async {
    final clean = name.trim().toUpperCase();
    for (final b in _snap.buckets) {
      if (b.name.toUpperCase() == clean) return b;
    }
    final b = Bucket(id: _uuid.v4(), name: clean, createdAt: DateTime.now());
    _snap = _snap.copyWith(buckets: [..._snap.buckets, b]);
    await _repo.upsertBucket(b);
    notifyListeners();
    return b;
  }

  // ------------------------------------------------------------- mastery
  Future<MasteryTrack> addTrack(String name) async {
    final t = MasteryTrack(
      id: _uuid.v4(),
      name: name.trim().toUpperCase(),
      createdAt: DateTime.now(),
    );
    _snap = _snap.copyWith(tracks: [..._snap.tracks, t]);
    await _repo.upsertTrack(t);
    notifyListeners();
    return t;
  }

  Future<void> deleteTrack(String id) async {
    _snap = _snap.copyWith(
      tracks: _snap.tracks.where((t) => t.id != id).toList(),
      hourLogs: _snap.hourLogs.where((h) => h.trackId != id).toList(),
    );
    await _repo.deleteTrack(id);
    notifyListeners();
  }

  /// Logs time against a craft. The track levels purely from hours — never from
  /// euros — but the hours also feed ordinary XP, so the main bar still moves
  /// for work that pays nothing at all.
  Future<void> logMasteryHours(
    String trackId,
    double hours, {
    String? note,
    bool grantXp = true,
  }) async {
    final i = _snap.tracks.indexWhere((t) => t.id == trackId);
    if (i < 0 || hours <= 0) return;

    final (updated, levelsGained) = _snap.tracks[i].logHours(hours);
    final tracks = [..._snap.tracks]..[i] = updated;
    final log = HourLog(
      id: _uuid.v4(),
      trackId: trackId,
      hours: hours,
      note: note,
      loggedAt: DateTime.now(),
    );

    _snap = _snap.copyWith(tracks: tracks, hourLogs: [log, ..._snap.hourLogs]);
    await _repo.upsertTrack(updated);
    await _repo.insertHourLog(log);

    if (levelsGained > 0) {
      _emit(MasteryLevelUp(updated.name, updated.level));
      await _awardShards(Economy.shardsPerMasteryLevel * levelsGained);
    }
    if (grantXp) {
      await _grantScaledXp(
          (hours * Economy.xpPerMasteryHour).round(), updated.name);
    }
    await _refreshCosmetics();
    notifyListeners();
  }

  // ----------------------------------------------------------- cosmetics
  /// Re-evaluates every unlock condition against live state. Cheap, and called
  /// after anything that could plausibly cross a threshold.
  Future<void> _refreshCosmetics() async {
    final p = _snap.profile;
    final w = _snap.wallet;
    final maxHours = _snap.tracks.fold(0.0, (m, t) => t.totalHours > m ? t.totalHours : m);
    final maxMasteryLevel = _snap.tracks.fold(0, (m, t) => t.level > m ? t.level : m);

    var changed = false;
    final next = <Cosmetic>[];
    for (final c in _snap.cosmetics) {
      if (c.unlocked) {
        next.add(c);
        continue;
      }
      final value = switch (c.unlockKind) {
        UnlockKind.tier => w.level,
        UnlockKind.streak => p.streak,
        UnlockKind.masteryHours => maxHours.floor(),
        UnlockKind.masteryLevel => maxMasteryLevel,
        UnlockKind.lifetimeXp => w.totalXp,
        UnlockKind.questsCollected => p.questsCollected,
        UnlockKind.rewardsClaimed => p.rewardsClaimed,
      };
      if (value >= c.unlockThreshold) {
        final unlocked = c.copyWith(unlocked: true, unlockedAt: DateTime.now());
        next.add(unlocked);
        changed = true;
        await _repo.upsertCosmetic(unlocked);
        _emit(CosmeticUnlocked(unlocked));
      } else {
        next.add(c);
      }
    }
    if (changed) {
      _snap = _snap.copyWith(cosmetics: next);
      notifyListeners();
    }
  }

  Future<void> equipCosmetic(String id) async {
    final c = _snap.cosmetics.firstWhere(
      (e) => e.id == id,
      orElse: () => throw ArgumentError('unknown cosmetic $id'),
    );
    if (!c.unlocked) return;

    // One per slot: clear whatever was worn there, wear this.
    final next = _snap.cosmetics
        .map((e) => e.type == c.type ? e.copyWith(equipped: e.id == id) : e)
        .toList();
    final profile = _snap.profile.equip(c.type.slot, id);
    _snap = _snap.copyWith(cosmetics: next, profile: profile);
    await _repo.saveProfile(profile);
    for (final e in next.where((e) => e.type == c.type)) {
      await _repo.upsertCosmetic(e);
    }
    notifyListeners();
  }

  // -------------------------------------------------------------- season
  /// Pins the manifest onto the ladder's real-world rungs, and the cosmetic
  /// catalogue onto the rungs between them.
  ///
  /// Cheap wishes land early and expensive ones late, so the ladder genuinely
  /// gets better as it climbs rather than handing over a €900 item at tier 10.
  /// Called whenever the manifest changes, because a wish added today should
  /// appear on the ladder today.
  Future<void> syncPassPrizes() async {
    final season = _snap.season;
    if (season.tiers.isEmpty) return;

    // Candidates: everything still wantable, cheapest first.
    final wishes = _snap.rewards
        .where((r) =>
            !r.isOwned &&
            r.kind == RewardKind.realWorld &&
            // A rung that cannot be reached inside the season is worse than an
            // empty one. Long goals belong to the vault.
            !horizonOf(r).isLongRange)
        .toList()
      ..sort((a, b) => a.coinCost.compareTo(b.coinCost));

    // Cosmetics not yet unlocked, in catalogue order.
    final locked = _snap.cosmetics.where((c) => !c.unlocked).toList();

    var wishIndex = 0;
    var cosmeticIndex = 0;
    var changed = false;
    final tiers = <PassTier>[];

    for (final t in season.tiers) {
      switch (t.kind) {
        // Both kinds of reward rung draw from the manifest; a major one simply
        // lands later in the ladder and so gets a more expensive wish.
        case RungKind.real:
        case RungKind.major:
          if (wishIndex < wishes.length) {
            final w = wishes[wishIndex++];
            if (t.rewardId != w.id) changed = true;
            tiers.add(t.copyWith(rewardId: w.id, rewardName: w.name));
          } else {
            tiers.add(t);
          }
        case RungKind.cosmetic:
          if (cosmeticIndex < locked.length) {
            final c = locked[cosmeticIndex++];
            if (t.cosmeticId != c.id) changed = true;
            tiers.add(t.copyWith(cosmeticId: c.id, cosmeticName: c.name));
          } else {
            tiers.add(t);
          }
        case RungKind.credits:
        case RungKind.nothing:
          tiers.add(t);
      }
    }

    if (!changed) return;
    final next = season.copyWith(tiers: tiers);
    _snap = _snap.copyWith(season: next);
    await _repo.saveSeason(next);
    notifyListeners();
  }

  /// A season that has run out is replaced by a fresh one. Credits and lifetime
  /// XP survive; the ladder and the level do not. The reset is the pressure.
  Future<void> _rolloverSeasonIfNeeded() async {
    if (!_snap.season.hasExpired) return;
    final next = Season.quarterly(
      id: _uuid.v4(),
      startsAt: DateTime.now(),
      plan: plan,
    );
    final w = _snap.wallet.resetSeason();
    _snap = _snap.copyWith(season: next, wallet: w);
    await _repo.saveSeason(next);
    await _repo.saveWallet(w);
    _emit(SeasonRolled(next.name));
  }

  // ----------------------------------------------------------- companion
  Future<void> setCompanionPosition(double x, double y) async {
    final c = _snap.companion.copyWith(x: x, y: y);
    _snap = _snap.copyWith(companion: c);
    await _repo.saveCompanion(c);
    // No notify: dragging repaints through the widget's own animation, and
    // rebuilding the whole tree on every pointer move would be wasteful.
  }

  Future<void> pushCompanionMessage(CompanionMessage m) async {
    final c = _snap.companion.withMessage(m);
    _snap = _snap.copyWith(companion: c);
    await _repo.saveCompanion(c);
    notifyListeners();
  }

  /// Changes how the overseer looks or sounds. Shape, finish, paint and
  /// persona are independent, so any combination in the catalogue is reachable.
  Future<void> setAppearance(Appearance a) async {
    final c = _snap.companion.copyWith(appearance: a);
    _snap = _snap.copyWith(companion: c);
    await _repo.saveCompanion(c);
    notifyListeners();
  }

  Future<void> setCompanionMood(CompanionMood mood) async {
    if (_snap.companion.mood == mood) return;
    final c = _snap.companion.copyWith(mood: mood);
    _snap = _snap.copyWith(companion: c);
    await _repo.saveCompanion(c);
    notifyListeners();
  }

  // ------------------------------------------------------------- profile
  Future<void> setDisplayName(String name) async {
    final p = _snap.profile.copyWith(displayName: name.trim());
    _snap = _snap.copyWith(profile: p);
    await _repo.saveProfile(p);
    notifyListeners();
  }

  Future<void> saveTaste(TasteProfile t) async {
    _snap = _snap.copyWith(taste: t);
    await _repo.saveTaste(t);
    notifyListeners();
  }

  // --------------------------------------------------------- calibration
  /// Declares what the user expects to earn, and rebuilds the ladder around it.
  ///
  /// This is what stops credits and euros drifting apart: the season's whole
  /// issuance is re-derived so that clearing the pass pays out exactly what
  /// will have been set aside.
  Future<void> setExpectedIncome(double monthlyEuro,
      {bool fromStatement = false}) async {
    final c = _snap.calibration.copyWith(
      expectedMonthlyIncomeEuro: monthlyEuro,
      fromStatement: fromStatement,
      isCalibrated: monthlyEuro > 0,
      calibratedAt: DateTime.now(),
    );
    _snap = _snap.copyWith(calibration: c);
    await _repo.saveCalibration(c);
    await _replanSeason();
  }

  Future<void> setDifficulty(Difficulty d) async {
    if (_snap.calibration.difficulty == d) return;
    final c = _snap.calibration.copyWith(difficulty: d);
    _snap = _snap.copyWith(calibration: c);
    await _repo.saveCalibration(c);
    await _replanSeason();
  }

  /// Records a month's measured income and re-calibrates from the average.
  ///
  /// The seam a banking integration implements: it produces [StatementEntry]
  /// values and calls this. Nothing downstream cares whether a human typed the
  /// figure or an API returned it, and no credential is ever handled here.
  Future<void> addStatement({
    required DateTime month,
    required double incomeEuro,
    double? outgoingsEuro,
    String source = 'manual',
  }) async {
    final entry = StatementEntry(
      id: _uuid.v4(),
      month: DateTime(month.year, month.month),
      incomeEuro: incomeEuro,
      outgoingsEuro: outgoingsEuro,
      source: source,
      recordedAt: DateTime.now(),
    );
    final next = [entry, ..._snap.statements.where((e) => e.month != entry.month)];
    _snap = _snap.copyWith(statements: next);
    await _repo.insertStatement(entry);
    await setExpectedIncome(averageMonthlyIncome(next), fromStatement: true);
  }

  /// Rebuilds the current season's rungs in place, preserving how far the user
  /// has climbed. Their progress is theirs; only the costs and payouts move.
  Future<void> _replanSeason() async {
    final next = Season.quarterly(
      id: _snap.season.id,
      startsAt: _snap.season.startsAt,
      name: _snap.season.name,
      plan: plan,
    );
    _snap = _snap.copyWith(season: next);
    await _repo.saveSeason(next);
    await syncPassPrizes();
    // Cashflow moved, so what is reachable moved with it.
    await _promoteReachableGoals();
    notifyListeners();
  }

  Future<void> resetEverything() async {
    await _repo.wipe();
    await load();
  }

  /// Debug-only shortcut used by the demo seeder to put the account partway up
  /// the ladder. Deliberately routes through the real [_grantXp] so the seeded
  /// state is reachable by ordinary play rather than fabricated.
  @visibleForTesting
  Future<void> grantDemoXp(int xp) => _grantXp(xp, 'SEED');
}
