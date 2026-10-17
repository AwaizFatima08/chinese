import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/auth_service.dart';
import '../../data/backup.dart';
import '../progress/progress_state.dart';

/// What went wrong, in terms the settings screen can explain to the learner.
enum AccountIssue { none, signInFailed, offline, syncFailed, deleteFailed }

@immutable
class AccountState {
  const AccountState({
    this.user,
    this.busy = false,
    this.lastSynced,
    this.issue = AccountIssue.none,
  });

  final AuthUser? user;

  /// True while signing in, syncing or deleting.
  final bool busy;
  final DateTime? lastSynced;
  final AccountIssue issue;

  bool get signedIn => user != null;

  AccountState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? busy,
    DateTime? lastSynced,
    bool clearLastSynced = false,
    AccountIssue? issue,
  }) => AccountState(
    user: clearUser ? null : (user ?? this.user),
    busy: busy ?? this.busy,
    lastSynced: clearLastSynced ? null : (lastSynced ?? this.lastSynced),
    issue: issue ?? this.issue,
  );
}

/// Optional sign-in and cloud backup. Local data is always the working copy;
/// the cloud copy is merged in and written back, never the other way round.
class AccountController extends Notifier<AccountState> {
  static const _lastSyncedKey = 'cloud.lastSynced';
  static const _debounce = Duration(seconds: 3);

  StreamSubscription<AuthUser?>? _sub;
  Timer? _timer;
  bool _running = false;

  @override
  AccountState build() {
    final auth = ref.watch(authServiceProvider);
    final hooks = ref.read(syncHooksProvider);
    hooks
      ..onProgressSaved = _scheduleSync
      ..onReset = (lang) => unawaited(_afterReset(lang));
    _sub = auth.changes.listen((u) {
      if (u == null) {
        state = state.copyWith(clearUser: true, clearLastSynced: true);
      } else {
        state = state.copyWith(user: u);
      }
    });
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _timer?.cancel();
      hooks
        ..onProgressSaved = null
        ..onReset = null;
    });
    final millis = ref.read(sharedPreferencesProvider).getInt(_lastSyncedKey);
    return AccountState(
      user: auth.currentUser,
      lastSynced: millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  bool get available => ref.read(authServiceProvider).available;

  void _scheduleSync() {
    if (!state.signedIn) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(sync()));
  }

  Future<void> signIn() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, issue: AccountIssue.none);
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      state = state.copyWith(user: user);
    } on AuthException catch (e) {
      state = state.copyWith(
        busy: false,
        issue: switch (e.problem) {
          AuthProblem.cancelled => AccountIssue.none,
          AuthProblem.network => AccountIssue.offline,
          _ => AccountIssue.signInFailed,
        },
      );
      return;
    }
    state = state.copyWith(busy: false);
    await sync();
  }

  Future<void> signOut() async {
    _timer?.cancel();
    await ref.read(authServiceProvider).signOut();
    await ref.read(sharedPreferencesProvider).remove(_lastSyncedKey);
    state = state.copyWith(
      clearUser: true,
      clearLastSynced: true,
      issue: AccountIssue.none,
    );
  }

  /// One full round: read the cloud copy, merge it with this device, keep the
  /// merged result locally and write back whatever the cloud is missing.
  Future<void> sync() async {
    final user = state.user;
    if (user == null || _running) return;
    _running = true;
    state = state.copyWith(busy: true, issue: AccountIssue.none);
    try {
      final repo = ref.read(progressRepositoryProvider);
      final cloud = ref.read(cloudStoreProvider);
      final settings = ref.read(settingsProvider);

      final local = await repo.exportBackup();
      final localWithLevels = ProgressBackup(
        languages: local.languages,
        days: local.days,
        freezes: local.freezes,
        levels: settings.levels,
      );
      final remoteDocs = await cloud.load(user.uid);
      final remote = ProgressBackup.fromDocuments(remoteDocs);
      final merged = ProgressBackup.merge(localWithLevels, remote);

      final mergedDocs = merged.toDocuments();
      if (!mapEquals(mergedDocs, localWithLevels.toDocuments())) {
        await repo.importBackup(merged);
        for (final e in merged.levels.entries) {
          if (settings.levels[e.key] != e.value) {
            await ref.read(settingsProvider.notifier).setLevel(e.key, e.value);
          }
        }
        ref.invalidate(progressProvider);
      }
      final changed = {
        for (final e in mergedDocs.entries)
          if (remoteDocs[e.key] != e.value) e.key: e.value,
      };
      if (changed.isNotEmpty) await cloud.save(user.uid, changed);

      final now = ref.read(clockProvider).now();
      await ref
          .read(sharedPreferencesProvider)
          .setInt(_lastSyncedKey, now.millisecondsSinceEpoch);
      state = state.copyWith(busy: false, lastSynced: now);
    } on Object catch (e, st) {
      debugPrint('Sync failed: $e\n$st');
      state = state.copyWith(busy: false, issue: AccountIssue.syncFailed);
    } finally {
      _running = false;
    }
  }

  /// A reset must also clear the cloud copy, otherwise the next sync would
  /// bring the old progress straight back.
  Future<void> _afterReset(String? language) async {
    final user = state.user;
    if (user == null) return;
    try {
      final cloud = ref.read(cloudStoreProvider);
      if (language == null) {
        await cloud.deleteAll(user.uid);
      } else {
        await cloud.delete(user.uid, 'lang_$language');
      }
    } on Object catch (e) {
      debugPrint('Cloud reset failed: $e');
      state = state.copyWith(issue: AccountIssue.syncFailed);
    }
  }

  /// Removes the cloud copy and the sign-in account. Progress on this device
  /// is left alone.
  Future<bool> deleteAccount() async {
    final user = state.user;
    if (user == null || state.busy) return false;
    _timer?.cancel();
    state = state.copyWith(busy: true, issue: AccountIssue.none);
    final auth = ref.read(authServiceProvider);
    try {
      await ref.read(cloudStoreProvider).deleteAll(user.uid);
      try {
        await auth.deleteAccount();
      } on AuthException catch (e) {
        if (e.problem != AuthProblem.needsRecentLogin) rethrow;
        await auth.reauthenticate();
        await auth.deleteAccount();
      }
      await ref.read(sharedPreferencesProvider).remove(_lastSyncedKey);
      state = state.copyWith(
        busy: false,
        clearUser: true,
        clearLastSynced: true,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        busy: false,
        issue: e.problem == AuthProblem.cancelled
            ? AccountIssue.none
            : AccountIssue.deleteFailed,
      );
    } on Object catch (e) {
      debugPrint('Delete account failed: $e');
      state = state.copyWith(busy: false, issue: AccountIssue.deleteFailed);
    }
    return false;
  }
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);
