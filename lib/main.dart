import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/services/ad_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/cloud_store.dart';
import 'core/services/firebase_setup.dart';
import 'data/app_database.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exceptionAsString()}');
      };
      final prefs = await SharedPreferences.getInstance();
      final database = await AppDatabase.open();
      final firebaseReady = await initFirebase();
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(database),
            adServiceProvider.overrideWithValue(AdMobService()),
            if (firebaseReady) ...[
              authServiceProvider.overrideWithValue(
                FirebaseAuthService(serverClientId: firebaseWebClientId),
              ),
              cloudStoreProvider.overrideWithValue(FirestoreCloudStore()),
            ],
          ],
          child: const LingoDailyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught: $error\n$stack');
    },
  );
}
