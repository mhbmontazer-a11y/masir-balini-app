import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/persian.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.initialized) {
      return Scaffold(
        body: Center(
          child: controller.error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('در حال آماده‌سازی برنامه…'),
                  ],
                )
              : _ErrorPanel(message: controller.error!, onRetry: controller.initialize),
        ),
      );
    }
    final screens = [
      TodayScreen(controller: controller),
      ProgramScreen(controller: controller),
      ReviewsScreen(controller: controller),
      ReportsScreen(controller: controller),
      SettingsScreen(controller: controller),
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: controller.navigationIndex, children: screens),
            if (controller.busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.navigationIndex,
        onDestinationSelected: controller.selectNavigation,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'امروز'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'برنامه'),
          NavigationDestination(icon: Icon(Icons.replay_outlined), selectedIcon: Icon(Icons.replay), label: 'مرورها'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'گزارش‌ها'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final day = controller.today;
    if (day == null) return const Center(child: Text('برنامه‌ای یافت نشد.'));
    final report = controller.todayReport;
    final actual = report?.actualMinutes ?? 0;
    final due = (controller.dashboard['due_today'] as int?) ?? 0;
    final overdue = (controller.dashboard['overdue'] as int?) ?? 0;
    final overall = (controller.dashboard['checklist_progress'] as num? ?? 0).toDouble();
    final todayProgress = day.plannedMinutes == 0
        ? 0.0
        : math.min(1.0, actual / day.plannedMinutes).toDouble();
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _TodayHeader(
            day: day,
            overallProgress: overall,
            todayProgress: todayProgress,
            actualMinutes: actual,
            dueReviews: due + overdue,
            onNotifications: () => controller.selectNavigation(2),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const _SectionTitle(title: 'برنامه امروز', icon: Icons.auto_awesome_motion_outlined),
                const Spacer(),
                Text('${day.weekday}، ${day.jalaliDate}', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 12),
              for (var i = 0; i < day.parts.length; i++) ...[
                _PartCard(
                  part: day.parts[i],
                  isFriday: day.isFriday,
                  onStart: () async {
                    final elapsed = await Navigator.of(context).push<int>(
                      MaterialPageRoute(builder: (_) => StudyTimerPage(part: day.parts[i])),
                    );
                    if (elapsed != null && context.mounted) {
                      await _showPartSheet(
                        context,
                        controller,
                        day.parts[i],
                        suggestedMinutes: elapsed,
                      );
                    }
                  },
                  onEdit: () => _showPartSheet(context, controller, day.parts[i]),
                ),
                if (i == 0) ...[
                  const SizedBox(height: 12),
                  _ReviewBridge(due: due, overdue: overdue, onTap: () => controller.selectNavigation(2)),
                ],
                const SizedBox(height: 12),
              ],
              _DailyReportCard(
                report: report,
                onTap: () => _showDailyReportSheet(context, controller, day, report),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.day,
    required this.overallProgress,
    required this.todayProgress,
    required this.actualMinutes,
    required this.dueReviews,
    required this.onNotifications,
  });

  final PlanDay day;
  final double overallProgress;
  final double todayProgress;
  final int actualMinutes;
  final int dueReviews;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navySoft],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/branding/app_icon.png', width: 48, height: 48),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مسیر بالینی', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('برنامه مطالعه روان‌شناسی بالینی', style: TextStyle(color: Color(0xFFCAD6E5), fontSize: 12)),
            ]),
          ),
          IconButton(onPressed: onNotifications, icon: const Icon(Icons.notifications_none_rounded, color: Colors.white)),
        ]),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: overallProgress.clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 9,
                  backgroundColor: AppColors.lavender,
                  color: AppColors.purple,
                ),
                Text(faPercent(overallProgress), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navy)),
              ]),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('پیشرفت کل دوره', style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 5),
                Text('روز ${faDigits(day.dayNumber)} از ۸۱', style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: todayProgress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: const Color(0xFFECEAF4),
                  color: AppColors.teal,
                ),
                const SizedBox(height: 6),
                Text('پیشرفت امروز ${faPercent(todayProgress)}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _DarkMetric(icon: Icons.timer_outlined, value: compactMinutes(actualMinutes), label: 'مطالعه امروز')),
          const SizedBox(width: 10),
          Expanded(child: _DarkMetric(icon: Icons.replay_rounded, value: faDigits(dueReviews), label: 'مرور سررسید')),
          const SizedBox(width: 10),
          Expanded(child: _DarkMetric(icon: Icons.calendar_month_outlined, value: 'هفته ${faDigits(day.weekNumber)}', label: day.weekday)),
        ]),
      ]),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(17)),
        child: Column(children: [
          Icon(icon, color: const Color(0xFFD9D2FF), size: 20),
          const SizedBox(height: 5),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBFCBDC), fontSize: 10)),
        ]),
      );
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.onStart,
    required this.onEdit,
    required this.isFriday,
  });

  final PlanPart part;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final bool isFriday;

  @override
  Widget build(BuildContext context) {
    final progress = part.plannedMinutes == 0
        ? 0.0
        : math.min(1.0, part.actualMinutes / part.plannedMinutes).toDouble();
    final subjectColor = _subjectColor(part.subject);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: subjectColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.menu_book_rounded, color: subjectColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isFriday && part.partNumber == 2 ? 'ایستگاه جبرانی و تثبیت' : part.subject, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(part.unitCodes.isEmpty ? 'پارت ${faDigits(part.partNumber)}' : part.unitCodes, style: TextStyle(color: subjectColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: progress, strokeWidth: 6, backgroundColor: const Color(0xFFECECF2), color: subjectColor),
                Text(faPercent(progress), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(part.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.65)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MiniChip(icon: Icons.schedule, text: compactMinutes(part.plannedMinutes)),
            _MiniChip(icon: Icons.menu_book_outlined, text: '${faDigits(part.plannedPages)} صفحه'),
            _MiniChip(icon: Icons.fact_check_outlined, text: '${faDigits(part.plannedTests)} تست'),
            _StatusBadge(status: part.status),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(part.status == 'not_started' ? 'شروع مطالعه' : 'ادامه مطالعه'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: OutlinedButton(onPressed: onEdit, child: const Text('ثبت نتیجه'))),
          ]),
        ]),
      ),
    );
  }
}

