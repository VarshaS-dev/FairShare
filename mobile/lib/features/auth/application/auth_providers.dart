import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// The FirebaseAuth singleton, exposed as a provider so tests can override it.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

/// The single source of truth for "who is signed in" — a stream of `User?`.
/// The router and any screen can `watch` this and react automatically.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});
