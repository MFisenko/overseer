import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'data/local_repository.dart';
import 'state/game_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The interface is near-black everywhere; the system bars should disappear
  // into it rather than frame it.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  // Firebase powers the AI paths only — pricing, image reading, braindump
  // triage and the companion's voice. Everything else works without it, so a
  // failure here is logged and stepped over rather than allowed to block start.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // App Check proves a request came from this app rather than from anyone
    // who read the API key out of the published bundle. Firebase AI Logic
    // rejects unattested calls outright, so without this every Gemini path
    // returns 401 — and without it the key would be free quota for strangers.
    //
    // The reCAPTCHA Enterprise key is domain-locked to the deployed origin and
    // localhost; it is a public site key, not a secret.
    await FirebaseAppCheck.instance.activate(
      webProvider:
          ReCaptchaEnterpriseProvider('6LfNtXstAAAAANAzEkdZc0PCsl606z4fYFgx1eLg'),
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint('Firebase unavailable, AI paths will stay dormant: $e');
  }

  // Local storage until sign-in lands; the repository seam makes that swap a
  // one-liner rather than a rewrite.
  final game = GameState(LocalRepository());
  unawaited(game.load());

  // Writes are debounced, so anything still buffered when the app goes away
  // has to be forced out. On web this covers a tab close or a reload; on
  // mobile, a swipe to the background.
  AppLifecycleListener(
    onInactive: () => unawaited(game.flush()),
    onHide: () => unawaited(game.flush()),
    onDetach: () => unawaited(game.flush()),
  );

  runApp(
    ChangeNotifierProvider.value(value: game, child: const OverseerApp()),
  );
}
