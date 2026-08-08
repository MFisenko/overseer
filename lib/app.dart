import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/firestore_repository.dart';
import 'data/local_repository.dart';
import 'screens/auth/sign_in_screen.dart';
import 'services/auth_service.dart';

import 'screens/companion/overseer_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pass/pass_screen.dart';
import 'screens/quests/quest_log_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/store/store_screen.dart';
import 'screens/vault/vault_screen.dart';
import 'state/game_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'theme/type.dart';
import 'widgets/companion/companion_layer.dart';
import 'widgets/feedback_overlay.dart';
import 'widgets/primitives.dart';

class OverseerApp extends StatelessWidget {
  const OverseerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return MaterialApp(
      title: 'OVERSEER',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      // Both modes are first-class; neither is a tinted afterthought.
      themeMode: game.themeMode,
      home: const _AuthGate(),
    );
  }
}

/// Decides whether to show the door or the app, and swaps the repository to
/// match.
///
/// The whole point of the repository seam is visible here: signing in changes
/// exactly one thing — where the data lives — and nothing above [GameState]
/// has to know it happened.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _auth = AuthService();
  StreamSubscription<User?>? _sub;

  /// Set when the user chose to carry on without an account. Kept in memory
  /// only — next launch they are asked again, which is the gentlest way to
  /// keep offering the account without nagging mid-session.
  bool _skipped = false;

  String? _boundUid;
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    _sub = _auth.changes.listen(_onAuthChanged);
    // authStateChanges fires on subscribe, but only once Firebase is ready;
    // bind whatever is already there so a refresh does not flash the door.
    _onAuthChanged(_auth.currentUser);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(User? user) async {
    final uid = user?.uid;
    if (uid == _boundUid) return;
    _boundUid = uid;

    final game = context.read<GameState>();
    setState(() => _swapping = true);
    // Flush whatever the previous repository was holding before letting go of
    // it, or the last few actions of an anonymous session are lost on sign-in.
    await game.flush();
    await game.switchRepository(
      uid == null ? LocalRepository() : FirestoreRepository(uid: uid),
    );
    if (mounted) setState(() => _swapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    if (_swapping || game.isLoading) {
      return Scaffold(
        body: Center(
          child: Text('OVERSEER', style: Kind.label(context, size: 12)),
        ),
      );
    }

    // No accounts available at all (Firebase not configured) means straight in;
    // the app is fully playable on local storage.
    if (!_auth.isAvailable || _auth.isSignedIn || _skipped) {
      return const RootShell();
    }

    return SignInScreen(
      auth: _auth,
      onSkip: () => setState(() => _skipped = true),
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final Widget Function() build;
  const _Dest(this.label, this.icon, this.build);
}

/// The shell. The overseer floats above every destination — it is a presence
/// watching the app, not a component inside one screen.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static final _destinations = <_Dest>[
    _Dest('TODAY', Icons.bolt_outlined, () => const HomeScreen()),
    // The overseer gets a permanent destination as well as the floating one:
    // the braindump is the fastest way into the app and must not depend on
    // hitting a small draggable target.
    // "MIND" rather than "OVERSEER": it is where you empty your head, and at
    // seven destinations the longer word wraps on a phone.
    _Dest('MIND', Icons.change_history_rounded, () => const OverseerScreen()),
    _Dest('PASS', Icons.military_tech_outlined, () => const PassScreen()),
    _Dest('STORE', Icons.storefront_outlined, () => const StoreScreen()),
    _Dest('VAULT', Icons.lock_clock_outlined, () => const VaultScreen()),
    _Dest('LOG', Icons.checklist_rounded, () => const QuestLogScreen()),
    _Dest('SYSTEM', Icons.tune_rounded, () => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;

    if (game.isLoading) {
      return Scaffold(
        body: Center(
          child: Text('OVERSEER', style: Kind.label(context, size: 12)),
        ),
      );
    }

    return FeedbackOverlay(
      child: CompanionLayer(
        child: Scaffold(
          // One place to cap the measure for every destination, rather than
          // remembering to do it in each screen.
          body: Readable(
            child: IndexedStack(
              index: _index,
              children: [for (final d in _destinations) d.build()],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: tk.canvas,
              border: Border(top: BorderSide(color: tk.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: Readable(
                  child: Row(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: _NavItem(
                            dest: _destinations[i],
                            selected: i == _index,
                            onTap: () => setState(() => _index = i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.dest, required this.selected, required this.onTap});
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = selected ? tk.accent : tk.inkDim;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(dest.icon, size: 19, color: color),
          const SizedBox(height: 5),
          // Nav labels are wide-tracked caps in a fixed-width column; shrink
          // rather than wrap, whatever gets added to the bar later.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Lbl(dest.label, color: color, size: 8.5),
            ),
          ),
        ],
      ),
    );
  }
}
