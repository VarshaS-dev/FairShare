/// Money helpers.
///
/// Amounts travel to/from the API as integer MINOR units (paise/cents) and are
/// only ever turned into a decimal for *display*. We parse and format using
/// integer arithmetic (no floating point) so ₹100.50 is exactly 10050 — never
/// 10049.9999. All our supported currencies use 2 decimal places.
class Money {
  Money._();

  static const int _fractionDigits = 2;

  /// Parse a user-typed amount ("100", "100.5", "100.50") into minor units.
  /// Returns null if it isn't a valid positive amount with <= 2 decimals.
  static int? parseToMinor(String input) {
    final s = input.trim().replaceAll(',', '');
    if (s.isEmpty || !RegExp(r'^\d*\.?\d*$').hasMatch(s)) return null;

    final parts = s.split('.');
    if (parts.length > 2) return null;

    final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    var frac = parts.length == 2 ? parts[1] : '';
    if (frac.length > _fractionDigits) return null;
    frac = frac.padRight(_fractionDigits, '0');
    final fracVal = frac.isEmpty ? 0 : int.parse(frac);

    final minor = whole * 100 + fracVal;
    return minor > 0 ? minor : null;
  }

  /// Format minor units (10050) as a plain decimal string ("100.50").
  static String formatMinor(int minor) {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(_fractionDigits, '0');
    return '$sign$whole.$frac';
  }

  /// e.g. "INR 100.50".
  static String formatWithCurrency(int minor, String currency) =>
      '$currency ${formatMinor(minor)}';
}
