import 'package:flutter_test/flutter_test.dart';
import 'package:masir_balini/services/report_calculator.dart';

void main() {
  group('Daily report', () {
    test('registered report calculates score and مطلوب status', () {
      final result = ReportCalculator.daily(
        hasReport: true,
        plannedMinutes: 240,
        actualMinutes: 240,
        plannedPages: 30,
        actualPages: 30,
        plannedTests: 20,
        actualTests: 20,
      );
      expect(result.score, 1);
      expect(result.status, 'مطلوب');
      expect(result.minuteDifference, 0);
    });

    test('blank report remains ثبت نشده', () {
      final result = ReportCalculator.daily(
        hasReport: false,
        plannedMinutes: 240,
        actualMinutes: 0,
        plannedPages: 30,
        actualPages: 0,
        plannedTests: 20,
        actualTests: 0,
      );
      expect(result.status, 'ثبت‌نشده');
    });

    test('checklist separates equivalent days from percentage', () {
      expect(ReportCalculator.checklistPercent(completed: 2, partial: 2, dayCount: 5), .6);
    });
  });
}
