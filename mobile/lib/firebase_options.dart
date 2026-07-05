import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration, keyed by platform.
///
/// Only the WEB config is filled in for now (we develop on Chrome). When we add
/// the Android app in a later slice, `flutterfire configure` will append the
/// Android options here automatically.
///
/// Note: the web `apiKey` is NOT a secret — it identifies the project to
/// Firebase and is meant to ship in client code. Access is controlled by
/// Firebase Auth + Security Rules, not by hiding this value.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'FirebaseOptions are not configured for this platform yet. '
      'Run `flutterfire configure` when we add Android/iOS.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDbnzdwTsIUdlo-LPl6g1gA83SwtxRr49Y',
    appId: '1:903690367116:web:d8463bc12b087eeafd4ba9',
    messagingSenderId: '903690367116',
    projectId: 'fairshare-3f1b1',
    authDomain: 'fairshare-3f1b1.firebaseapp.com',
    storageBucket: 'fairshare-3f1b1.firebasestorage.app',
  );
}
