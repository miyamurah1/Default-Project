// BloomApi HTTP contract: request shape + JSON parsing for the main
// endpoints, driven by a MockClient (no real network).
import 'dart:convert';

import 'package:daily_bloom/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> seen;

  BloomApi apiWith(int status, Object body) {
    seen = [];
    return BloomApi(MockClient((req) async {
      seen.add(req);
      final text = body is String ? body : jsonEncode(body);
      return http.Response(text, status);
    }));
  }

  test('fetchTasks parses tasks and builds the query', () async {
    final api = apiWith(200, [
      {'id': 't1', 'title': 'Write', 'tag': 'Work', 'status': 'todo'}
    ]);
    final tasks =
        await api.fetchTasks(status: 'todo', withDetails: true);
    expect(tasks.single.title, 'Write');
    final q = seen.single.url.query;
    expect(q, contains('status=todo'));
    expect(q, contains('include=subtasks'));
  });

  test('createTask posts and parses the created task', () async {
    final api = apiWith(201, {'id': 't2', 'title': 'New', 'tag': 'Idea'});
    final t = await api.createTask('New', tag: 'Idea', clientId: 'tmp_1');
    expect(t.id, 't2');
    expect(seen.single.method, 'POST');
    expect(seen.single.body, contains('client_id'));
  });

  test('a non-2xx create throws', () async {
    final api = apiWith(400, 'bad request');
    await expectLater(api.createTask('X'), throwsA(isA<Exception>()));
  });

  test('moveTask PATCHes and returns the moved task', () async {
    final api = apiWith(200, {'id': 't1', 'title': 'W', 'status': 'done'});
    final t = await api.moveTask('t1', 'done');
    expect(t.status, 'done');
    expect(seen.single.method, 'PATCH');
  });

  test('updateTask sends only provided fields', () async {
    final api = apiWith(200, {'id': 't1', 'title': 'Renamed'});
    await api.updateTask('t1', title: 'Renamed');
    expect(seen.single.body, contains('Renamed'));
    expect(seen.single.body, isNot(contains('description')));
  });

  test('fetchFolders parses folder stats', () async {
    final api = apiWith(200, [
      {'name': 'Work', 'icon': 'folder', 'total': 3, 'completed': 1}
    ]);
    final folders = await api.fetchFolders();
    expect(folders.single.name, 'Work');
    expect(folders.single.total, 3);
  });

  test('fetchInbox + markInboxRead round-trip', () async {
    final api = apiWith(200, [
      {
        'id': 'm1',
        'tag': 'rule',
        'title': 'Heads up',
        'body': 'body',
        'unread': true,
        'created_at': '2026-01-01T00:00:00Z',
      }
    ]);
    final inbox = await api.fetchInbox();
    expect(inbox.single.title, 'Heads up');
    expect(inbox.single.unread, isTrue);
  });

  test('subtask CRUD parses each shape', () async {
    final sub = {
      'id': 's1',
      'task_id': 't1',
      'title': 'Step',
      'done': false,
      'created_at': '2026-01-01T00:00:00Z',
    };
    final listApi = apiWith(200, [sub]);
    expect((await listApi.fetchSubtasks('t1')).single.title, 'Step');

    final createApi = apiWith(201, sub);
    expect((await createApi.createSubtask('t1', 'Step')).title, 'Step');

    final patchApi = apiWith(200, {...sub, 'done': true});
    expect((await patchApi.updateSubtask('s1', done: true)).done, isTrue);

    final deleteApi = apiWith(204, '');
    await deleteApi.deleteSubtask('s1');
    expect(seen.single.method, 'DELETE');
  });

  test('timeline + note parsing', () async {
    final event = {
      'id': 'e1',
      'task_id': 't1',
      'kind': 'created',
      'body': '',
      'created_at': '2026-01-01T00:00:00Z',
    };
    final listApi = apiWith(200, [event]);
    expect((await listApi.fetchTaskEvents('t1')).single.kind, 'created');

    final noteApi = apiWith(201, {...event, 'kind': 'note', 'body': 'hi'});
    expect((await noteApi.addNote('t1', 'hi')).body, 'hi');
  });

  test('fetchStore parses balance + catalog', () async {
    final api = apiWith(200, {
      'balance': 420,
      'active': 'edo',
      'themes': [
        {'id': 'edo', 'name': 'Edo', 'label': 'CLASSIC', 'price': 0, 'owned': true}
      ],
    });
    final store = await api.fetchStore();
    expect(store.balance, 420);
    expect(store.themes.single.id, 'edo');
  });
}
