import '../models/calibration.dart';
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
import 'snapshot.dart';

/// The only seam between the game and where its data lives.
///
/// Nothing above this line knows whether rows are in Postgres or on disk, and
/// no Supabase type is ever allowed to leak past it into the UI. Two
/// implementations exist: one on shared_preferences for offline and first-run,
/// one on Supabase for the real, per-user, row-level-secured article.
abstract class OverseerRepository {
  /// Reads the user's whole world. Returns a fresh snapshot for a new account.
  Future<GameSnapshot> load();

  Future<void> saveProfile(Profile profile);
  Future<void> saveWallet(Wallet wallet);
  Future<void> saveFund(Fund fund);
  Future<void> saveUpkeep(Upkeep upkeep);
  Future<void> saveCalibration(Calibration calibration);
  Future<void> saveCompanion(CompanionState companion);
  Future<void> saveTaste(TasteProfile taste);
  Future<void> saveSeason(Season season);

  Future<void> upsertQuest(Quest quest);
  Future<void> deleteQuest(String id);

  Future<void> upsertReward(Reward reward);
  Future<void> deleteReward(String id);

  Future<void> upsertBucket(Bucket bucket);
  Future<void> deleteBucket(String id);

  Future<void> upsertObligation(Obligation obligation);
  Future<void> deleteObligation(String id);

  Future<void> upsertTrack(MasteryTrack track);
  Future<void> deleteTrack(String id);
  Future<void> insertHourLog(HourLog log);

  Future<void> upsertCosmetic(Cosmetic cosmetic);
  Future<void> insertIncome(IncomeEntry entry);
  Future<void> insertStatement(StatementEntry entry);

  /// Wipes this user's data. Used by "reset account" in settings, never
  /// implicitly.
  Future<void> wipe();

  /// Forces any buffered writes out immediately.
  ///
  /// Called when the app is backgrounded or closing. Implementations that write
  /// synchronously have nothing to do here.
  Future<void> flush() async {}
}
