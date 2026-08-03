class DailyCalculation {
  const DailyCalculation({
    required this.timeRatio,
    required this.pageRatio,
    required this.testRatio,
    required this.score,
    required this.minuteDifference,
    required this.status,
  });

  final double? timeRatio;
  final double? pageRatio;
  final double? testRatio;
  final double? score;
  final int? minuteDifference;
  final String status;
}

class ReportCalculator {
  static DailyCalculation daily({
    required bool hasReport,
    required int plannedMinutes,
    required int? actualMinutes,
    required int plannedPages,
    required int? actualPages,
    required int plannedTests,
    required int? actualTests,
  }) {
    final time = actualMinutes == null || plannedMinutes == 0
        ? null
        : actualMinutes / plannedMinutes;
    final pages = actualPages == null || plannedPages == 0
        ? null
        : actualPages / plannedPages;
    final tests = actualTests == null || plannedTests == 0
        ? null
        : actualTests / plannedTests;
    final available = [time, pages, tests].whereType<double>().toList();
    final score = available.isEmpty
        ? null
        : available.reduce((a, b) => a + b) / available.length;
    final difference = actualMinutes == null ? null : actualMinutes - plannedMinutes;
    final status = !hasReport
        ? 'ثبت‌نشده'
        : (score ?? 0) >= .90
            ? 'مطلوب'
            : (score ?? 0) >= .60
                ? 'نسبی'
                : 'نیازمند جبران';
    return DailyCalculation(
      timeRatio: time,
      pageRatio: pages,
      testRatio: tests,
      score: score,
      minuteDifference: difference,
      status: status,
    );
  }

  static double checklistPercent({
    required int completed,
    required int partial,
    required int dayCount,
  }) {
    if (dayCount == 0) return 0;
    return (completed + partial * .5) / dayCount;
  }

  static double weeklyComposite(Iterable<double?> values) {
    final available = values.whereType<double>().toList();
    if (available.isEmpty) return 0;
    return available.reduce((a, b) => a + b) / available.length;
  }

  static String weeklySummary({required int daysWithReport, required double score}) {
    if (daysWithReport == 0) return 'هنوز گزارش روزانه‌ای ثبت نشده است.';
    if (score >= .90) return 'عملکرد هفتگی بسیار مطلوب';
    if (score >= .75) return 'عملکرد مطلوب؛ جبران جزئی کافی است';
    if (score >= .55) return 'عملکرد متوسط؛ جبران هدفمند لازم است';
    return 'عملکرد ضعیف؛ بازطراحی هفتهٔ بعد ضروری است';
  }
}
