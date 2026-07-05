import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/home_shell.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/profile/presentation/account_screen.dart';

/// The router is a provider so it can react to auth state.
///
/// `redirect` is the ROUTE GUARD: it runs on every navigation and returns a
/// path to send the user to (or null to stay put). We re-run it whenever auth
/// changes via `refreshListenable`, so signing in/out moves the user
/// automatically — the screens never call navigation after login.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(authRepo.watchAuthState());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/groups',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = authRepo.currentUser != null;
      final atAuthScreen = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      if (!loggedIn) return atAuthScreen ? null : '/sign-in';
      if (atAuthScreen) return '/groups';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/groups', builder: (c, s) => const GroupsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/activity', builder: (c, s) => const ActivityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/sign-in', builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (c, s) => const SignUpScreen()),
    ],
  );
});

/// Bridges a Stream to a Listenable so GoRouter re-runs `redirect` whenever the
/// stream emits (here: whenever the auth state changes).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
