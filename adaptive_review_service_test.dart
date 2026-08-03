import 'package:flutter_test/flutter_test.dart';
import 'package:masir_balini/services/adaptive_review_service.dart';

void main() {
  final date = DateTime(2026, 8, 11);

  test('wrong answer schedules one day later', () {
    final result = AdaptiveReviewService.calculate(
      reviewDate: date,
      quality: 'غلط یا کمتر از ۵۰٪',
      previousInterval: 7,
      previousFullSuccessCount: 2,
    );
    expect(result.nextDate, DateTime(2026, 8, 12));
    expect(result.fullSuccessCount, 0);
  });

  test('third full success moves to 14 days', () {
    final result = AdaptiveReviewService.calculate(
      reviewDate: date,
      quality: 'درست، سریع و کامل',
      previousInterval: 7,
      previousFullSuccessCount: 2,
    );
    expect(result.nextInterval, 14);
    expect(result.fullSuccessCount, 3);
  });

  test('long interval moves to 28 days', () {
    final result = AdaptiveReviewService.calculate(
      reviewDate: date,
      quality: 'درست، سریع و کامل',
      previousInterval: 14,
      previousFullSuccessCount: 2,
    );
    expect(result.nextInterval, 28);
  });
}
