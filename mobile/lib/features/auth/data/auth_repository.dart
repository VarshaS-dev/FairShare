import 'package:firebase_auth/firebase_auth.dart';

/// The data-layer wrapper around FirebaseAuth.
///
/// Everything above this (providers, controllers, screens) talks to THIS, never
/// to FirebaseAuth directly. That keeps Firebase a swappable implementation
/// detail and gives us one place to shape auth behavior.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Emits the current user on sign-in/out AND on profile changes (e.g. after
  /// we set a display name). Using `userChanges` (rather than
  /// `authStateChanges`) is what makes a freshly-set name appear immediately.
  Stream<User?> watchAuthState() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.reload(); // push the new name into `userChanges`
  }

  /// Web uses Firebase's popup flow. Android will use a native flow once its
  /// app is configured (a later slice).
  Future<void> signInWithGoogle() {
    return _auth.signInWithPopup(GoogleAuthProvider());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
