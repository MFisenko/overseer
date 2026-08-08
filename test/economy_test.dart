import 'package:flutter_test/flutter_test.dart';
import 'package:overseer/core/economy.dart';
import 'package:overseer/core/horizon.dart';
import 'package:overseer/models/calibration.dart';
import 'package:overseer/models/mastery.dart';
import 'package:overseer/models/profile.dart';
import 'package:overseer/models/upkeep.dart';
import 'package:overseer/models/wallet.dart';

/// The economy is the product. If these rules drift, the app stops meaning
/// anything, so they are pinned here rather than left to the UI to enforce.
void main() {
  /// A ladder for a person on €2,000 a month setting aside 10%.
  final plan = LadderPlan.from(
    calibration: const Calibration(
      expectedMonthlyIncomeEuro: 2000,
      isCalibrated: true,
      difficulty: Difficulty.basic,
    ),
    fundPercent: 10,
  );

  group('the split between XP and credits', () {
    test('XP alone never mints credits', () {
      // One short of tier 1's threshold: the bar moves and nothing is paid.
      final need = plan.xpFor(1);
      final (w, r) = const Wallet().grantXp(need - 1, plan);
      expect(w.totalXp, need - 1);
      expect(w.coins, 0);
      expect(r.leveledUp, isFalse);
    });

    test('crossing a tier pays exactly that tier', () {
      final (w, r) = const Wallet().grantXp(plan.xpFor(1), plan);
      expect(r.leveledUp, isTrue);
      expect(w.level, 2);
      expect(w.coins, plan.payoutFor(2));
      expect(w.xpIntoLevel, 0);
    });

    test('a single large win can carry several tiers at once', () {
      final (w, r) = const Wallet().grantXp(5000, plan);
      expect(r.tiersCrossed.length, greaterThan(1));
      expect(w.level, r.endLevel);
      final expected =
          r.tiersCrossed.fold(0, (sum, t) => sum + plan.payoutFor(t));
      expect(w.coins, expected);
    });

    test('most rungs pay nothing at all', () {
      // Sparse payouts are deliberate: with a fixed budget, paying on fewer
      // rungs makes each one land as an event.
      final empty = [
        for (var t = 1; t <= Economy.seasonTiers; t++)
          if (plan.payoutFor(t) == 0) t
      ];
      expect(empty.length, greaterThan(Economy.seasonTiers ~/ 2));
    });

    test('a season reset keeps credits and lifetime XP, drops the ladder', () {
      final (w, _) = const Wallet().grantXp(3000, plan);
      final after = w.resetSeason();
      expect(after.coins, w.coins);
      expect(after.totalXp, w.totalXp);
      expect(after.level, 1);
      expect(after.seasonXp, 0);
    });
  });

  group('the ladder is calibrated to real income', () {
    test('clearing the pass pays what the reserve will hold', () {
      // This is the answer to "what if credits do not match the money".
      // €2,000/month at 10% is €600 a quarter — so the whole ladder pays
      // 60,000 credits, give or take the rounding to readable figures.
      expect(plan.budget, 60000);
      expect(plan.totalPayout, closeTo(60000, 60000 * 0.02));
    });

    test('a bigger earner gets a richer ladder for the same effort', () {
      final richer = LadderPlan.from(
        calibration: const Calibration(
          expectedMonthlyIncomeEuro: 6000,
          isCalibrated: true,
          difficulty: Difficulty.basic,
        ),
        fundPercent: 10,
      );
      expect(richer.totalPayout, greaterThan(plan.totalPayout * 2.5));
      // Same difficulty, so the climb itself is identical.
      expect(richer.xpFor(40), plan.xpFor(40));
    });

    test('setting aside more raises the budget proportionally', () {
      final generous = LadderPlan.from(
        calibration: const Calibration(
          expectedMonthlyIncomeEuro: 2000,
          isCalibrated: true,
          difficulty: Difficulty.basic,
        ),
        fundPercent: 20,
      );
      expect(generous.budget, plan.budget * 2);
    });

    test('difficulty changes the effort, never the money', () {
      for (final d in Difficulty.values) {
        final p = LadderPlan.from(
          calibration: Calibration(
            expectedMonthlyIncomeEuro: 2000,
            isCalibrated: true,
            difficulty: d,
          ),
          fundPercent: 10,
        );
        expect(p.totalPayout, plan.totalPayout,
            reason: '${d.name} must pay the same as any other difficulty');
      }
      final hell = LadderPlan.from(
        calibration: const Calibration(
          expectedMonthlyIncomeEuro: 2000,
          isCalibrated: true,
          difficulty: Difficulty.hell,
        ),
        fundPercent: 10,
      );
      expect(hell.xpFor(50), greaterThan(plan.xpFor(50) * 5));
    });

    test('an uncalibrated account still gets a modest, working ladder', () {
      final fresh = LadderPlan.from(
        calibration: const Calibration(),
        fundPercent: Economy.defaultFundPercent,
      );
      expect(fresh.budget, greaterThan(0));
      expect(fresh.totalPayout, greaterThan(0));
    });
  });

  group('goals are banded by time, not by price', () {
    // €2,000/month at 10% is €2,400 a year reaching the reserve.
    const annual = 2400.0;

    Horizon band(double price, {double saved = 0}) => bandFor(
          priceEuro: price,
          annualReserveEuro: annual,
          alreadySavedEuro: saved,
          covered: false,
        );

    test('small things sit inside the season', () {
      expect(band(400), Horizon.thisSeason); // ~2 months
    });

    test('a year-sized thing waits for a future season', () {
      expect(band(2000), Horizon.onDeck);
    });

    test('a car is long range, not a ladder rung', () {
      expect(band(12000), Horizon.longRange); // 5 years
      expect(band(12000).isLongRange, isTrue);
      expect(band(12000).eligibleForSeason, isFalse);
    });

    test('a deposit past ten years is called what it is', () {
      expect(band(42000), Horizon.beyondHorizon); // 17.5 years
    });

    test('money already put by pulls a goal closer', () {
      expect(band(12000), Horizon.longRange);
      expect(band(12000, saved: 11500), Horizon.thisSeason);
    });

    test('with no income declared, nothing is claimed to be reachable', () {
      expect(
        bandFor(
            priceEuro: 500,
            annualReserveEuro: 0,
            alreadySavedEuro: 0,
            covered: false),
        Horizon.beyondHorizon,
      );
    });

    test('a covered goal is in reach regardless of price', () {
      expect(
        bandFor(
            priceEuro: 42000,
            annualReserveEuro: annual,
            alreadySavedEuro: 0,
            covered: true),
        Horizon.inReach,
      );
    });
  });

  group('long goals are dated, and the date responds to cashflow', () {
    test('years remaining falls as the pot fills', () {
      expect(
        yearsRemaining(
            priceEuro: 12000, alreadySavedEuro: 0, annualRateEuro: 1200),
        10,
      );
      expect(
        yearsRemaining(
            priceEuro: 12000, alreadySavedEuro: 6000, annualRateEuro: 1200),
        5,
      );
    });

    test('a goal with nothing going into it never arrives', () {
      expect(
        yearsRemaining(
            priceEuro: 12000, alreadySavedEuro: 0, annualRateEuro: 0),
        isNull,
      );
    });

    test('the app can say what income would bring a goal inside five years', () {
      // €12,000 outstanding, 10% set aside, all of it earmarked here.
      final needed = incomeNeededFor(
        priceEuro: 12000,
        alreadySavedEuro: 0,
        fundPercent: 10,
        earmarkPercent: 100,
        targetYears: 5,
      );
      // 12000 / (60 months × 0.10) = €2,000 a month.
      expect(needed, closeTo(2000, 1));
    });

    test('a bigger earmark shortens the wait proportionally', () {
      final quarter = incomeNeededFor(
        priceEuro: 12000,
        alreadySavedEuro: 0,
        fundPercent: 10,
        earmarkPercent: 25,
        targetYears: 5,
      );
      expect(quarter, closeTo(8000, 1));
    });
  });

  group('the streak is the difficulty knob', () {
    test('starting cold is the hardest it gets', () {
      expect(Economy.streakMultiplier(0), 1.0);
      expect(Economy.streakMultiplier(2), 1.0);
    });

    test('sustained daily completion makes progress moderate', () {
      expect(Economy.streakMultiplier(3), greaterThan(1.0));
      expect(Economy.streakMultiplier(7), greaterThan(Economy.streakMultiplier(3)));
      expect(Economy.streakMultiplier(14), greaterThan(Economy.streakMultiplier(7)));
      expect(Economy.streakMultiplier(30), 2.0);
    });

    test('it never runs away — a month is the ceiling', () {
      expect(Economy.streakMultiplier(365), Economy.streakMultiplier(30));
    });

    test('the app can say what the next step is worth reaching', () {
      expect(Economy.nextStreakStep(0), 3);
      expect(Economy.nextStreakStep(5), 7);
      expect(Economy.nextStreakStep(30), isNull);
    });
  });

  group('shards are scarce and cannot be bought', () {
    test('ordinary rungs pay none', () {
      expect(Economy.shardsForTier(1), 0);
      expect(Economy.shardsForTier(3), 0);
      expect(Economy.shardsForTier(7), 0);
    });

    test('milestones pay, and escalate', () {
      expect(Economy.shardsForTier(5), greaterThan(0));
      expect(Economy.shardsForTier(10),
          greaterThan(Economy.shardsForTier(5)));
      expect(Economy.shardsForTier(25),
          greaterThan(Economy.shardsForTier(10)));
    });

    test('a whole season pays far fewer shards than credits', () {
      // Deliberate: shards are the thing money cannot reach.
      var shards = 0;
      for (var t = 1; t <= Economy.seasonTiers; t++) {
        shards += Economy.shardsForTier(t);
      }
      expect(shards, lessThan(1500));
    });

    test('holding a streak is the most productive source', () {
      final streakTotal = Economy.streakShardMilestones.values
          .take(5)
          .fold(0, (a, b) => a + b);
      // Five streak milestones beat twenty tier milestones.
      expect(streakTotal, greaterThan(Economy.shardsForTier(5) * 20));
    });

    test('the wallet tracks lifetime shards separately from the balance', () {
      final w = const Wallet().addShards(50).spendShards(30);
      expect(w.shards, 20);
      expect(w.lifetimeShards, 50);
    });

    test('spending cannot go negative', () {
      final w = const Wallet().addShards(5).spendShards(999);
      expect(w.shards, 0);
      expect(w.canAffordShards(1), isFalse);
    });
  });

  group('capture is acknowledged but never farmable', () {
    test('capture is worth a fraction of doing the thing', () {
      expect(Economy.xpForCapture, lessThan(Economy.xpTrivial));
      expect(Economy.xpForWish, lessThanOrEqualTo(Economy.xpTrivial));
    });

    test('logging noise can never beat real work', () {
      // A hundred captures must still be worth less than one paid session.
      expect(Economy.xpForCapture * 100, lessThan(Economy.xpBigWin));
    });
  });

  group('the peg to real money', () {
    test('one euro is one hundred credits, both ways', () {
      expect(Economy.euroToCoins(5), 500);
      expect(Economy.euroToCoins(12.34), 1234);
      expect(Economy.coinsToEuro(500), 5);
    });

    test('the reserve refuses to cover what it does not hold', () {
      const f = Fund(balanceEuro: 49.99);
      expect(f.covers(49.99), isTrue);
      expect(f.covers(50.00), isFalse);
    });
  });

  group('upkeep and arrears', () {
    test('an obligation converts to a daily burn', () {
      final rent = Obligation(
        id: 'r',
        name: 'RENT',
        amountEuro: 900,
        cadence: ObligationCadence.monthly,
        createdAt: DateTime(2026),
      );
      expect(rent.dailyEuro, closeTo(900 / 30.44, 0.01));
      expect(rent.dailyCredits, closeTo(2956.6, 1));
    });

    test('a negative balance is arrears, and the levy is charged on it', () {
      const up = Upkeep(balanceCredits: -100000);
      expect(up.inArrears, isTrue);
      expect(up.arrearsCredits, 100000);
      // 0.005% a day on a €1000 debt is deliberately near-symbolic.
      expect(up.todaysLevyCredits, closeTo(5, 0.001));
    });

    test('a positive balance owes nothing', () {
      const up = Upkeep(balanceCredits: 5000);
      expect(up.inArrears, isFalse);
      expect(up.todaysLevyCredits, 0);
    });
  });

  group('mastery fills from hours, never from euros', () {
    test('hours accumulate and carry the level', () {
      final t = MasteryTrack(id: 't', name: 'GUITAR', createdAt: DateTime(2026));
      final (after, gained) = t.logHours(5);
      expect(after.totalHours, 5);
      expect(after.level, 2);
      expect(gained, 1);
    });

    test('a long session can carry more than one level', () {
      final t = MasteryTrack(id: 't', name: 'DJ', createdAt: DateTime(2026));
      final (after, gained) = t.logHours(20);
      expect(gained, greaterThan(1));
      expect(after.progress, inInclusiveRange(0.0, 1.0));
    });
  });

  group('streaks', () {
    final base = Profile(createdAt: DateTime(2026));

    test('the first day starts a streak', () {
      final (p, broken) = base.touch(DateTime(2026, 3, 1));
      expect(p.streak, 1);
      expect(broken, isFalse);
    });

    test('a second touch on the same day changes nothing', () {
      final (p, _) = base.touch(DateTime(2026, 3, 1, 9));
      final (p2, _) = p.touch(DateTime(2026, 3, 1, 21));
      expect(p2.streak, 1);
    });

    test('consecutive days extend it', () {
      var (p, _) = base.touch(DateTime(2026, 3, 1));
      (p, _) = p.touch(DateTime(2026, 3, 2));
      (p, _) = p.touch(DateTime(2026, 3, 3));
      expect(p.streak, 3);
      expect(p.bestStreak, 3);
    });

    test('a skipped day breaks it but the best is remembered', () {
      var (p, _) = base.touch(DateTime(2026, 3, 1));
      (p, _) = p.touch(DateTime(2026, 3, 2));
      final (p2, broken) = p.touch(DateTime(2026, 3, 5));
      expect(broken, isTrue);
      expect(p2.streak, 1);
      expect(p2.bestStreak, 2);
    });

    test('a lapsed streak reads as zero before it is recomputed', () {
      final (p, _) = base.touch(DateTime(2026, 3, 1));
      expect(p.streakAsOf(DateTime(2026, 3, 2)), 1);
      expect(p.streakAsOf(DateTime(2026, 3, 9)), 0);
    });
  });
}
