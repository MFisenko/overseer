import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
import 'local_repository.dart';
import 'repository.dart';
import 'snapshot.dart';

/// Per-user storage in Firestore, as a single document.
///
/// One account's world is small — a few hundred entries even after years — so
/// it lives in one document rather than a dozen collections. That keeps reads
/// to a single round trip, makes the security rule one line, and means this
/// class mirrors [LocalRepository] almost exactly.
///
/// Writes are debounced and mirrored to local storage as they go, so the app
/// stays fully playable offline and a dropped connection costs nothing.
class FirestoreRepository implements OverseerRepository {
  FirestoreRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    LocalRepository? cache,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        // The local mirror is namespaced by uid so two accounts on one device
        // never see each other's data.
        _cache = cache ?? LocalRepository(namespace: uid);

  final String uid;
  final FirebaseFirestore _db;

  /// Offline mirror. Every write lands here first and synchronously, so the
  /// interface never waits on the network to feel responsive.
  final LocalRepository _cache;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid);

  GameSnapshot? _snap;
  Timer? _flushTimer;
  DateTime? _dirtySince;

  static const _debounce = Duration(milliseconds: 600);
  static const _maxDelay = Duration(seconds: 3);

  @override
  Future<GameSnapshot> load() async {
    // Read the local mirror first so there is something to draw immediately,
    // then reconcile with the server.
    final local = await _cache.load();
    _snap = local;

    try {
      final doc = await _doc.get();
      final data = doc.data();
      if (data != null && data['snapshot'] is Map) {
        _snap = GameSnapshot.fromJson(
            Map<String, dynamic>.from(data['snapshot'] as Map));
        await _writeThroughToCache();
      } else {
        // First sign-in on this account: seed the server from whatever is
        // already on the device, so an anonymous session is not thrown away.
        await _push();
      }
    } catch (e) {
      // Offline, or rules not yet deployed. The local mirror stands; the next
      // successful write reconciles.
      debugPrint('Firestore load failed, using local mirror: $e');
    }
    return _snap!;
  }

  void _mutate(GameSnapshot Function(GameSnapshot) f) {
    _snap = f(_snap ?? GameSnapshot.fresh(cosmetics: buildCosmeticCatalog()));
    _schedule();
  }

  void _schedule() {
    final since = _dirtySince ??= DateTime.now();
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
    await _writeThroughToCache();
    await _push();
  }

  /// Mirrors the current snapshot into local storage. Never fails the caller —
  /// a cache write problem must not cost the user their progress in memory.
  Future<void> _writeThroughToCache() async {
    final snap = _snap;
    if (snap == null) return;
    try {
      await _cache.replace(snap);
    } catch (e) {
      debugPrint('local mirror write failed: $e');
    }
  }

  Future<void> _push() async {
    final snap = _snap;
    if (snap == null) return;
    try {
      await _doc.set({
        'snapshot': snap.toJson(),
        'updated_at': FieldValue.serverTimestamp(),
        'schema': 1,
      }, SetOptions(merge: true));
    } catch (e) {
      // Offline writes are queued by Firestore's own persistence on mobile and
      // dropped on web; either way the local mirror is authoritative until the
      // next successful push.
      debugPrint('Firestore push failed: $e');
    }
  }

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
    _snap = GameSnapshot.fresh(cosmetics: buildCosmeticCatalog());
    await _cache.wipe();
    try {
      await _doc.delete();
    } catch (e) {
      debugPrint('Firestore wipe failed: $e');
    }
  }
}
