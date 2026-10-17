import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The signed-in learner. Only these three fields are ever read.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.email, this.name});

  final String uid;
  final String? email;
  final String? name;
}

/// Why a sign-in or account action did not complete.
enum AuthProblem { cancelled, network, needsRecentLogin, unavailable, other }

class AuthException implements Exception {
  const AuthException(this.problem);

  final AuthProblem problem;

  @override
  String toString() => 'AuthException($problem)';
}

/// Optional Google sign-in. The app is fully usable without it.
abstract interface class AuthService {
  /// False when Firebase is not configured or not reachable on this device.
  bool get available;

  AuthUser? get currentUser;

  /// Emits the current user first, then every change.
  Stream<AuthUser?> get changes;

  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();

  /// Signs in again so a sensitive action is allowed.
  Future<void> reauthenticate();

  /// Deletes the sign-in account itself. Cloud data must be removed first.
  Future<void> deleteAccount();
}

/// Used when Firebase is missing: the account section is hidden.
class NoAuthService implements AuthService {
  const NoAuthService();

  @override
  bool get available => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get changes => Stream.value(null);

  @override
  Future<AuthUser> signInWithGoogle() =>
      throw const AuthException(AuthProblem.unavailable);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> reauthenticate() =>
      throw const AuthException(AuthProblem.unavailable);

  @override
  Future<void> deleteAccount() =>
      throw const AuthException(AuthProblem.unavailable);
}

/// [AuthService] on Firebase Authentication with Google sign-in.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({required this.serverClientId});

  /// The web client id of the Firebase project (needed for the ID token).
  final String serverClientId;

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= GoogleSignIn.instance.initialize(
    serverClientId: serverClientId,
  );

  static AuthUser? _map(fb.User? u) => u == null
      ? null
      : AuthUser(uid: u.uid, email: u.email, name: u.displayName);

  @override
  bool get available => true;

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get changes async* {
    yield currentUser;
    yield* _auth.userChanges().map(_map);
  }

  Future<fb.AuthCredential> _googleCredential() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthException(AuthProblem.other);
      return fb.GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled ||
                e.code == GoogleSignInExceptionCode.interrupted
            ? AuthProblem.cancelled
            : AuthProblem.other,
      );
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final credential = await _googleCredential();
    try {
      final result = await _auth.signInWithCredential(credential);
      return _map(result.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } on Object catch (_) {
      // Signing out of Firebase is what matters.
    }
  }

  @override
  Future<void> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthProblem.other);
    final credential = await _googleCredential();
    try {
      await user.reauthenticateWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } on Object catch (_) {}
  }

  AuthException _translate(fb.FirebaseAuthException e) =>
      AuthException(switch (e.code) {
        'requires-recent-login' => AuthProblem.needsRecentLogin,
        'network-request-failed' => AuthProblem.network,
        _ => AuthProblem.other,
      });
}