Color _subjectColor(String subject) {
  if (subject.contains('آسیب')) return const Color(0xFF2BB99A);
  if (subject.contains('رشد')) return const Color(0xFF5B35D5);
  if (subject.contains('درمان')) return const Color(0xFFF6A43B);
  return const Color(0xFF4E84D4);
}

class _DailyReportCard extends StatelessWidget {
  const _DailyReportCard({required this.report, required this.onTap});
  final DailyReport? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final registered = report?.hasReport ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.edit_note),
            const SizedBox(width: 8),
            Text('گزارش پایان روز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Chip(label: Text(registered ? report!.status : 'ثبت نشده')),
          ]),
          const SizedBox(height: 10),
          Text(registered ? 'گزارش روز ثبت شده و قابل ویرایش است.' : 'زمان، صفحه و تست از پارت‌ها خودکار جمع می‌شوند؛ فقط ارزیابی روز را تکمیل کنید.'),
          if (report != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _MiniChip(icon: Icons.timer_outlined, text: '${faDigits(report.actualMinutes)} دقیقه'),
              _MiniChip(icon: Icons.menu_book_outlined, text: '${faDigits(report.actualPages)} صفحه'),
              _MiniChip(icon: Icons.fact_check_outlined, text: '${faDigits(report.actualTests ?? 0)} تست'),
              _MiniChip(icon: Icons.speed, text: faPercent(report.score ?? 0)),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.edit_note), label: Text(registered ? 'ویرایش گزارش امروز' : 'ثبت گزارش امروز'))),
        ]),
      ),
    );
  }
}

