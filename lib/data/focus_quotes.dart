import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Daily motivational lines for the focus timer. Unattributed short
/// zen lines (no misattributed masters). Pure functions so the pick is
/// deterministic and unit-testable.
const _focusQuotes = [
  'One task, fully here.',
  'Still water runs deep.',
  'Begin again, gently.',
  'Small steps every day.',
  'The bamboo bends; it does not break.',
  'Where attention goes, the bloom follows.',
  'Do the next right thing, slowly.',
  'A quiet mind finishes more.',
];

const _breakQuotes = [
  'Rest is part of the work.',
  'Step away; return clearer.',
  'Tea first, tasks after.',
  'Breathe out. The work will wait.',
  'A field that rests gives a better harvest.',
  'Loosen your shoulders, unclench your jaw.',
];

/// Quote of the day: stable all day, rotates daily. [mode] selects the
/// shelf ('focus' vs anything else → break lines).
String focusQuoteFor(DateTime day, String mode) {
  final shelf = mode == 'focus' ? _focusQuotes : _breakQuotes;
  final dayOfYear =
      day.difference(DateTime(day.year, 1, 1)).inDays;
  return shelf[dayOfYear % shelf.length];
}

/// Free quote API (no key): one random attributed line per call.
/// Throws nothing — any failure (offline, timeout, bad payload)
/// falls back to a local zen line, avoiding [notEqualTo] when it can.
Future<String> fetchRandomQuote({http.Client? client, String? notEqualTo}) async {
  final c = client ?? http.Client();
  try {
    return await _fetchRandomQuote(c, notEqualTo);
  } finally {
    if (client == null) c.close();
  }
}

Future<String> _fetchRandomQuote(http.Client c, String? notEqualTo) async {
  try {
    final res = await c
        .get(Uri.parse('https://dummyjson.com/quotes/random'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final j = json.decode(res.body);
      if (j is Map) {
        final text = '${j['quote'] ?? ''}'.trim();
        final by = '${j['author'] ?? ''}'.trim();
        if (text.isNotEmpty && text != notEqualTo) {
          return by.isEmpty ? text : '$text — $by';
        }
      }
    }
  } catch (_) {
    // Offline or API hiccup: fall through to the local shelf.
  }
  return _localFallback(notEqualTo);
}

/// Local shelf fallback: random line unlike [notEqualTo] when possible.
String _localFallback(String? notEqualTo) {
  final all = [..._focusQuotes, ..._breakQuotes]
      .where((q) => q != notEqualTo)
      .toList();
  final pool = all.isEmpty ? [..._focusQuotes, ..._breakQuotes] : all;
  return pool[Random().nextInt(pool.length)];
}
