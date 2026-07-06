import 'dart:convert';

import 'package:flutter_localisation/src/management/exceptions.dart';
import 'package:flutter_localisation/src/management/management_client.dart';
import 'package:flutter_localisation/src/management/project_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

ManagementClient clientWith(final List<Map<String, dynamic>> projects) {
  final MockClient mock = MockClient((final http.Request req) async {
    if (req.url.path == '/api/projects/') {
      return http.Response(
        jsonEncode(<String, dynamic>{'projects': projects}),
        200,
      );
    }
    return http.Response('not found', 404);
  });
  return ManagementClient(
    baseUrl: 'http://test',
    token: 'flk_live_x',
    httpClient: mock,
  );
}

Map<String, dynamic> project(
  final int id,
  final String name,
  final List<Map<String, dynamic>> flavors,
) =>
    <String, dynamic>{'id': id, 'name': name, 'workspace': 'WS', 'flavors': flavors};

Map<String, dynamic> flavor(final String name, final List<String> locales) =>
    <String, dynamic>{'name': name, 'base_language': locales.first, 'languages': locales};

void main() {
  test('single project + single flavor resolves with no selectors', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(7, 'Shopping App', <Map<String, dynamic>>[
        flavor('production', <String>['en', 'fr']),
      ]),
    ]));
    final ResolvedTarget t = await r.resolve();
    expect(t.projectId, 7);
    expect(t.projectName, 'Shopping App');
    expect(t.flavor, 'production');
  });

  test('resolves by name (case-insensitive)', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(1, 'Alpha', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
      project(2, 'Beta', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
    ]));
    final ResolvedTarget t = await r.resolve(project: 'beta');
    expect(t.projectId, 2);
  });

  test('resolves by numeric id', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(1, 'Alpha', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
      project(2, 'Beta', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
    ]));
    final ResolvedTarget t = await r.resolve(project: '1');
    expect(t.projectName, 'Alpha');
  });

  test('unknown project throws with the available list', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(1, 'Alpha', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
    ]));
    expect(
      () => r.resolve(project: 'Nope'),
      throwsA(isA<ResolveException>()),
    );
  });

  test('multiple projects without a selector throws', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(1, 'Alpha', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
      project(2, 'Beta', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
    ]));
    expect(() => r.resolve(), throwsA(isA<ResolveException>()));
  });

  test('multiple flavors without a flavor throws; specifying one works', () async {
    final ProjectResolver r = ProjectResolver(clientWith(<Map<String, dynamic>>[
      project(3, 'Multi', <Map<String, dynamic>>[
        flavor('production', <String>['en', 'fr']),
        flavor('staging', <String>['en']),
      ]),
    ]));
    expect(() => r.resolve(project: 'Multi'), throwsA(isA<ResolveException>()));
    final ResolvedTarget t = await r.resolve(project: 'Multi', flavor: 'staging');
    expect(t.flavor, 'staging');
  });

  test('default project selector is used when no arg passed', () async {
    final ProjectResolver r = ProjectResolver(
      clientWith(<Map<String, dynamic>>[
        project(1, 'Alpha', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
        project(2, 'Beta', <Map<String, dynamic>>[flavor('default', <String>['en'])]),
      ]),
      defaultProject: 'Beta',
    );
    final ResolvedTarget t = await r.resolve();
    expect(t.projectId, 2);
  });
}