class _ReviewBridge extends StatelessWidget {
  const _ReviewBridge({required this.due, required this.overdue, required this.onTap});
  final int due;
  final int overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.replay)),
          title: const Text('مرورهای امروز', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${faDigits(due)} سررسید امروز • ${faDigits(overdue)} عقب‌افتاده'),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  String query = '';
  String filter = 'همه';

  @override
  Widget build(BuildContext context) {
    var days = widget.controller.days.where((day) {
      final text = '${day.jalaliDate} ${day.weekday} ${day.parts.map((e) => '${e.subject} ${e.unitCodes} ${e.description}').join(' ')}';
      final searchOk = query.isEmpty || text.contains(query);
      final filterOk = filter == 'همه' || _statusFa(day.checklistStatus) == filter || (filter == 'نیازمند بررسی' && day.auditStatus == 'نیازمند بررسی');
      return searchOk && filterOk;
    }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('برنامه', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جست‌وجوی درس، فصل یا شناسه واحد'),
            onChanged: (value) => setState(() => query = value.trim()),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['همه', 'انجام‌نشده', 'نیمه‌انجام', 'انجام‌شده', 'نیازمند بررسی'].map((e) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(label: Text(e), selected: filter == e, onSelected: (_) => setState(() => filter = e)),
            )).toList()),
          ),
        ]),
      ),
      Expanded(
        child: days.isEmpty
            ? const _EmptyState(icon: Icons.search_off, title: 'نتیجه‌ای پیدا نشد', text: 'عبارت جست‌وجو یا فیلترها را تغییر دهید.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                itemCount: days.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DayTile(day: days[index]),
                ),
              ),
      ),
    ]);
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});
  final PlanDay day;
  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: CircleAvatar(child: Text(faDigits(day.dayNumber))),
          title: Text('${day.weekday}، ${day.jalaliDate}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('هفته ${faDigits(day.weekNumber)} • ${compactMinutes(day.plannedMinutes)}'),
          trailing: _StatusBadge(status: day.checklistStatus),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final part in day.parts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('پارت ${faDigits(part.partNumber)}'),
                title: Text(part.subject),
                subtitle: Text('${part.unitCodes} • ${faDigits(part.plannedPages)} صفحه • ${faDigits(part.plannedTests)} تست'),
              ),
            if (day.auditStatus == 'نیازمند بررسی') const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.warning_amber), title: Text('این روز نیازمند بررسی ممیزی است.')),
          ],
        ),
      );
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مرورها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['عقب‌افتاده', 'سررسید امروز', 'آینده', 'انتقال به تثبیت نهایی', 'همه'].map((e) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(label: Text(e == 'سررسید امروز' ? 'امروز' : e), selected: controller.reviewFilter == e, onSelected: (_) => controller.setReviewFilter(e)),
            )).toList()),
          ),
        ]),
      ),
      Expanded(
        child: controller.reviews.isEmpty
            ? const _EmptyState(icon: Icons.task_alt, title: 'مروری در این بخش نیست', text: 'مرورهای بعدی در زمان سررسید نمایش داده می‌شوند.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: controller.reviews.length,
                itemBuilder: (context, index) {
                  final item = controller.reviews[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(item.unitCode, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Chip(label: Text(item.dueStatus)),
                          ]),
                          const SizedBox(height: 6),
                          Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${item.chapterTitle} • ${item.pageRange}'),
                          if (item.scheduledDate != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('تاریخ برنامه‌ریزی‌شده: ${jalaliFromIso(item.scheduledDate!)}')),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showReviewSheet(context, controller, item), icon: const Icon(Icons.fact_check_outlined), label: const Text('ثبت مرور'))),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Align(alignment: Alignment.centerRight, child: Text('گزارش‌ها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          ),
          const TabBar(tabs: [Tab(text: 'روزانه'), Tab(text: 'هفتگی'), Tab(text: 'جامع')]),
          Expanded(child: TabBarView(children: [
            _DailyReports(controller: controller),
            _WeeklyReports(controller: controller),
            _ComprehensiveReport(controller: controller),
          ])),
        ]),
      );
}

