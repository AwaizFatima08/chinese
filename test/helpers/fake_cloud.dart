import 'dart:async';

import 'package:lingodaily/core/services/auth_service.dart';
import 'package:lingodaily/core/services/cloud_store.dart';

/// In-memory cloud shared between "devices" in a test.
class FakeCloud implements CloudStore {
  final Map<String, Map<String, String>> data = {};
  bool failing = false;

  void _check() {
    if (failing) throw StateError('offline');
  }

  @override
  Future<Map<String, String>> load(String uid) async {
    _check();
    return {...?data[uid]};
  }

  @override
  Future<void> save(String uid, Map<String, String> documents) async {
    _check();
    data.putIfAbsent(uid, () => {}).addAll(documents);
  }

  @override
  Future<void> delete(String uid, String documentId) async {
    _check();
    data[uid]?.remove(documentId);
  }

  @override
  Future<void> deleteAll(String uid) async {
    _check();
    data.remove(uid);
  }
}

/// Auth that signs in as a fixed user without any network.
class FakeAuth implements AuthService {
  FakeAuth({this.user = const AuthUser(uid: 'u1', email: 'a@b.c')});

  final AuthUser user;
  AuthUser? _current;
  final _changes = StreamController<AuthUser?>.broadcast();

  /// Throw [AuthProblem.needsRecentLogin] on the first account deletion.
  bool needsRecentLoginOnce = false;
  bool cancelNextSignIn = false;
  int reauthCalls = 0;

  @override
  bool get available => true;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get changes => _changes.stream;

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (cancelNextSignIn) {
      cancelNextSignIn = false;
      throw const AuthException(AuthProblem.cancelled);
    }
    _current = user;
    _changes.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  @override
  Future<void> reauthenticate() async => reauthCalls++;

  @override
  Future<void> deleteAccount() async {
    if (needsRecentLoginOnce && reauthCalls == 0) {
      throw const AuthException(AuthProblem.needsRecentLogin);
    }
    _current = null;
    _changes.add(null);
  }
}
