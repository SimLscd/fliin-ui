import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import 'support.dart';

const _token = 'jeton-de-test-selection';
const _question = 'Quel bouton pour valider le formulaire ?';
const _candidates = ['button', 'switch'];

/// Ce que DESIGN.md §5.3 attend d'un client : le mode URL seulement s'il le
/// déclare dans une ère qui le connaît.
enum _Route { inputRequired, urlError, pickUrl }

_Route _expected(String era, {required bool url}) => switch ((era, url)) {
  ('2026-07-28', true) => _Route.inputRequired,
  ('2025-11-25', true) => _Route.urlError,
  _ => _Route.pickUrl,
};

void main() {
  late TestDist dist;
  late int port;

  setUpAll(() async {
    dist = await buildTestDist();
    port = (await startHttpServer(dist, _token)).port;
  });

  for (final transport in ['stdio', 'http']) {
    for (final era in eras) {
      for (final url in [true, false]) {
        final route = _expected(era, url: url);
        final declared = url
            ? 'déclare elicitation.url'
            : 'déclare une élicitation vide';
        test(
          'devrait passer par ${route.name} puis rendre chosen quand un client $era $declared en $transport',
          () async {
            final elicited = <ElicitRequest>[];
            final client = eraClient(
              era,
              url: url,
              onElicit: (request) async {
                elicited.add(request);
                expect(await humanAnswers(request.url!, item: 'button'), 303);
                return const ElicitResult(action: 'accept');
              },
            );
            await client.connect(
              transport == 'stdio'
                  ? await stdioTransport(dist)
                  : httpTransport(port, _token),
            );
            addTearDown(client.close);
            expect(client.getProtocolVersion(), era);

            const open = CallToolRequest(
              name: 'request_selection',
              arguments: {
                'candidates': _candidates,
                'question': _question,
                'variant': {'brightness': 'dark', 'dir': 'rtl'},
              },
            );
            switch (route) {
              case _Route.inputRequired:
                final result = await client.callTool(open);
                expect(elicited.single.isUrlMode, isTrue);
                expect(elicited.single.message, _question);
                expect(result.structuredContent, {
                  'selectionHandle': isNotEmpty,
                  'status': 'chosen',
                  'chosen': 'button',
                  'pickUrl': elicited.single.url,
                });
              case _Route.urlError:
                final error = await client
                    .callTool(open)
                    .then<McpError>(
                      (_) => fail('−32042 attendue'),
                      onError: (Object e) => e as McpError,
                    );
                expect(error.code, ErrorCode.urlElicitationRequired.value);
                final data = URLElicitationRequiredErrorData.fromJson(
                  Map<String, dynamic>.from(error.data as Map),
                );
                final pickUrl = data.elicitations.single.url!;
                expect(data.elicitations.single.message, _question);
                expect(await humanAnswers(pickUrl, item: 'button'), 303);
                final retried = await client.callTool(open);
                expect(retried.structuredContent?['status'], 'chosen');
                expect(retried.structuredContent?['chosen'], 'button');
                expect(retried.structuredContent?['pickUrl'], pickUrl);
              case _Route.pickUrl:
                final result = await client.callTool(open);
                expect(elicited, isEmpty);
                final opened = result.structuredContent!;
                expect(opened['status'], 'pending');
                expect(opened['chosen'], isNull);
                final pickUrl = opened['pickUrl']! as String;
                expect(
                  pickUrl,
                  matches(RegExp(r'^http://127\.0\.0\.1:\d+/pick/[\w-]{22}$')),
                );
                expect(
                  result.content.whereType<ImageContent>().map(
                    (i) => i.mimeType,
                  ),
                  ['image/png', 'image/png'],
                  reason: 'une image de référence par candidat',
                );
                expect(await humanAnswers(pickUrl, item: 'button'), 303);
                final read = await client.callTool(
                  CallToolRequest(
                    name: 'request_selection',
                    arguments: {'selectionHandle': opened['selectionHandle']},
                  ),
                );
                expect(read.structuredContent, {
                  ...opened,
                  'status': 'chosen',
                  'chosen': 'button',
                });
            }
          },
        );
      }
    }
  }

  test('devrait rendre declined quand l\'humain refuse l\'élicitation URL en 2026-07-28', () async {
    final client = eraClient(
      '2026-07-28',
      url: true,
      onElicit: (_) async => const ElicitResult(action: 'decline'),
    );
    await client.connect(await stdioTransport(dist));
    addTearDown(client.close);
    final result = await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {'candidates': _candidates, 'question': _question},
      ),
    );
    expect(result.structuredContent?['status'], 'declined');
  });

  test('devrait rendre declined quand l\'humain refuse sur la page', () async {
    final client = eraClient('2025-06-18');
    await client.connect(httpTransport(port, _token));
    addTearDown(client.close);
    final opened = (await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {'candidates': _candidates, 'question': _question},
      ),
    )).structuredContent!;
    expect(await humanAnswers(opened['pickUrl']! as String), 303);
    final read = await client.callTool(
      CallToolRequest(
        name: 'request_selection',
        arguments: {'selectionHandle': opened['selectionHandle']},
      ),
    );
    expect(read.structuredContent?['status'], 'declined');
    expect(read.structuredContent?['chosen'], isNull);
  });

  test('devrait rendre NOT_FOUND quand la poignée est inconnue ou qu\'un candidat n\'existe pas', () async {
    final client = eraClient('2026-07-28');
    await client.connect(await stdioTransport(dist));
    addTearDown(client.close);
    final unknown = await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {'selectionHandle': 'AAAAAAAAAAAAAAAAAAAAAA'},
      ),
    );
    expect(unknown.isError, isTrue);
    expect(textJson(unknown)['code'], 'NOT_FOUND');
    final missing = await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {
          'candidates': ['button', 'absent'],
          'question': _question,
        },
      ),
    );
    expect(missing.isError, isTrue);
    expect(textJson(missing)['details'], {
      'missing': ['absent'],
    });
  });

  test('devrait rendre pending avec la consigne de relire quand le client accepte l\'URL avant que l\'humain choisisse en 2026-07-28', () async {
    final client = eraClient(
      '2026-07-28',
      url: true,
      onElicit: (_) async => const ElicitResult(action: 'accept'),
    );
    await client.connect(await stdioTransport(dist));
    addTearDown(client.close);
    final accepted = await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {'candidates': _candidates, 'question': _question},
      ),
    );
    final state = accepted.structuredContent!;
    expect(state['status'], 'pending');
    expect(
      (accepted.content.last as TextContent).text,
      contains('selectionHandle: "${state['selectionHandle']}"'),
    );
    expect(
      await humanAnswers(state['pickUrl']! as String, item: 'switch'),
      303,
    );
    final read = await client.callTool(
      CallToolRequest(
        name: 'request_selection',
        arguments: {'selectionHandle': state['selectionHandle']},
      ),
    );
    expect(read.structuredContent?['chosen'], 'switch');
  });

  test('devrait reconnaître le rejeu après −32042 quand les arguments reviennent dans un autre ordre', () async {
    final client = eraClient('2025-11-25', url: true);
    await client.connect(await stdioTransport(dist));
    addTearDown(client.close);
    final error = await client
        .callTool(
          const CallToolRequest(
            name: 'request_selection',
            arguments: {
              'candidates': _candidates,
              'question': _question,
              'variant': {'dir': 'rtl', 'brightness': 'dark'},
            },
          ),
        )
        .then<McpError>(
          (_) => fail('−32042 attendue'),
          onError: (Object e) => e as McpError,
        );
    final pickUrl = URLElicitationRequiredErrorData.fromJson(
      Map<String, dynamic>.from(error.data as Map),
    ).elicitations.single.url!;
    expect(await humanAnswers(pickUrl, item: 'button'), 303);
    final retried = await client.callTool(
      const CallToolRequest(
        name: 'request_selection',
        arguments: {
          'variant': {'brightness': 'dark', 'dir': 'rtl'},
          'question': _question,
          'candidates': _candidates,
        },
      ),
    );
    expect(retried.structuredContent?['chosen'], 'button');
  });
}