class _DailyReports extends StatelessWidget {
  const _DailyReports({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final rows = controller.dailyRows.take(14).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _ChartCard(title: 'زمان برنامه و زمان واقعی', child: SizedBox(height: 220, child: _DailyLineChart(rows: rows))),
      const SizedBox(height: 12),
      for (final row in controller.dailyRows.reversed.take(20))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text('${row['weekday']}، ${row['jalali_date']}'),
              subtitle: Text('واقعی: ${faDigits(row['actual_minutes'] ?? 0)} از ${faDigits(row['planned_minutes'])} دقیقه'),
              trailing: Chip(label: Text(row['report_status'] as String? ?? 'ثبت‌نشده')),
            ),
          ),
        ),
    ]);
  }
}

class _WeeklyReports extends StatelessWidget {
  const _WeeklyReports({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        _ChartCard(title: 'زمان برنامه و زمان واقعی به تفکیک هفته', child: SizedBox(height: 230, child: _WeeklyBarChart(weeks: controller.weeks))),
        const SizedBox(height: 12),
        for (final week in controller.weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ExpansionTile(
                title: Text('هفته ${faDigits(week.weekNumber)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${week.dateRange} • ${faPercent(week.compositeScore)}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _MetricRow('تحقق زمانی', faPercent(week.timeRatio)),
                  _MetricRow('پیشرفت چک‌لیست', faPercent(week.checklistPercent)),
                  _MetricRow('زمان واقعی', compactMinutes(week.actualMinutes)),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: Text(week.summary)),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: week.note,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'یادداشت هفتگی تکمیلی'),
                    onFieldSubmitted: (value) => controller.saveWeeklyNote(week.weekNumber, value),
                  ),
                  const SizedBox(height: 6),
                  const Text('برای ذخیره یادداشت، دکمه انجام روی صفحه‌کلید را بزنید.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
      ]);
}

class _ComprehensiveReport extends StatelessWidget {
  const _ComprehensiveReport({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final d = controller.dashboard;
    final progress = (d['checklist_progress'] as num? ?? 0).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          _KpiCard('پیشرفت چک‌لیست', faPercent(progress), Icons.check_circle_outline),
          _KpiCard('روزهای معادل', faNumber((d['equivalent_days'] as num? ?? 0), fraction: 1), Icons.calendar_month_outlined),
          _KpiCard('زمان واقعی', compactMinutes((d['actual_minutes'] as int?) ?? 0), Icons.timer_outlined),
          _KpiCard('روزهای دارای گزارش', faDigits(d['days_with_report'] ?? 0), Icons.edit_note),
        ],
      ),
      const SizedBox(height: 12),
      _ChartCard(title: 'وضعیت پیشرفت برنامه', child: SizedBox(height: 220, child: _ProgressPie(progress: progress))),
      const SizedBox(height: 12),
      const _SectionTitle(title: 'پیشرفت درس‌ها', icon: Icons.menu_book_outlined),
      const SizedBox(height: 8),
      for (final s in controller.subjects)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: math
                      .min(1.0, ((s['actual_minutes'] as num? ?? 0).toDouble()) / ((s['planned_hours'] as int) * 60))
                      .toDouble(),
                ),
                const SizedBox(height: 8),
                Text('${compactMinutes((s['actual_minutes'] as int?) ?? 0)} از ${faDigits(s['planned_hours'])} ساعت'),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.settings_rounded, color: AppColors.purple),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تنظیمات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const Text('ظاهر، داده‌ها و خروجی‌ها', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 18),
          const _SettingsLabel('نمایش'),
          Card(
            child: Column(children: [
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.brightness_auto_outlined),
                title: const Text('خودکار'),
                value: ThemeMode.system,
                groupValue: controller.themeMode,
                onChanged: (v) => v == null ? null : controller.setTheme(v),
              ),
              const Divider(height: 1),
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.light_mode_outlined),
                title: const Text('روشن'),
                value: ThemeMode.light,
                groupValue: controller.themeMode,
                onChanged: (v) => v == null ? null : controller.setTheme(v),
              ),
              const Divider(height: 1),
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('تیره'),
                value: ThemeMode.dark,
                groupValue: controller.themeMode,
                onChanged: (v) => v == null ? null : controller.setTheme(v),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const _SettingsLabel('داده‌ها و گزارش'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const _SettingsIcon(icon: Icons.file_download_outlined),
                title: const Text('خروجی کامل اکسل'),
                subtitle: const Text('ساخت فایل گزارش از اطلاعات فعلی اپ'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  final result = await controller.exportExcel();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.success ? 'فایل اکسل ساخته شد' : 'ساخت فایل اکسل انجام نشد: ${result.error ?? ''}')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.cloud_download_outlined),
                title: const Text('تهیه پشتیبان کامل'),
                subtitle: const Text('ذخیره تمام اطلاعات و سوابق برنامه'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  final result = await controller.createBackup();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.success ? 'فایل پشتیبان ساخته شد' : result.error ?? 'تهیه پشتیبان انجام نشد')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.settings_backup_restore_rounded),
                title: const Text('بازیابی پشتیبان'),
                subtitle: const Text('جایگزینی اطلاعات فعلی با فایل پشتیبان'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _confirmRestore(context, controller),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.restart_alt_rounded),
                title: const Text('بازنشانی با فایل اصلی'),
                subtitle: const Text('حذف ثبت‌های فعلی و بازگرداندن برنامه اولیه'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _confirmReset(context, controller),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const _SettingsLabel('درباره'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.teal),
                  SizedBox(width: 8),
                  Text('حریم خصوصی داده‌ها', style: TextStyle(fontWeight: FontWeight.w900)),
                ]),
                SizedBox(height: 10),
                Text(
                  'اطلاعات برنامه به‌صورت آفلاین روی دستگاه ذخیره می‌شود و بدون اقدام مستقیم شما ارسال نخواهد شد.',
                  style: TextStyle(height: 1.7),
                ),
                SizedBox(height: 12),
                Text('نسخه ۱٫۰٫۰', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ]),
            ),
          ),
        ],
      );
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy)),
      );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.purple, size: 21),
      );
}

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart({required this.rows});
  final List<Map<String, Object?>> rows;
  @override
  Widget build(BuildContext context) {
    final planned = <FlSpot>[];
    final actual = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      planned.add(FlSpot(i.toDouble(), (rows[i]['planned_minutes'] as num? ?? 0).toDouble()));
      actual.add(FlSpot(i.toDouble(), (rows[i]['actual_minutes'] as num? ?? 0).toDouble()));
    }
    final scheme = Theme.of(context).colorScheme;
    return LineChart(LineChartData(
      minY: 0,
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
      ),
      lineBarsData: [
        LineChartBarData(spots: planned, color: scheme.outline, barWidth: 2, dotData: const FlDotData(show: false)),
        LineChartBarData(spots: actual, color: scheme.primary, barWidth: 3, dotData: const FlDotData(show: false)),
      ],
    ));
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.weeks});
  final List<WeeklySummary> weeks;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BarChart(BarChartData(
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(faDigits(value.toInt() + 1), style: const TextStyle(fontSize: 10)))),
      ),
      barGroups: List.generate(weeks.length, (i) => BarChartGroupData(x: i, barsSpace: 3, barRods: [
        BarChartRodData(toY: weeks[i].plannedMinutes.toDouble(), width: 7, color: scheme.outlineVariant),
        BarChartRodData(toY: weeks[i].actualMinutes.toDouble(), width: 7, color: scheme.primary),
      ])),
    ));
  }
}

