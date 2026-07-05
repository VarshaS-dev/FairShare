import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Flutter must be initialized before we do async work prior to runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to our Firebase project. All auth depends on this, so we await it.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: FairShareApp()));
}
