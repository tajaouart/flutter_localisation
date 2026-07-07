import 'dart:convert';

import 'package:flutter_localisation/src/management/management_client.dart';
import 'package:flutter_localisation/src/management/operations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('delete without locale calls the whole-key delete endpoint', () async {
    final List<String> hits = <String>[];
    final MockClient mock = MockClient((final http.Request req) async {
      hits.add('${req.method} ${req.url.path}');
      return http.Response(jsonEncode(<String, dynamic>{'status': 'success'}), 200);
    });
    final ManagementClient client =
        ManagementClient(baseUrl: 'http://t', token: 'flk_live_x', httpClient: mock);
    final OpResult r =
        await Operations(client, 7, flavor: 'default').delete('greeting');
    expect(r.ok, isTrue);
    expect(hits, contains('POST /api/projects/7/translation_keys/delete/'));
    // Must NOT fetch the project or hit per-translation delete for a whole-key delete.
    expect(hits.where((final h) => h.contains('/api/projects/7/')).length, 1);
  });

  test('delete with a locale removes only that translation', () async {
    final List<String> hits = <String>[];
    final MockClient mock = MockClient((final http.Request req) async {
      hits.add('${req.method} ${req.url.path}');
      if (req.url.path == '/api/projects/7/') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 7,
            'name': 'P',
            'flavors': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'default',
                'languages': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'code': 'fr',
                    'is_base_language': false,
                    'translations': <Map<String, dynamic>>[
                      <String, dynamic>{'id': 42, 'key': 'greeting', 'value': 'Salut'},
                    ],
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response(jsonEncode(<String, dynamic>{'status': 'success'}), 200);
    });
    final ManagementClient client =
        ManagementClient(baseUrl: 'http://t', token: 'flk_live_x', httpClient: mock);
    final OpResult r = await Operations(client, 7, flavor: 'default')
        .delete('greeting', locale: 'fr');
    expect(r.ok, isTrue);
    expect(hits, contains('DELETE /api/translations/42/delete/'));
    expect(hits.any((final h) => h.contains('translation_keys/delete')), isFalse);
  });
}
