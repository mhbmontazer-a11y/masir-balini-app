import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled seed contains the complete professional plan', () async {
    final file = File('assets/seed/normalized_seed_v2.json');
    expect(await file.exists(), isTrue);
    final seed = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final days = (seed['planDays'] as List<dynamic>).cast<Map<String, dynamic>>();
    final units = (seed['studyUnits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final weeks = (seed['weeklyReports'] as List<dynamic>);

    expect(days.length, 81);
    expect(units.length, 180);
    expect(weeks.length, 12);
    expect(days.fold<int>(0, (sum, item) => sum + (item['totalMinutes'] as num).toInt()), 19440);
    expect(days.fold<int>(0, (sum, item) => sum + (item['totalNewPages'] as num).toInt()), 2075);
    expect(days.fold<int>(0, (sum, item) => sum + (item['totalTests'] as num).toInt()), 1377);
    expect(units.first['unitCode'], 'U001');
    expect(units.last['unitCode'], 'U180');
    expect(units.map((e) => e['unitCode']).toSet().length, 180);
  });
}
