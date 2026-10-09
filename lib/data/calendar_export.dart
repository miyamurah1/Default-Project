import 'mock_data.dart';

/// Dep-free calendar export: dated tasks as an RFC 5545 ICS feed the
/// user can import anywhere (Google/Apple/Outlook). No provider SDKs,
/// no OAuth, no sync daemon — a file the user owns, shared through
/// the OS sheet. Pure function, unit-tested.
String buildIcs(List<Task> tasks, {DateTime? now}) {  final stamp = _utc(now ?? DateTime.now());
  final buf = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Daily Bloom//Tasks//EN')
    ..writeln('CALSCALE:GREGORIAN');
  for (final t in tasks) {
    final due = t.dueAt;
    if (due == null) continue;
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${_esc(t.id)}@dailybloom')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${_utc(due)}')
      ..writeln('SUMMARY:${_esc(t.title)}')
      ..writeln('DESCRIPTION:${_esc('${t.folder} · ${t.tag}')}');
    if (t.status == 'done' && t.completedAt != null) {
      buf.writeln('COMPLETED:${_utc(t.completedAt!)}');
    }
    buf.writeln('END:VEVENT');
  }
  buf.writeln('END:VCALENDAR');
  return buf.toString();
}

/// Dated-task count (the UI's "nothing to export" gate).
int datedCount(List<Task> tasks) =>
    tasks.where((t) => t.dueAt != null).length;

String _utc(DateTime d) {
  final u = d.toUtc();
  String p(int n, [int w = 2]) => '$n'.padLeft(w, '0');
  return '${p(u.year, 4)}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
}

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// One planned work block: a task title plus its estimated minutes.
class PlanBlock {
  final String id;
  final String title;
  final int minutes;

  const PlanBlock({required this.id, required this.title, this.minutes = 25});
}

/// Time-block export: lays [blocks] back-to-back from [startHour] today
/// (defaulting to the user's peak hour) as DURATION-based events.
/// Same no-SDK file the dated-task export uses — import anywhere.
String buildPlanBlocks(
  List<PlanBlock> blocks, {
  DateTime? day,
  int startHour = 9,
}) {
  final base = day ?? DateTime.now();
  var cursor = DateTime(base.year, base.month, base.day, startHour.clamp(0, 23));
  final stamp = _utc(DateTime.now());
  final buf = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Daily Bloom//Plan//EN')
    ..writeln('CALSCALE:GREGORIAN');
  for (final b in blocks.take(10)) {
    final mins = b.minutes.clamp(5, 240);
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:plan-${_esc(b.id)}@dailybloom')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${_utc(cursor)}')
      ..writeln('DURATION:PT${mins}M')
      ..writeln('SUMMARY:${_esc(b.title)}')
      ..writeln('DESCRIPTION:${_esc('Planned by Daily Bloom · ~${mins}m')}')
      ..writeln('END:VEVENT');
    cursor = cursor.add(Duration(minutes: mins + 5));
  }
  buf.writeln('END:VCALENDAR');
  return buf.toString();
}
