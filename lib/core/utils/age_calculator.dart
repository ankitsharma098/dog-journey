/// Turns a birthdate into the human label used anywhere a pet's age is
/// shown — Pet Profile, and later the vaccine schedule (HP-1/HP-2) and
/// Timeline milestones, all key off the same age math, so it lives here
/// once instead of each feature computing it.
abstract final class AgeCalculator {
  /// [isEstimate] softens the language per the PRD's edge case for an
  /// unknown birthdate ("around 2 years old" rather than a flat claim).
  static String label(DateTime birthdate, {bool isEstimate = false, DateTime? now}) {
    final today = now ?? DateTime.now();
    final days = today.difference(birthdate).inDays;
    if (days < 0) return isEstimate ? 'Age unknown' : 'Not born yet';

    final prefix = isEstimate ? 'Around ' : '';

    if (days < 60) {
      final weeks = (days / 7).floor();
      return '$prefix$weeks week${weeks == 1 ? '' : 's'} old';
    }
    if (days < 365) {
      final months = (days / 30.44).floor();
      return '$prefix$months month${months == 1 ? '' : 's'} old';
    }
    final years = (days / 365.25).floor();
    final remMonths = ((days - years * 365.25) / 30.44).floor();
    if (remMonths == 0) {
      return '$prefix$years year${years == 1 ? '' : 's'} old';
    }
    return '$prefix$years yr${years == 1 ? '' : 's'} $remMonths mo';
  }

  static int ageInDays(DateTime birthdate, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(birthdate).inDays;
}
