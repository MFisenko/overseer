import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Accounts, behind one class.
///
/// Deliberately thin: the app only needs to know who the user is so their data
/// can be scoped to them. Everything else — the game, the ladder, the overseer
/// — is indifferent to how they signed in.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? _tryInstance();

  final FirebaseAuth? _auth;

  /// Firebase may not be configured on this platform. Resolving lazily and
  /// tolerating failure keeps the app usable offline and un-signed-in rather
  /// than blocking at the door.
  static FirebaseAuth? _tryInstance() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('Auth unavailable: $e');
      return null;
    }
  }

  bool get isAvailable => _auth != null;

  User? get currentUser => _auth?.currentUser;
  String? get uid => currentUser?.uid;
  bool get isSignedIn => currentUser != null;

  /// Fires on sign-in, sign-out and token refresh. The app swaps its repository
  /// in response, which is the only thing that has to change.
  Stream<User?> get changes =>
      _auth?.authStateChanges() ?? const Stream<User?>.empty();

  Future<String?> signIn(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Accounts are unavailable right now.';
    try {
      await auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _readable(e);
    } catch (e) {
      return 'Could not sign in. $e';
    }
  }

  Future<String?> register(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Accounts are unavailable right now.';
    try {
      await auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _readable(e);
    } catch (e) {
      return 'Could not create the account. $e';
    }
  }

  Future<String?> sendReset(String email) async {
    final auth = _auth;
    if (auth == null) return 'Accounts are unavailable right now.';
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _readable(e);
    }
  }

  Future<void> signOut() async => _auth?.signOut();

  /// Firebase's own messages are written for developers. These are written for
  /// someone who just wants to get in.
  static String _readable(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That does not look like an email address.',
        'user-disabled' => 'That account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Wrong email or password.',
        'email-already-in-use' =>
          'There is already an account with that email. Sign in instead.',
        'weak-password' => 'Use at least six characters.',
        'network-request-failed' =>
          'No connection. The app still works offline — sign in later.',
        'too-many-requests' => 'Too many attempts. Wait a moment.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled on this project yet.',
        _ => e.message ?? 'Something went wrong signing in.',
      };
}