class _ProgressPie extends StatelessWidget {
  const _ProgressPie({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(alignment: Alignment.center, children: [
      PieChart(PieChartData(centerSpaceRadius: 58, sectionsSpace: 3, sections: [
        PieChartSectionData(value: math.max(0.0, progress * 100).toDouble(), color: scheme.primary, radius: 34, showTitle: false),
        PieChartSectionData(value: math.max(0.0, (1 - progress) * 100).toDouble(), color: scheme.surfaceContainerHighest, radius: 34, showTitle: false),
      ])),
      Text(faPercent(progress), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }
}

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key, required this.part});

  final PlanPart part;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> with WidgetsBindingObserver {
  Timer? _ticker;
  int _elapsedSeconds = 0;
  DateTime? _runningSince;
  bool _running = false;

  String get _prefix => 'study_timer_${widget.part.id}_';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('${_prefix}elapsed') ?? 0;
    final started = prefs.getString('${_prefix}started');
    final running = prefs.getBool('${_prefix}running') ?? false;
    var elapsed = saved;
    DateTime? since;
    if (running && started != null) {
      since = DateTime.tryParse(started);
      if (since != null) elapsed += DateTime.now().difference(since).inSeconds;
    }
    if (!mounted) return;
    setState(() {
      _elapsedSeconds = elapsed;
      _running = running;
      _runningSince = running ? DateTime.now() : null;
    });
    if (_running) _beginTicker();
  }

  void _beginTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _startOrResume() async {
    if (_running) return;
    setState(() {
      _running = true;
      _runningSince = DateTime.now();
    });
    _beginTicker();
    await _persist();
  }

  Future<void> _pause() async {
    if (!_running) return;
    _ticker?.cancel();
    setState(() {
      _running = false;
      _runningSince = null;
    });
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}elapsed', _elapsedSeconds);
    await prefs.setBool('${_prefix}running', _running);
    if (_running) {
      _runningSince = DateTime.now();
      await prefs.setString('${_prefix}started', _runningSince!.toIso8601String());
    } else {
      await prefs.remove('${_prefix}started');
    }
  }

