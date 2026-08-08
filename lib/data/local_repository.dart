import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
import 'cosmetic_catalog.dart';
import 'repository.dart';
import 'snapshot.dart';

/// On-device storage. Holds the whole snapshot as one JSON blob and flushes it
/// on a short debounce, because the core loop fires many small writes in a row
/// (complete a task → XP → level → coins → streak) and each one should not
/// touch the disk.
///
/// This is the repository used before sign-in and whenever the network is gone,
/// so the app is playable on a plane.
class LocalRepository implements OverseerRepository {
  LocalRepository({this.namespace = 'default'});

  /// Lets a signed-in user's local cache sit beside the anonymous one.
  final String namespace;

  String get _key => 'overseer.snapshot.$namespace';

  GameSnapshot? _cache;
  Timer? _flushTimer;

  /// When the oldest unflushed write happened. The debounce is reset on every
  /// write, so without a ceiling a steady stream of them — completing several
  /// directives in a row, or the demo seeder — could postpone the flush
  /// indefinitely and lose everything if the page went away.
  DateTime? _dirtySince;
  static const _debounce = Duration(milliseconds: 400);
  static const _maxDelay = Duration(milliseconds: 1500);

  @override
  Future<GameSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = GameSnapshot.fresh(cosmetics: buildCosmeticCatalog());
      return _cache!;
    }
    try {
      _cache = GameSnapshot.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // A corrupt blob must never brick the app — start clean rather than
      // crash on launch.
      _cache = GameSnapshot.fresh(cosmetics: buildCosmeticCatalog());
    }
    return _cache!;
  }

  /// Replaces the whole cached world. Used by [FirestoreRepository] to mirror
  /// server state down, so the device always has a complete offline copy.
  Future<void> replace(GameSnapshot snap) async {
    _cache = snap;
    await flush();
  }

  void _mutate(GameSnapshot Function(GameSnapshot) f) {
    _cache = f(_cache ?? GameSnapshot.fresh(cosmetics: buildCosmeticCatalog()));
    _scheduleFlush();
  }

  void _scheduleFlush() {
    final since = _dirtySince ??= DateTime.now();
    // Coalesce bursts, but never let the ceiling slip.
    final elapsed = DateTime.now().difference(since);
    if (elapsed >= _maxDelay) {
      unawaited(flush());
      return;
    }
    final remaining = _maxDelay - elapsed;
    _flushTimer?.cancel();
    _flushTimer =
        Timer(_debounce < remaining ? _debounce : remaining, () => flush());
  }

  @override
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _dirtySince = null;
    final snap = _cache;
    if (snap == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snap.toJson()));
  }

  /// Replaces one item in a list by id, appending when it is new.
  static List<T> _upsert<T>(List<T> items, T item, String Function(T) id) {
    final i = items.indexWhere((e) => id(e) == id(item));
    if (i < 0) return [...items, item];
    final next = [...items];
    next[i] = item;
    return next;
  }

  @override
  Future<void> saveProfile(Profile p) async => _mutate((s) => s.copyWith(profile: p));

  @override
  Future<void> saveWallet(Wallet w) async => _mutate((s) => s.copyWith(wallet: w));

  @override
  Future<void> saveFund(Fund f) async => _mutate((s) => s.copyWith(fund: f));

  @override
  Future<void> saveUpkeep(Upkeep u) async => _mutate((s) => s.copyWith(upkeep: u));

  @override
  Future<void> saveCalibration(Calibration c) async =>
      _mutate((s) => s.copyWith(calibration: c));

  @override
  Future<void> saveCompanion(CompanionState c) async =>
      _mutate((s) => s.copyWith(companion: c));

  @override
  Future<void> saveTaste(TasteProfile t) async => _mutate((s) => s.copyWith(taste: t));

  @override
  Future<void> saveSeason(Season season) async => _mutate((s) =>
      season.type == PassType.lifetime
          ? s.copyWith(lifetime: season)
          : s.copyWith(season: season));

  @override
  Future<void> upsertQuest(Quest q) async =>
      _mutate((s) => s.copyWith(quests: _upsert(s.quests, q, (e) => e.id)));

  @override
  Future<void> deleteQuest(String id) async => _mutate(
      (s) => s.copyWith(quests: s.quests.where((e) => e.id != id).toList()));

  @override
  Future<void> upsertReward(Reward r) async =>
      _mutate((s) => s.copyWith(rewards: _upsert(s.rewards, r, (e) => e.id)));

  @override
  Future<void> deleteReward(String id) async => _mutate(
      (s) => s.copyWith(rewards: s.rewards.where((e) => e.id != id).toList()));

  @override
  Future<void> upsertBucket(Bucket b) async =>
      _mutate((s) => s.copyWith(buckets: _upsert(s.buckets, b, (e) => e.id)));

  @override
  Future<void> deleteBucket(String id) async => _mutate(
      (s) => s.copyWith(buckets: s.buckets.where((e) => e.id != id).toList()));

  @override
  Future<void> upsertObligation(Obligation o) async => _mutate(
      (s) => s.copyWith(obligations: _upsert(s.obligations, o, (e) => e.id)));

  @override
  Future<void> deleteObligation(String id) async => _mutate((s) =>
      s.copyWith(obligations: s.obligations.where((e) => e.id != id).toList()));

  @override
  Future<void> upsertTrack(MasteryTrack t) async =>
      _mutate((s) => s.copyWith(tracks: _upsert(s.tracks, t, (e) => e.id)));

  @override
  Future<void> deleteTrack(String id) async => _mutate((s) => s.copyWith(
        tracks: s.tracks.where((e) => e.id != id).toList(),
        hourLogs: s.hourLogs.where((e) => e.trackId != id).toList(),
      ));

  @override
  Future<void> insertHourLog(HourLog log) async =>
      _mutate((s) => s.copyWith(hourLogs: [log, ...s.hourLogs]));

  @override
  Future<void> upsertCosmetic(Cosmetic c) async =>
      _mutate((s) => s.copyWith(cosmetics: _upsert(s.cosmetics, c, (e) => e.id)));

  @override
  Future<void> insertIncome(IncomeEntry e) async =>
      _mutate((s) => s.copyWith(income: [e, ...s.income]));

  @override
  Future<void> insertStatement(StatementEntry e) async => _mutate((s) =>
      s.copyWith(statements: [
        e,
        ...s.statements.where((x) => x.month != e.month),
      ]));

  @override
  Future<void> wipe() async {
    _flushTimer?.cancel();
    _cache = GameSnapshot.fresh(cosmetics: buildCosmeticCatalog());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
