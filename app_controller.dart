import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../domain/models.dart';
import 'backup_service.dart';
import 'excel_export_service.dart';

class AppController extends ChangeNotifier {
  AppController(this.database)
      : exporter = ExcelExportService(database),
        backup = BackupService(database);

  final AppDatabase database;
  final ExcelExportService exporter;
  final BackupService backup;

  bool initialized = false;
  bool busy = false;
  String? error;
  int navigationIndex = 0;
  ThemeMode themeMode = ThemeMode.system;
  PlanDay? today;
  DailyReport? todayReport;
  List<PlanDay> days = [];
  List<ReviewItem> reviews = [];
  List<WeeklySummary> weeks = [];
  List<Map<String, Object?>> dailyRows = [];
  List<Map<String, Object?>> subjects = [];
  Map<String, Object?> dashboard = {};
  String reviewFilter = 'همه';

  Future<void> initialize() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode = switch (prefs.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      await database.ensureSeeded();
      await refresh();
      initialized = true;
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final now = DateTime.now();
    final iso = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    today = await database.getDayByDate(iso);
    todayReport = today == null ? null : await database.getDailyReport(today!.id);
    days = await database.getAllDays();
    reviews = await database.getReviews(status: reviewFilter);
    weeks = await database.getWeeklySummaries();
    dailyRows = await database.getDailyReportRows();
    dashboard = await database.getDashboard();
    subjects = await database.getSubjectsProgress();
    notifyListeners();
  }

  void selectNavigation(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setReviewFilter(String value) async {
    reviewFilter = value;
    reviews = await database.getReviews(status: value);
    notifyListeners();
  }

  Future<void> savePart({
    required int partId,
    required String status,
    required int minutes,
    required int pages,
    required int tests,
    required String note,
  }) async {
    await _run(() async {
      await database.updatePartProgress(
        partId: partId,
        status: status,
        actualMinutes: minutes,
        actualPages: pages,
        actualTests: tests,
        note: note,
      );
      await refresh();
    });
  }

  Future<void> saveDailyReport({
    required int dayId,
    required int reviewMinutes,
    required int? focus,
    required int? energy,
    required String achievement,
    required String deviation,
    required String corrective,
  }) async {
    await _run(() async {
      await database.saveDailyReport(
        dayId: dayId,
        actualReviewMinutes: reviewMinutes,
        focus: focus,
        energy: energy,
        achievement: achievement,
        deviationReason: deviation,
        correctiveAction: corrective,
      );
      await refresh();
    });
  }

  Future<void> saveReview({
    required int stateId,
    required String quality,
    required int? correctPercent,
    required String? speed,
    required String? confidence,
    required bool conceptualError,
    required bool retraining,
    required String note,
  }) async {
    await _run(() async {
      await database.saveReview(
        reviewStateId: stateId,
        quality: quality,
        correctPercent: correctPercent,
        responseSpeed: speed,
        confidence: confidence,
        conceptualError: conceptualError,
        retrainingRequired: retraining,
        note: note,
      );
      await refresh();
    });
  }

  Future<void> saveWeeklyNote(int week, String note) async {
    await _run(() async {
      await database.saveWeeklyNote(week, note);
      weeks = await database.getWeeklySummaries();
      notifyListeners();
    });
  }

  Future<ExcelExportResult> exportExcel() async {
    busy = true;
    notifyListeners();
    try {
      return await exporter.exportFull();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<BackupResult> createBackup() async {
    busy = true;
    notifyListeners();
    try {
      return await backup.createBackup();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<BackupResult> restoreBackup() async {
    busy = true;
    notifyListeners();
    try {
      final result = await backup.restoreBackup();
      if (result.success) {
        await refresh();
      }
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> resetData() async {
    await _run(() async {
      await database.resetToBundledSeed();
      await refresh();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