  Future<void> _finish() async {
    await _pause();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefix}elapsed');
    await prefs.remove('${_prefix}running');
    await prefs.remove('${_prefix}started');
    final minutes = math.max(1, (_elapsedSeconds / 60).ceil()).toInt();
    if (mounted) Navigator.pop(context, minutes);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _ticker?.cancel();
      _persist();
    } else if (state == AppLifecycleState.resumed && _running) {
      _resumeFromBackground();
    }
  }

  Future<void> _resumeFromBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final started = DateTime.tryParse(prefs.getString('${_prefix}started') ?? '');
    if (started != null && mounted) {
      setState(() {
        _elapsedSeconds += DateTime.now().difference(started).inSeconds;
        _runningSince = DateTime.now();
      });
    }
    _beginTicker();
    await _persist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _persist();
    super.dispose();
  }

  String _clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${faDigits(h.toString().padLeft(2, '0'))}:${faDigits(m.toString().padLeft(2, '0'))}:${faDigits(s.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = math
        .min(1.0, _elapsedSeconds / math.max(1, widget.part.plannedMinutes * 60))
        .toDouble();
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('حالت تمرکز'),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            Text(widget.part.subject, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(widget.part.unitCodes, style: const TextStyle(color: Color(0xFFCFC7FF), fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(widget.part.description, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBFCBDC), height: 1.6)),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: progress, strokeWidth: 13, backgroundColor: Colors.white.withValues(alpha: .1), color: const Color(0xFFA991FF)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_clock(_elapsedSeconds), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text('هدف ${faDigits(widget.part.plannedMinutes)} دقیقه', style: const TextStyle(color: Color(0xFFBFCBDC))),
                ]),
              ]),
            ),
            const Spacer(),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? _pause : _startOrResume,
                  icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_running ? 'توقف موقت' : (_elapsedSeconds == 0 ? 'شروع' : 'ادامه')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                  onPressed: _elapsedSeconds == 0 ? null : _finish,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('پایان و ثبت'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> _showPartSheet(
  BuildContext context,
  AppController controller,
  PlanPart part, {
  int? suggestedMinutes,
}) async {
  var status = part.status;
  final minutes = TextEditingController(
    text: '${suggestedMinutes ?? (part.actualMinutes == 0 ? part.plannedMinutes : part.actualMinutes)}',
  );
  final pages = TextEditingController(text: '${part.actualPages == 0 ? part.plannedPages : part.actualPages}');
  final tests = TextEditingController(text: '${part.actualTests == 0 ? part.plannedTests : part.actualTests}');
  final note = TextEditingController(text: part.note);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ثبت نتیجه پارت ${faDigits(part.partNumber)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'وضعیت'),
          items: const [
            DropdownMenuItem(value: 'not_started', child: Text('انجام‌نشده')),
            DropdownMenuItem(value: 'partial', child: Text('نیمه‌انجام')),
            DropdownMenuItem(value: 'completed', child: Text('انجام‌شده')),
          ],
          onChanged: (v) => setState(() => status = v ?? status),
        ),
        const SizedBox(height: 12),
        _NumberField(controller: minutes, label: 'زمان واقعی (دقیقه)'),
        const SizedBox(height: 12),
        _NumberField(controller: pages, label: 'صفحات انجام‌شده'),
        const SizedBox(height: 12),
        _NumberField(controller: tests, label: 'تست انجام‌شده'),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت')),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          await controller.savePart(
            partId: part.id,
            status: status,
            minutes: int.tryParse(minutes.text) ?? 0,
            pages: int.tryParse(pages.text) ?? 0,
            tests: int.tryParse(tests.text) ?? 0,
            note: note.text.trim(),
          );
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نتیجه پارت ثبت شد')));
        }, child: const Text('ذخیره'))),
      ])),
    )),
  );
}

