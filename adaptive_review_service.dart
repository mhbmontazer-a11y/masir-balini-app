class ReviewDecision {
  const ReviewDecision({required this.nextDate, required this.nextInterval, required this.fullSuccessCount});
  final DateTime nextDate;
  final int nextInterval;
  final int fullSuccessCount;
}

class AdaptiveReviewService {
  static ReviewDecision calculate({
    required DateTime reviewDate,
    required String quality,
    required int previousInterval,
    required int previousFullSuccessCount,
  }) {
    var interval = 1;
    var count = 0;
    switch (quality) {
      case 'غلط یا کمتر از ۵۰٪':
        interval = 1;
        break;
      case 'ناقص یا همراه با حدس':
        interval = 2;
        break;
      case 'درست ولی کند و مردد':
        interval = 4;
        break;
      case 'درست، سریع و کامل':
        count = previousFullSuccessCount + 1;
        if (previousFullSuccessCount >= 2) {
          interval = previousInterval < 14 ? 14 : 28;
        } else {
          interval = (previousInterval * 2).clamp(3, 28).toInt();
        }
        break;
      default:
        throw ArgumentError.value(quality, 'quality', 'کیفیت بازیابی نامعتبر است');
    }
    return ReviewDecision(
      nextDate: DateTime(reviewDate.year, reviewDate.month, reviewDate.day).add(Duration(days: interval)),
      nextInterval: interval,
      fullSuccessCount: count,
    );
  }

  static String dueStatus({required DateTime? scheduled, required DateTime today, required bool finalConsolidation}) {
    if (finalConsolidation) return 'انتقال به تثبیت نهایی';
    if (scheduled == null) return 'فاقد داده';
    final target = DateTime(scheduled.year, scheduled.month, scheduled.day);
    final base = DateTime(today.year, today.month, today.day);
    if (target.isBefore(base)) return 'عقب‌افتاده';
    if (target == base) return 'سررسید امروز';
    return 'آینده';
  }
}
