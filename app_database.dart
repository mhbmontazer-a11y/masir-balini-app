import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../services/adaptive_review_service.dart';
import '../services/report_calculator.dart';

class AppDatabase {
  Database? _db;

  Future<String> get databaseFilePath async =>
      p.join(await getDatabasesPath(), 'masir_balini_v2.db');

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = await databaseFilePath;
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE daily_reports ADD COLUMN data_origin TEXT NOT NULL DEFAULT \'auto_aggregated\'');
        }
      },
    );
  }

  Future<List<int>> readDatabaseBytes() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await db.close();
    _db = null;
    final file = File(await databaseFilePath);
    return file.readAsBytes();
  }

  Future<void> replaceDatabaseBytes(List<int> bytes) async {
    if (bytes.length < 100) {
      throw const FormatException('فایل پشتیبان معتبر نیست.');
    }
    final header = String.fromCharCodes(bytes.take(16));
    if (!header.startsWith('SQLite format 3')) {
      throw const FormatException('ساختار فایل پشتیبان معتبر نیست.');
    }
    await _db?.close();
    _db = null;
    final target = File(await databaseFilePath);
    final temporary = File('${target.path}.restore.tmp');
    final wal = File('${target.path}-wal');
    final shm = File('${target.path}-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
    await temporary.writeAsBytes(bytes, flush: true);
    File? safety;
    if (await target.exists()) {
      safety = File('${target.path}.before_restore');
      if (await safety.exists()) await safety.delete();
      await target.copy(safety.path);
      await target.delete();
    }
    await temporary.rename(target.path);
    final db = await database;
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final result = integrity.isEmpty ? null : integrity.first.values.first?.toString();
    if (result != 'ok') {
      await db.close();
      _db = null;
      if (await target.exists()) await target.delete();
      if (safety != null && await safety.exists()) {
        await safety.rename(target.path);
      }
      throw StateError('فایل پشتیبان سالم نیست: ${result ?? 'خطای نامشخص'}');
    }
    await refreshReviewDueStatuses();
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE metadata(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE subjects(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        planned_hours INTEGER NOT NULL,
        planned_pages INTEGER NOT NULL,
        planned_tests INTEGER NOT NULL,
        base_reviews INTEGER NOT NULL,
        coefficient INTEGER NOT NULL,
        planning_weight INTEGER NOT NULL,
        first_round_end TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE plan_days(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gregorian_date TEXT NOT NULL UNIQUE,
        jalali_date TEXT NOT NULL,
        weekday TEXT NOT NULL,
        day_number INTEGER NOT NULL UNIQUE,
        week_number INTEGER NOT NULL,
        planned_minutes INTEGER NOT NULL,
        planned_pages INTEGER NOT NULL,
        planned_tests INTEGER NOT NULL,
        checklist_status TEXT NOT NULL DEFAULT 'not_started',
        checklist_score REAL NOT NULL DEFAULT 0,
        audit_status TEXT NOT NULL,
        is_friday INTEGER NOT NULL DEFAULT 0,
        activity_type TEXT NOT NULL DEFAULT '',
        execution_notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_plan_days_date ON plan_days(gregorian_date)');
    await db.execute('CREATE INDEX idx_plan_days_week ON plan_days(week_number)');
    await db.execute('''
      CREATE TABLE plan_parts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_id INTEGER NOT NULL REFERENCES plan_days(id) ON DELETE CASCADE,
        part_number INTEGER NOT NULL,
        subject TEXT NOT NULL,
        description TEXT NOT NULL,
        unit_codes TEXT NOT NULL,
        planned_minutes INTEGER NOT NULL,
        planned_pages INTEGER NOT NULL,
        planned_tests INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'not_started',
        actual_minutes INTEGER NOT NULL DEFAULT 0,
        actual_pages INTEGER NOT NULL DEFAULT 0,
        actual_tests INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        updated_at TEXT,
        UNIQUE(day_id, part_number)
      )
    ''');
    await db.execute('CREATE INDEX idx_parts_day ON plan_parts(day_id)');
    await db.execute('''
      CREATE TABLE daily_reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_id INTEGER NOT NULL UNIQUE REFERENCES plan_days(id) ON DELETE CASCADE,
        has_report INTEGER NOT NULL DEFAULT 0,
        planned_minutes INTEGER NOT NULL,
        actual_minutes INTEGER NOT NULL DEFAULT 0,
        time_ratio REAL,
        planned_pages INTEGER NOT NULL,
        actual_pages INTEGER NOT NULL DEFAULT 0,
        page_ratio REAL,
        planned_tests INTEGER NOT NULL,
        actual_tests INTEGER NOT NULL DEFAULT 0,
        test_ratio REAL,
        actual_review_minutes INTEGER NOT NULL DEFAULT 0,
        focus INTEGER,
        energy INTEGER,
        achievement TEXT NOT NULL DEFAULT '',
        deviation_reason TEXT NOT NULL DEFAULT '',
        corrective_action TEXT NOT NULL DEFAULT '',
        daily_score REAL,
        minute_difference INTEGER,
        report_status TEXT NOT NULL DEFAULT 'ثبت‌نشده',
        data_origin TEXT NOT NULL DEFAULT 'auto_aggregated',
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE study_units(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_code TEXT NOT NULL UNIQUE,
        subject TEXT NOT NULL,
        source TEXT NOT NULL,
        chapter TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        subsection_title TEXT NOT NULL,
        page_range TEXT NOT NULL,
        page_count INTEGER NOT NULL,
        initial_date TEXT,
        initial_jalali TEXT,
        initial_minutes INTEGER NOT NULL,
        d1_date TEXT,
        d3_date TEXT,
        d7_date TEXT,
        d14_date TEXT,
        d28_date TEXT,
        deadline_date TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_unit_code ON study_units(unit_code)');
    await db.execute('''
      CREATE TABLE review_states(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL UNIQUE REFERENCES study_units(id) ON DELETE CASCADE,
        last_review_date TEXT,
        previous_interval_days INTEGER NOT NULL DEFAULT 1,
        correct_percent INTEGER,
        retrieval_quality TEXT,
        response_speed TEXT,
        confidence TEXT,
        full_success_count INTEGER NOT NULL DEFAULT 0,
        conceptual_error INTEGER NOT NULL DEFAULT 0,
        retraining_required INTEGER NOT NULL DEFAULT 0,
        suggested_date TEXT,
        scheduled_date TEXT,
        shift_days INTEGER NOT NULL DEFAULT 0,
        due_status TEXT NOT NULL DEFAULT 'فاقد داده',
        final_consolidation INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_review_due ON review_states(due_status, scheduled_date)');
    await db.execute('''
      CREATE TABLE review_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL REFERENCES study_units(id) ON DELETE CASCADE,
        actual_review_date TEXT NOT NULL,
        correct_percent INTEGER,
        retrieval_quality TEXT NOT NULL,
        response_speed TEXT,
        confidence TEXT,
        conceptual_error INTEGER NOT NULL,
        retraining_required INTEGER NOT NULL,
        previous_interval_days INTEGER NOT NULL,
        full_success_before INTEGER NOT NULL,
        full_success_after INTEGER NOT NULL,
        calculated_next_date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE weekly_notes(
        week_number INTEGER PRIMARY KEY,
        date_range TEXT NOT NULL,
        supplementary_note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        action_type TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE export_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        file_path TEXT,
        result_status TEXT NOT NULL,
        error_message TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> ensureSeeded() async {
    final db = await database;
    final row = await db.query('metadata', where: 'key = ?', whereArgs: ['seed_hash'], limit: 1);
    if (row.isNotEmpty) {
      await refreshReviewDueStatuses();
      return;
    }
    await resetToBundledSeed();
  }

  Future<void> resetToBundledSeed() async {
    final text = await rootBundle.loadString('assets/seed/normalized_seed_v2.json');
    final seed = jsonDecode(text) as Map<String, dynamic>;
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'review_events',
        'review_states',
        'study_units',
        'daily_reports',
        'plan_parts',
        'plan_days',
        'weekly_notes',
        'subjects',
        'audit_logs',
        'export_history',
        'metadata',
      ]) {
        await txn.delete(table);
      }

      for (final raw in seed['subjects'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        await txn.insert('subjects', {
          'name': item['name'],
          'planned_hours': item['plannedHours'],
          'planned_pages': item['plannedPages'],
          'planned_tests': item['plannedTests'],
          'base_reviews': item['baseReviews'],
          'coefficient': item['coefficient'],
          'planning_weight': item['weight'],
          'first_round_end': item['firstRoundEnd'],
        });
      }

      final dailyByDate = <String, Map<String, dynamic>>{};
      for (final raw in seed['dailyReports'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        dailyByDate[item['gregorianDate'] as String] = item;
      }

      for (final raw in seed['planDays'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        final checklist = _statusFromPersian(item['checklist'] as String?);
        final dayId = await txn.insert('plan_days', {
          'gregorian_date': item['gregorianDate'],
          'jalali_date': item['jalaliDate'],
          'weekday': item['weekday'],
          'day_number': item['dayNumber'],
          'week_number': item['weekNumber'],
          'planned_minutes': item['totalMinutes'],
          'planned_pages': item['totalNewPages'],
          'planned_tests': item['totalTests'],
          'checklist_status': checklist,
          'checklist_score': item['completionScore'],
          'audit_status': item['auditStatus'],
          'is_friday': item['isFriday'] == true ? 1 : 0,
          'activity_type': item['activityType'],
          'execution_notes': item['executionNotes'],
        });
        await txn.insert('plan_parts', {
          'day_id': dayId,
          'part_number': 1,
          'subject': item['part1Subject'],
          'description': item['part1Description'],
          'unit_codes': item['part1Units'],
          'planned_minutes': item['part1Minutes'],
          'planned_pages': item['part1Pages'],
          'planned_tests': item['part1Tests'],
          'status': checklist,
        });
        await txn.insert('plan_parts', {
          'day_id': dayId,
          'part_number': 2,
          'subject': item['part2Subject'],
          'description': item['part2Description'],
          'unit_codes': item['part2Units'],
          'planned_minutes': item['part2Minutes'],
          'planned_pages': item['part2Pages'],
          'planned_tests': item['part2Tests'],
          'status': checklist,
        });

        final report = dailyByDate[item['gregorianDate'] as String];
        await txn.insert('daily_reports', {
          'day_id': dayId,
          'has_report': report?['hasReport'] == true ? 1 : 0,
          'planned_minutes': item['totalMinutes'],
          'actual_minutes': (report?['actualMinutes'] as num?)?.toInt() ?? 0,
          'time_ratio': report?['timeRatio'],
          'planned_pages': item['totalNewPages'],
          'actual_pages': (report?['actualPages'] as num?)?.toInt() ?? 0,
          'page_ratio': report?['pageRatio'],
          'planned_tests': item['totalTests'],
          'actual_tests': (report?['actualTests'] as num?)?.toInt() ?? 0,
          'test_ratio': report?['testRatio'],
          'actual_review_minutes': (report?['actualReviewMinutes'] as num?)?.toInt() ?? 0,
          'focus': (report?['focus'] as num?)?.toInt(),
          'energy': (report?['energy'] as num?)?.toInt(),
          'achievement': report?['achievement'] ?? '',
          'deviation_reason': report?['deviationReason'] ?? '',
          'corrective_action': report?['correctiveAction'] ?? '',
          'daily_score': report?['dailyScore'],
          'minute_difference': (report?['minuteDifference'] as num?)?.toInt(),
          'report_status': report?['reportStatus'] ?? 'ثبت‌نشده',
          'data_origin': report?['hasReport'] == true ? 'imported_daily' : 'auto_aggregated',
        });
      }

      for (final raw in seed['studyUnits'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        final unitId = await txn.insert('study_units', {
          'unit_code': item['unitCode'],
          'subject': item['subject'],
          'source': item['source'],
          'chapter': item['chapter'],
          'chapter_title': item['chapterTitle'],
          'subsection_title': item['subsectionTitle'],
          'page_range': item['pageRange'],
          'page_count': item['pageCount'],
          'initial_date': item['initialDate'],
          'initial_jalali': item['initialJalaliDate'],
          'initial_minutes': item['initialMinutes'],
          'd1_date': item['d1Date'],
          'd3_date': item['d3Date'],
          'd7_date': item['d7Date'],
          'd14_date': item['d14Date'],
          'd28_date': item['d28Date'],
          'deadline_date': item['deadlineDate'],
        });
        await txn.insert('review_states', {
          'unit_id': unitId,
          'last_review_date': item['lastReviewDate'],
          'previous_interval_days': item['previousIntervalDays'],
          'correct_percent': (item['correctPercent'] as num?)?.toInt(),
          'retrieval_quality': item['retrievalQuality'],
          'response_speed': item['responseSpeed'],
          'confidence': item['confidence'],
          'full_success_count': item['fullSuccessCount'],
          'conceptual_error': item['conceptualError'] == true ? 1 : 0,
          'retraining_required': item['retrainingRequired'] == true ? 1 : 0,
          'suggested_date': item['suggestedDate'],
          'scheduled_date': item['scheduledDate'],
          'shift_days': item['shiftDays'],
          'due_status': item['dueStatus'] ?? 'فاقد داده',
          'final_consolidation': item['finalConsolidation'] == true ? 1 : 0,
        });
      }

      for (final raw in seed['weeklyReports'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        await txn.insert('weekly_notes', {
          'week_number': item['weekNumber'],
          'date_range': item['dateRange'],
          'supplementary_note': item['supplementaryNote'] ?? '',
        });
      }

      await txn.insert('metadata', {'key': 'schema_version', 'value': '${seed['schemaVersion']}'});
      await txn.insert('metadata', {'key': 'seed_hash', 'value': seed['sourceSha256']});
      await txn.insert('metadata', {'key': 'source_file', 'value': seed['sourceFile']});
    });
    await refreshReviewDueStatuses();
  }

  static String _statusFromPersian(String? value) {
    return switch (value) {
      'انجام‌شده' => 'completed',
      'نیمه‌انجام' => 'partial',
      _ => 'not_started',
    };
  }

  Future<List<PlanPart>> getParts(int dayId) async {
    final db = await database;
    final rows = await db.query('plan_parts', where: 'day_id = ?', whereArgs: [dayId], orderBy: 'part_number');
    return rows.map(PlanPart.fromMap).toList();
  }

  Future<PlanDay?> getDayByDate(String isoDate) async {
    final db = await database;
    var rows = await db.query('plan_days', where: 'gregorian_date = ?', whereArgs: [isoDate], limit: 1);
    if (rows.isEmpty) {
      rows = await db.rawQuery('SELECT * FROM plan_days ORDER BY ABS(julianday(gregorian_date) - julianday(?)) LIMIT 1', [isoDate]);
    }
    if (rows.isEmpty) return null;
    final row = rows.first;
    final parts = await getParts(row['id'] as int);
    return PlanDay.fromMap(row, parts);
  }

  Future<List<PlanDay>> getAllDays() async {
    final db = await database;
    final rows = await db.query('plan_days', orderBy: 'day_number');
    final result = <PlanDay>[];
    for (final row in rows) {
      result.add(PlanDay.fromMap(row, await getParts(row['id'] as int)));
    }
    return result;
  }

  Future<DailyReport?> getDailyReport(int dayId) async {
    final db = await database;
    final rows = await db.query('daily_reports', where: 'day_id = ?', whereArgs: [dayId], limit: 1);
    return rows.isEmpty ? null : DailyReport(values: rows.first);
  }

  Future<List<Map<String, Object?>>> getDailyReportRows() async {
    final db = await database;
    return db.rawQuery('''
      SELECT d.jalali_date, d.gregorian_date, d.weekday, d.week_number,
             d.checklist_status, d.checklist_score,
             r.*
      FROM plan_days d
      JOIN daily_reports r ON r.day_id = d.id
      ORDER BY d.day_number
    ''');
  }

  Future<void> updatePartProgress({
    required int partId,
    required String status,
    required int actualMinutes,
    required int actualPages,
    required int actualTests,
    required String note,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final old = (await txn.query('plan_parts', where: 'id = ?', whereArgs: [partId], limit: 1)).first;
      await txn.update('plan_parts', {
        'status': status,
        'actual_minutes': actualMinutes,
        'actual_pages': actualPages,
        'actual_tests': actualTests,
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [partId]);
      await txn.insert('audit_logs', {
        'entity_type': 'plan_part',
        'entity_id': partId,
        'action_type': 'task-status change',
        'old_values': jsonEncode(old),
        'new_values': jsonEncode({
          'status': status,
          'actual_minutes': actualMinutes,
          'actual_pages': actualPages,
          'actual_tests': actualTests,
          'note': note,
        }),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _recalculateDay(txn, old['day_id'] as int);
    });
  }

  Future<void> _recalculateDay(DatabaseExecutor txn, int dayId) async {
    final parts = await txn.query('plan_parts', where: 'day_id = ?', whereArgs: [dayId]);
    final statuses = parts.map((e) => e['status'] as String).toList();
    final status = statuses.every((e) => e == 'completed')
        ? 'completed'
        : statuses.every((e) => e == 'not_started')
            ? 'not_started'
            : 'partial';
    final score = status == 'completed' ? 1.0 : status == 'partial' ? .5 : 0.0;
    final minutes = parts.fold<int>(0, (sum, e) => sum + (e['actual_minutes'] as int? ?? 0));
    final pages = parts.fold<int>(0, (sum, e) => sum + (e['actual_pages'] as int? ?? 0));
    final tests = parts.fold<int>(0, (sum, e) => sum + (e['actual_tests'] as int? ?? 0));
    await txn.update('plan_days', {'checklist_status': status, 'checklist_score': score}, where: 'id = ?', whereArgs: [dayId]);
    final report = (await txn.query('daily_reports', where: 'day_id = ?', whereArgs: [dayId], limit: 1)).first;
    final hasReport = (report['has_report'] as int) == 1;
    final calc = ReportCalculator.daily(
      hasReport: hasReport,
      plannedMinutes: report['planned_minutes'] as int,
      actualMinutes: minutes,
      plannedPages: report['planned_pages'] as int,
      actualPages: pages,
      plannedTests: report['planned_tests'] as int,
      actualTests: tests,
    );
    await txn.update('daily_reports', {
      'actual_minutes': minutes,
      'actual_pages': pages,
      'actual_tests': tests,
      'time_ratio': calc.timeRatio,
      'page_ratio': calc.pageRatio,
      'test_ratio': calc.testRatio,
      'daily_score': calc.score,
      'minute_difference': calc.minuteDifference,
      'report_status': calc.status,
      'data_origin': 'auto_aggregated',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'day_id = ?', whereArgs: [dayId]);
  }

  Future<void> saveDailyReport({
    required int dayId,
    required int actualReviewMinutes,
    required int? focus,
    required int? energy,
    required String achievement,
    required String deviationReason,
    required String correctiveAction,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final report = (await txn.query('daily_reports', where: 'day_id = ?', whereArgs: [dayId], limit: 1)).first;
      final calc = ReportCalculator.daily(
        hasReport: true,
        plannedMinutes: report['planned_minutes'] as int,
        actualMinutes: report['actual_minutes'] as int,
        plannedPages: report['planned_pages'] as int,
        actualPages: report['actual_pages'] as int,
        plannedTests: report['planned_tests'] as int,
        actualTests: report['actual_tests'] as int,
      );
      await txn.update('daily_reports', {
        'has_report': 1,
        'actual_review_minutes': actualReviewMinutes,
        'focus': focus,
        'energy': energy,
        'achievement': achievement,
        'deviation_reason': deviationReason,
        'corrective_action': correctiveAction,
        'time_ratio': calc.timeRatio,
        'page_ratio': calc.pageRatio,
        'test_ratio': calc.testRatio,
        'daily_score': calc.score,
        'minute_difference': calc.minuteDifference,
        'report_status': calc.status,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'day_id = ?', whereArgs: [dayId]);
      await txn.insert('audit_logs', {
        'entity_type': 'daily_report',
        'entity_id': report['id'],
        'action_type': 'daily-report save',
        'new_values': jsonEncode({
          'focus': focus,
          'energy': energy,
          'achievement': achievement,
          'deviation_reason': deviationReason,
          'corrective_action': correctiveAction,
        }),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> refreshReviewDueStatuses() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.id, r.scheduled_date, r.final_consolidation
      FROM review_states r
    ''');
    final today = DateTime.now();
    final batch = db.batch();
    for (final row in rows) {
      final scheduled = DateTime.tryParse(row['scheduled_date'] as String? ?? '');
      final status = AdaptiveReviewService.dueStatus(
        scheduled: scheduled,
        today: today,
        finalConsolidation: (row['final_consolidation'] as int) == 1,
      );
      batch.update('review_states', {'due_status': status}, where: 'id = ?', whereArgs: [row['id']]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ReviewItem>> getReviews({String? status}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.*, u.unit_code, u.subject, u.chapter_title, u.page_range, u.deadline_date
      FROM review_states r
      JOIN study_units u ON u.id = r.unit_id
      ${status == null || status == 'همه' ? '' : 'WHERE r.due_status = ?'}
      ORDER BY r.conceptual_error DESC, r.retraining_required DESC,
               CASE r.due_status WHEN 'عقب‌افتاده' THEN 0 WHEN 'سررسید امروز' THEN 1 ELSE 2 END,
               r.scheduled_date, u.unit_code
    ''', status == null || status == 'همه' ? [] : [status]);
    return rows.map((e) => ReviewItem(values: e)).toList();
  }

  Future<void> saveReview({
    required int reviewStateId,
    required String quality,
    required int? correctPercent,
    required String? responseSpeed,
    required String? confidence,
    required bool conceptualError,
    required bool retrainingRequired,
    required String note,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final state = (await txn.rawQuery('''
        SELECT r.*, u.deadline_date FROM review_states r
        JOIN study_units u ON u.id = r.unit_id
        WHERE r.id = ?
      ''', [reviewStateId])).first;
      final now = DateTime.now();
      final decision = AdaptiveReviewService.calculate(
        reviewDate: now,
        quality: quality,
        previousInterval: state['previous_interval_days'] as int? ?? 1,
        previousFullSuccessCount: state['full_success_count'] as int? ?? 0,
      );
      final deadline = DateTime.tryParse(state['deadline_date'] as String? ?? '');
      final finalConsolidation = deadline != null && decision.nextDate.isAfter(deadline);
      final status = AdaptiveReviewService.dueStatus(
        scheduled: decision.nextDate,
        today: now,
        finalConsolidation: finalConsolidation,
      );
      final nextIso = _dateOnly(decision.nextDate);
      await txn.insert('review_events', {
        'unit_id': state['unit_id'],
        'actual_review_date': _dateOnly(now),
        'correct_percent': correctPercent,
        'retrieval_quality': quality,
        'response_speed': responseSpeed,
        'confidence': confidence,
        'conceptual_error': conceptualError ? 1 : 0,
        'retraining_required': retrainingRequired ? 1 : 0,
        'previous_interval_days': state['previous_interval_days'],
        'full_success_before': state['full_success_count'],
        'full_success_after': decision.fullSuccessCount,
        'calculated_next_date': nextIso,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update('review_states', {
        'last_review_date': _dateOnly(now),
        'previous_interval_days': decision.nextInterval,
        'correct_percent': correctPercent,
        'retrieval_quality': quality,
        'response_speed': responseSpeed,
        'confidence': confidence,
        'full_success_count': decision.fullSuccessCount,
        'conceptual_error': conceptualError ? 1 : 0,
        'retraining_required': retrainingRequired ? 1 : 0,
        'suggested_date': nextIso,
        'scheduled_date': nextIso,
        'due_status': status,
        'final_consolidation': finalConsolidation ? 1 : 0,
        'note': note,
      }, where: 'id = ?', whereArgs: [reviewStateId]);
    });
  }

  Future<List<WeeklySummary>> getWeeklySummaries() async {
    final db = await database;
    final notes = await db.query('weekly_notes', orderBy: 'week_number');
    final result = <WeeklySummary>[];
    for (final note in notes) {
      final week = note['week_number'] as int;
      final days = await db.rawQuery('''
        SELECT d.id, d.planned_minutes, d.planned_pages, d.planned_tests,
               d.checklist_status, r.*
        FROM plan_days d JOIN daily_reports r ON r.day_id = d.id
        WHERE d.week_number = ?
      ''', [week]);
      int sumInt(String key) => days.fold(0, (s, e) => s + (e[key] as int? ?? 0));
      final plannedMinutes = sumInt('planned_minutes');
      final actualMinutes = sumInt('actual_minutes');
      final plannedPages = sumInt('planned_pages');
      final actualPages = sumInt('actual_pages');
      final plannedTests = sumInt('planned_tests');
      final actualTests = sumInt('actual_tests');
      final completed = days.where((e) => e['checklist_status'] == 'completed').length;
      final partial = days.where((e) => e['checklist_status'] == 'partial').length;
      final notStarted = days.length - completed - partial;
      final withReport = days.where((e) => e['has_report'] == 1).toList();
      double avg(String key) {
        final values = withReport.map((e) => e[key]).whereType<num>().map((e) => e.toDouble()).toList();
        return values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
      }
      final timeRatio = plannedMinutes == 0 ? 0.0 : actualMinutes / plannedMinutes;
      final pageRatio = plannedPages == 0 ? 0.0 : actualPages / plannedPages;
      final testRatio = plannedTests == 0 ? 0.0 : actualTests / plannedTests;
      final checklist = ReportCalculator.checklistPercent(completed: completed, partial: partial, dayCount: days.length);
      final composite = ReportCalculator.weeklyComposite([timeRatio, pageRatio, testRatio, checklist]);
      result.add(WeeklySummary(values: {
        'week_number': week,
        'date_range': note['date_range'],
        'day_count': days.length,
        'planned_minutes': plannedMinutes,
        'actual_minutes': actualMinutes,
        'time_ratio': timeRatio,
        'planned_pages': plannedPages,
        'actual_pages': actualPages,
        'page_ratio': pageRatio,
        'planned_tests': plannedTests,
        'actual_tests': actualTests,
        'test_ratio': testRatio,
        'average_focus': avg('focus'),
        'average_energy': avg('energy'),
        'completed_days': completed,
        'partial_days': partial,
        'not_started_days': notStarted,
        'equivalent_days': completed + partial * .5,
        'checklist_percent': checklist,
        'days_with_report': withReport.length,
        'days_without_report': days.length - withReport.length,
        'composite_score': composite,
        'automatic_summary': ReportCalculator.weeklySummary(daysWithReport: withReport.length, score: composite),
        'supplementary_note': note['supplementary_note'],
      }));
    }
    return result;
  }

  Future<void> saveWeeklyNote(int weekNumber, String note) async {
    final db = await database;
    await db.update('weekly_notes', {'supplementary_note': note}, where: 'week_number = ?', whereArgs: [weekNumber]);
  }

  Future<Map<String, Object?>> getDashboard() async {
    final db = await database;
    final days = await db.rawQuery('SELECT COUNT(*) count, SUM(checklist_score) completed FROM plan_days');
    final report = await db.rawQuery('''
      SELECT SUM(planned_minutes) planned_minutes, SUM(actual_minutes) actual_minutes,
             SUM(planned_pages) planned_pages, SUM(actual_pages) actual_pages,
             SUM(planned_tests) planned_tests, SUM(actual_tests) actual_tests,
             SUM(has_report) days_with_report,
             AVG(CASE WHEN focus > 0 THEN focus END) avg_focus,
             AVG(CASE WHEN energy > 0 THEN energy END) avg_energy
      FROM daily_reports
    ''');
    final review = await db.rawQuery('''
      SELECT SUM(CASE WHEN due_status = 'عقب‌افتاده' THEN 1 ELSE 0 END) overdue,
             SUM(CASE WHEN due_status = 'سررسید امروز' THEN 1 ELSE 0 END) due_today,
             SUM(CASE WHEN due_status = 'انتقال به تثبیت نهایی' THEN 1 ELSE 0 END) final_count
      FROM review_states
    ''');
    final dayCount = (days.first['count'] as int?) ?? 0;
    final completed = (days.first['completed'] as num?)?.toDouble() ?? 0;
    return {
      'day_count': dayCount,
      'equivalent_days': completed,
      'checklist_progress': dayCount == 0 ? 0.0 : completed / dayCount,
      ...report.first,
      ...review.first,
    };
  }

  Future<List<Map<String, Object?>>> getSubjectsProgress() async {
    final db = await database;
    final subjects = await db.query('subjects', orderBy: 'planning_weight DESC, id');
    final result = <Map<String, Object?>>[];
    for (final subject in subjects) {
      final name = subject['name'] as String;
      final actual = await db.rawQuery('''
        SELECT SUM(actual_minutes) actual_minutes, SUM(actual_pages) actual_pages, SUM(actual_tests) actual_tests
        FROM plan_parts WHERE subject = ?
      ''', [name]);
      result.add({...subject, ...actual.first});
    }
    return result;
  }

  Future<Map<String, List<Map<String, Object?>>>> exportSnapshot() async {
    final db = await database;
    return {
      'subjects': await db.query('subjects'),
      'plan_days': await db.query('plan_days', orderBy: 'day_number'),
      'plan_parts': await db.query('plan_parts', orderBy: 'day_id, part_number'),
      'daily_reports': await getDailyReportRows(),
      'weekly_reports': (await getWeeklySummaries()).map((e) => e.values).toList(),
      'study_units': await db.query('study_units', orderBy: 'unit_code'),
      'review_states': await db.rawQuery('''
        SELECT u.*, r.* FROM study_units u JOIN review_states r ON r.unit_id = u.id ORDER BY u.unit_code
      '''),
      'review_events': await db.rawQuery('''
        SELECT u.unit_code, u.subject, u.chapter_title, u.page_range, e.*
        FROM review_events e JOIN study_units u ON u.id = e.unit_id ORDER BY e.created_at
      '''),
      'audit_logs': await db.query('audit_logs', orderBy: 'created_at'),
    };
  }

  Future<void> addExportHistory({required String fileName, String? path, required String status, String? error}) async {
    final db = await database;
    await db.insert('export_history', {
      'file_name': fileName,
      'file_path': path,
      'result_status': status,
      'error_message': error,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
