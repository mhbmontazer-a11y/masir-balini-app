import 'package:shamsi_date/shamsi_date.dart';

const _faDigits = '۰۱۲۳۴۵۶۷۸۹';

String faDigits(Object? value) {
  final text = value?.toString() ?? '';
  return text.replaceAllMapped(RegExp(r'[0-9]'), (m) => _faDigits[int.parse(m.group(0)!)]);
}

String faNumber(num value, {int fraction = 0}) {
  final fixed = value.toStringAsFixed(fraction);
  final parts = fixed.split('.');
  final chars = parts.first.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add('٬');
    grouped.add(chars[i]);
  }
  final integer = grouped.reversed.join();
  final result = parts.length == 1 ? integer : '$integer٫${parts[1]}';
  return faDigits(result);
}

String faPercent(num? value, {int fraction = 0}) {
  if (value == null) return '—';
  return '${faNumber(value * 100, fraction: fraction)}٪';
}

String jalaliFromIso(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  final j = Jalali.fromDateTime(date);
  return faDigits('${j.year.toString().padLeft(4, '0')}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');
}

String compactMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${faDigits(m)} دقیقه';
  if (m == 0) return '${faDigits(h)} ساعت';
  return '${faDigits(h)} ساعت و ${faDigits(m)} دقیقه';
}