Future<void> _showDailyReportSheet(BuildContext context, AppController controller, PlanDay day, DailyReport? report) async {
  int? focus = (report?.values['focus'] as int?);
  int? energy = (report?.values['energy'] as int?);
  final reviewMinutes = TextEditingController(text: '${report?.values['actual_review_minutes'] ?? 0}');
  final achievement = TextEditingController(text: report?.values['achievement'] as String? ?? '');
  final deviation = TextEditingController(text: report?.values['deviation_reason'] as String? ?? '');
  final corrective = TextEditingController(text: report?.values['corrective_action'] as String? ?? '');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('گزارش پایان روز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('زمان واقعی: ${faDigits(report?.actualMinutes ?? 0)} دقیقه • صفحات: ${faDigits(report?.actualPages ?? 0)} • تست: ${faDigits(report?.actualTests ?? 0)}'),
        const SizedBox(height: 16),
        _NumberField(controller: reviewMinutes, label: 'دقیقه مرور و بازیابی واقعی'),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: focus, decoration: const InputDecoration(labelText: 'تمرکز از ۱ تا ۵'), items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text(faDigits(i + 1)))), onChanged: (v) => setState(() => focus = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: energy, decoration: const InputDecoration(labelText: 'انرژی از ۱ تا ۵'), items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text(faDigits(i + 1)))), onChanged: (v) => setState(() => energy = v)),
        const SizedBox(height: 12),
        TextField(controller: achievement, maxLines: 2, decoration: const InputDecoration(labelText: 'مهم‌ترین دستاورد امروز')),
        const SizedBox(height: 12),
        TextField(controller: deviation, maxLines: 2, decoration: const InputDecoration(labelText: 'مشکل یا علت انحراف')),
        const SizedBox(height: 12),
        TextField(controller: corrective, maxLines: 2, decoration: const InputDecoration(labelText: 'اقدام جبرانی یا برنامه فردا')),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          await controller.saveDailyReport(
            dayId: day.id,
            reviewMinutes: int.tryParse(reviewMinutes.text) ?? 0,
            focus: focus,
            energy: energy,
            achievement: achievement.text.trim(),
            deviation: deviation.text.trim(),
            corrective: corrective.text.trim(),
          );
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('گزارش روزانه ثبت شد')));
        }, child: const Text('ثبت گزارش روزانه'))),
      ])),
    )),
  );
}

