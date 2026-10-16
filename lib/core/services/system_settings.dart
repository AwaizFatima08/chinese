import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

/// Opens the phone's text-to-speech settings, where voice data can be
/// installed. Falls back to the main Settings app.
Future<void> openVoiceSettings() async {
  for (final action in const [
    'com.android.settings.TTS_SETTINGS',
    'android.settings.SETTINGS',
  ]) {
    try {
      await AndroidIntent(action: action).launch();
      return;
    } on Object catch (e) {
      debugPrint('Could not open $action: $e');
    }
  }
}
