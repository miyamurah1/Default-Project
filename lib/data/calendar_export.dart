import 'mock_data.dart';

/// Dep-free calendar export: dated tasks as an RFC 5545 ICS feed the
/// user can import anywhere (Google/Apple/Outlook). No provider SDKs,
/// no OAuth, no sync daemon — a file the user owns, shared through
/// the OS sheet. Pure function, unit-tested.
String buildIcs(List<Task> tasks, {DateTime? now}) {
  final stamp = _utc(now ?? DateTime.now());
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
