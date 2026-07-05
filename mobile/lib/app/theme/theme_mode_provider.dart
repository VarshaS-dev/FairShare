import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the app's current [ThemeMode] (system / light / dark).
///
/// This is our first real taste of Riverpod's state layer. A [Notifier] is a
/// small class that OWNS a piece of state and exposes methods to change it:
///   - `build()` returns the initial value.
///   - assigning to `state` notifies every widget watching this provider.
/// The UI reads it with `ref.watch(themeModeProvider)` (and rebuilds on change)
/// and mutates it with `ref.read(themeModeProvider.notifier).set(...)`.
///
/// We deliberately introduce Riverpod on something trivial and visible. In
/// Slice 1 we reuse this exact pattern for the far more important auth session.
///
/// (Later we'll persist this choice to disk so it survives an app restart —
/// an example of "refine as we evolve" rather than over-building now.)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void set(ThemeMode mode) => state = mode;
}

/// The global handle widgets use to reach the notifier above.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
