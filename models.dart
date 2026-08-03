class PlanPart {
  PlanPart({
    required this.id,
    required this.dayId,
    required this.partNumber,
    required this.subject,
    required this.description,
    required this.unitCodes,
    required this.plannedMinutes,
    required this.plannedPages,
    required this.plannedTests,
    required this.status,
    required this.actualMinutes,
    required this.actualPages,
    required this.actualTests,
    required this.note,
  });

  final int id;
  final int dayId;
  final int partNumber;
  final String subject;
  final String description;
  final String unitCodes;
  final int plannedMinutes;
  final int plannedPages;
  final int plannedTests;
  final String status;
  final int actualMinutes;
  final int actualPages;
  final int actualTests;
  final String note;

  factory PlanPart.fromMap(Map<String, Object?> m) => PlanPart(
        id: m['id'] as int,
        dayId: m['day_id'] as int,
        partNumber: m['part_number'] as int,
        subject: (m['subject'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        unitCodes: (m['unit_codes'] ?? '') as String,
        plannedMinutes: (m['planned_minutes'] ?? 0) as int,
        plannedPages: (m['planned_pages'] ?? 0) as int,
        plannedTests: (m['planned_tests'] ?? 0) as int,
        status: (m['status'] ?? 'not_started') as String,
        actualMinutes: (m['actual_minutes'] ?? 0) as int,
        actualPages: (m['actual_pages'] ?? 0) as int,
        actualTests: (m['actual_tests'] ?? 0) as int,
        note: (m['note'] ?? '') as String,
      );
}

class PlanDay {
  PlanDay({
    required this.id,
    required this.date,
    required this.jalaliDate,
    required this.weekday,
    required this.dayNumber,
    required this.weekNumber,
    required this.plannedMinutes,
    required this.plannedPages,
    required this.plannedTests,
    required this.checklistStatus,
    required this.checklistScore,
    required this.auditStatus,
    required this.isFriday,
    required this.parts,
  });

  final int id;
  final String date;
  final String jalaliDate;
  final String weekday;
  final int dayNumber;
  final int weekNumber;
  final int plannedMinutes;
  final int plannedPages;
  final int plannedTests;
  final String checklistStatus;
  final double checklistScore;
  final String auditStatus;
  final bool isFriday;
  final List<PlanPart> parts;

  factory PlanDay.fromMap(Map<String, Object?> m, List<PlanPart> parts) => PlanDay(
        id: m['id'] as int,
        date: m['gregorian_date'] as String,
        jalaliDate: m['jalali_date'] as String,
        weekday: m['weekday'] as String,
        dayNumber: m['day_number'] as int,
        weekNumber: m['week_number'] as int,
        plannedMinutes: m['planned_minutes'] as int,
        plannedPages: m['planned_pages'] as int,
        plannedTests: m['planned_tests'] as int,
        checklistStatus: m['checklist_status'] as String,
        checklistScore: (m['checklist_score'] as num).toDouble(),
        auditStatus: m['audit_status'] as String,
        isFriday: (m['is_friday'] as int) == 1,
        parts: parts,
      );
}

class DailyReport {
  DailyReport({required this.values});
  final Map<String, Object?> values;
  int get dayId => values['day_id'] as int;
  bool get hasReport => (values['has_report'] as int? ?? 0) == 1;
  int get plannedMinutes => values['planned_minutes'] as int? ?? 0;
  int get actualMinutes => values['actual_minutes'] as int? ?? 0;
  int get plannedPages => values['planned_pages'] as int? ?? 0;
  int get actualPages => values['actual_pages'] as int? ?? 0;
  int get plannedTests => values['planned_tests'] as int? ?? 0;
  int get actualTests => values['actual_tests'] as int? ?? 0;
  double? get score => (values['daily_score'] as num?)?.toDouble();
  String get status => values['report_status'] as String? ?? 'ثبت‌نشده';
}

class ReviewItem {
  ReviewItem({required this.values});
  final Map<String, Object?> values;
  int get id => values['id'] as int;
  String get unitCode => values['unit_code'] as String;
  String get subject => values['subject'] as String;
  String get chapterTitle => values['chapter_title'] as String;
  String get pageRange => values['page_range'] as String;
  String? get scheduledDate => values['scheduled_date'] as String?;
  String get dueStatus => values['due_status'] as String? ?? 'فاقد داده';
  int get previousInterval => values['previous_interval_days'] as int? ?? 1;
  int get fullSuccessCount => values['full_success_count'] as int? ?? 0;
}

class WeeklySummary {
  WeeklySummary({required this.values});
  final Map<String, Object?> values;
  int get weekNumber => values['week_number'] as int;
  String get dateRange => values['date_range'] as String? ?? '';
  int get plannedMinutes => values['planned_minutes'] as int? ?? 0;
  int get actualMinutes => values['actual_minutes'] as int? ?? 0;
  double get timeRatio => (values['time_ratio'] as num? ?? 0).toDouble();
  double get checklistPercent => (values['checklist_percent'] as num? ?? 0).toDouble();
  double get compositeScore => (values['composite_score'] as num? ?? 0).toDouble();
  String get summary => values['automatic_summary'] as String? ?? '';
  String get note => values['supplementary_note'] as String? ?? '';
}