Future<void> _showReviewSheet(BuildContext context, AppController controller, ReviewItem item) async {
  String? quality;
  String? speed;
  String? confidence;
  var conceptual = false;
  var retraining = false;
  final percent = TextEditingController();
  final note = TextEditingController();
  const qualities = ['غلط یا کمتر از ۵۰٪', 'ناقص یا همراه با حدس', 'درست ولی کند و مردد', 'درست، سریع و کامل'];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ثبت نتیجه مرور ${item.unitCode}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text('${item.subject} • ${item.chapterTitle} • ${item.pageRange}'),
        const SizedBox(height: 16),
        const Text('نتیجه بازیابی', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final q in qualities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(value: q, groupValue: quality, title: Text(q), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)), onChanged: (v) => setState(() => quality = v)),
          ),
        _NumberField(controller: percent, label: 'درصد پاسخ‌های صحیح'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: speed, decoration: const InputDecoration(labelText: 'سرعت پاسخ'), items: ['کند', 'متوسط', 'سریع'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => speed = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: confidence, decoration: const InputDecoration(labelText: 'میزان اطمینان'), items: ['کم', 'متوسط', 'زیاد'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => confidence = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('خطای مفهومی'), value: conceptual, onChanged: (v) => setState(() => conceptual = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('نیاز به بازآموزی'), value: retraining, onChanged: (v) => setState(() => retraining = v)),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت مرور')),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: quality == null ? null : () async {
          final correct = int.tryParse(percent.text);
          if (correct != null && (correct < 0 || correct > 100)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درصد باید بین صفر تا صد باشد')));
            return;
          }
          await controller.saveReview(stateId: item.id, quality: quality!, correctPercent: correct, speed: speed, confidence: confidence, conceptualError: conceptual, retraining: retraining, note: note.text.trim());
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مرور ثبت شد')));
        }, child: const Text('محاسبه و ثبت مرور'))),
      ])),
    )),
  );
}

Future<void> _confirmReset(BuildContext context, AppController controller) async {
  final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: const Text('بازنشانی اطلاعات'),
    content: const Text('تمام ثبت‌های فعلی حذف و داده‌های فایل اصلی دوباره وارد می‌شود. این عملیات قابل بازگشت نیست.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بازنشانی'))],
  ));
  if (ok == true) {
    await controller.resetData();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اطلاعات اولیه بازیابی شد')));
  }
}

Future<void> _confirmRestore(BuildContext context, AppController controller) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('بازیابی اطلاعات'),
      content: const Text(
        'اطلاعات فعلی با اطلاعات فایل پشتیبان جایگزین می‌شود. بهتر است قبل از ادامه یک پشتیبان جدید تهیه کنید.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('انتخاب فایل')),
      ],
    ),
  );
  if (ok != true) return;
  final result = await controller.restoreBackup();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.success ? 'اطلاعات پشتیبان بازیابی شد' : result.error ?? 'بازیابی انجام نشد')),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const Spacer(), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(title)])));
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 16), child])));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]);
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(text)]));
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) { 'completed' => scheme.primaryContainer, 'partial' => scheme.tertiaryContainer, _ => scheme.surfaceContainerHighest };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(_statusFa(status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text(label), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(text, textAlign: TextAlign.center)])));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 52), const SizedBox(height: 12), const Text('آماده‌سازی برنامه انجام نشد', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: onRetry, child: const Text('تلاش دوباره'))]));
}

String _statusFa(String status) => switch (status) { 'completed' => 'انجام‌شده', 'partial' => 'نیمه‌انجام', _ => 'انجام‌نشده' };
