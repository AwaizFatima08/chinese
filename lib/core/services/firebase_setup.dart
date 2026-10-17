import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Web client id of the Lingo15 Firebase project. Google sign-in needs it to
/// obtain an ID token. It identifies the project and is not a secret.
const firebaseWebClientId =
    '1045378404555-09mbub9cfo7f1ul0a1s6ivvpqgrvsmec.apps.googleusercontent.com';

/// Starts Firebase from the platform config (`google-services.json`).
/// Returns false when it is missing or fails, so the app simply runs without
/// the optional account features.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    return true;
  } on Object catch (e) {
    debugPrint('Firebase unavailable: $e');
    return false;
  }
}
