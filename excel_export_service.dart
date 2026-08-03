import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../core/persian.dart';
import '../data/app_database.dart';

class ExcelExportResult {
  const ExcelExportResult({required this.success, this.path, this.error});
  final bool success;
  final String? path;
  final String? error;
}

class ExcelExportService {
  ExcelExportService(this.database);
  final AppDatabase database;

  Future<ExcelExportResult> exportFull() async {
    final name = 'گزارش_کامل_مسیر_بالینی_${faDigits(DateTime.now().toIso8601String().substring(0, 10))}.xlsx';
    try {
      final snapshot = await database.exportSnapshot();
      final dashboard = await database.getDashboard();
      final subjects = await database.getSubjectsProgress();
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) excel.rename(defaultSheet, 'داشبورد');

      _writeDashboard(excel['داشبورد'], dashboard, subjects);
      _writeTable(excel['برنامه خرد'], snapshot['plan_days']!, preferredHeaders: const [
        'day_number', 'jalali_date', 'weekday', 'week_number', 'planned_minutes',
        'planned_pages', 'planned_tests', 'checklist_status', 'checklist_score',
        'audit_status', 'activity_type', 'execution_notes',
      ]);
      _writeTable(excel['مرور تطبیقی'], snapshot['review_states']!);
      _writeAuditSheet(excel['ممیزی و فرضیات']);
      _writeTable(excel['گزارش روزانه'], snapshot['daily_reports']!);
      _writeTable(excel['گزارش هفتگی'], snapshot['weekly_reports']!);
      _writeTable(excel['تاریخچه جلسات'], snapshot['plan_parts']!);
      _writeTable(excel['تاریخچه مرورها'], snapshot['review_events']!);
      _writeTable(excel['تاریخچه تغییرات'], snapshot['audit_logs']!);
      _writeGuide(excel['راهنما']);
      excel.setDefaultSheet('داشبورد');
      final bytes = excel.save();
      if (bytes == null) throw StateError('تولید فایل اکسل ناموفق بود.');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره گزارش اکسل',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
      await database.addExportHistory(fileName: name, path: path, status: 'موفق');
      return ExcelExportResult(success: true, path: path);
    } catch (e) {
      await database.addExportHistory(fileName: name, status: 'ناموفق', error: e.toString());
      return ExcelExportResult(success: false, error: e.toString());
    }
  }

  void _writeDashboard(Sheet sheet, Map<String, Object?> dashboard, List<Map<String, Object?>> subjects) {
    sheet.appendRow([TextCellValue('داشبورد برنامه جامع کارشناسی ارشد روان‌شناسی بالینی ۱۴۰۶')]);
    sheet.appendRow([TextCellValue('شاخص'), TextCellValue('مقدار')]);
    final rows = <List<Object?>>[
      ['پیشرفت چک‌لیست', dashboard['checklist_progress']],
      ['روزهای معادل تکمیل‌شده', dashboard['equivalent_days']],
      ['دقیقه برنامه', dashboard['planned_minutes']],
      ['دقیقه واقعی', dashboard['actual_minutes']],
      ['صفحات برنامه', dashboard['planned_pages']],
      ['صفحات واقعی', dashboard['actual_pages']],
      ['تست برنامه', dashboard['planned_tests']],
      ['تست واقعی', dashboard['actual_tests']],
      ['روزهای دارای گزارش', dashboard['days_with_report']],
      ['مرورهای عقب‌افتاده', dashboard['overdue']],
      ['مرورهای امروز', dashboard['due_today']],
    ];
    for (final row in rows) sheet.appendRow(row.map(_cv).toList());
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('درس'), TextCellValue('ساعت برنامه'), TextCellValue('دقیقه واقعی'),
      TextCellValue('صفحات برنامه'), TextCellValue('صفحات واقعی'),
      TextCellValue('تست برنامه'), TextCellValue('تست واقعی'),
    ]);
    for (final subject in subjects) {
      sheet.appendRow([
        _cv(subject['name']), _cv(subject['planned_hours']), _cv(subject['actual_minutes']),
        _cv(subject['planned_pages']), _cv(subject['actual_pages']),
        _cv(subject['planned_tests']), _cv(subject['actual_tests']),
      ]);
    }
  }

  void _writeTable(Sheet sheet, List<Map<String, Object?>> rows, {List<String>? preferredHeaders}) {
    if (rows.isEmpty) {
      sheet.appendRow([TextCellValue('داده‌ای ثبت نشده است')]);
      return;
    }
    final allKeys = <String>{};
    for (final row in rows) allKeys.addAll(row.keys);
    final headers = <String>[
      ...?preferredHeaders?.where(allKeys.contains),
      ...allKeys.where((e) => !(preferredHeaders ?? const <String>[]).contains(e)),
    ];
    sheet.appendRow(headers.map((e) => TextCellValue(_headerFa(e))).toList());
    for (final row in rows) {
      sheet.appendRow(headers.map((key) => _cv(row[key])).toList());
    }
  }

  void _writeAuditSheet(Sheet sheet) {
    final rows = [
      ['عنوان', 'مقدار'],
      ['فایل مبنا', 'clinical_psychology_plan_1405_professional_final.xlsx'],
      ['نسخه ساختار', '۲'],
      ['تعداد روز برنامه', '۸۱'],
      ['تعداد هفته', '۱۲'],
      ['تعداد واحد مطالعه', '۱۸۰'],
      ['روش محوری', 'مرور بازیابی‌محور تطبیقی'],
      ['توضیح', 'این فایل از داده‌های برنامه مسیر بالینی تولید شده است.'],
    ];
    for (final row in rows) sheet.appendRow(row.map(TextCellValue.new).toList());
  }

  void _writeGuide(Sheet sheet) {
    final rows = [
      ['بخش', 'توضیح'],
      ['امروز', 'ثبت پارت‌ها و گزارش پایان روز'],
      ['برنامه', 'مشاهده ۸۱ روز برنامه در نمای موبایلی'],
      ['مرورها', 'ثبت کیفیت بازیابی و محاسبه مرور بعدی'],
      ['گزارش‌ها', 'گزارش روزانه، هفتگی و جامع'],
      ['پشتیبان', 'برای بازیابی کامل، از پشتیبان داخل برنامه استفاده شود.'],
    ];
    for (final row in rows) sheet.appendRow(row.map(TextCellValue.new).toList());
  }

  CellValue? _cv(Object? value) {
    if (value == null) return null;
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }

  String _headerFa(String key) => const {
        'day_number': 'شماره روز',
        'jalali_date': 'تاریخ شمسی',
        'gregorian_date': 'تاریخ میلادی',
        'weekday': 'روز هفته',
        'week_number': 'هفته',
        'planned_minutes': 'دقیقه برنامه',
        'actual_minutes': 'دقیقه واقعی',
        'planned_pages': 'صفحات برنامه',
        'actual_pages': 'صفحات واقعی',
        'planned_tests': 'تست برنامه',
        'actual_tests': 'تست واقعی',
        'checklist_status': 'وضعیت چک‌لیست',
        'checklist_score': 'امتیاز چک‌لیست',
        'audit_status': 'وضعیت ممیزی',
        'activity_type': 'نوع فعالیت',
        'execution_notes': 'یادداشت اجرایی',
        'has_report': 'پرچم ثبت گزارش',
        'time_ratio': 'تحقق زمانی',
        'page_ratio': 'تحقق صفحات',
        'test_ratio': 'تحقق تست',
        'daily_score': 'امتیاز گزارش روزانه',
        'report_status': 'وضعیت گزارش',
        'focus': 'تمرکز',
        'energy': 'انرژی',
        'achievement': 'مهم‌ترین دستاورد',
        'deviation_reason': 'علت انحراف',
        'corrective_action': 'اقدام جبرانی',
        'unit_code': 'شناسه واحد',
        'subject': 'درس',
        'chapter_title': 'عنوان فصل',
        'page_range': 'بازه صفحه',
        'due_status': 'وضعیت سررسید',
        'scheduled_date': 'تاریخ برنامه‌ریزی‌شده',
        'supplementary_note': 'یادداشت هفتگی تکمیلی',
      }[key] ?? key;
}
