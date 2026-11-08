import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin/src/mcp/local/pick_page.dart';
import 'package:fliin/src/mcp/local/selection_store.dart';
import 'package:fliin/src/mcp/ports.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

final _button = ItemRef('button', version: Version(0, 1, 0));
final _switch = ItemRef('switch', version: Version(0, 1, 0));
final _png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);

typedef _Response = ({int status, Map<String, String> headers, String body});

/// Une requête dont on choisit Host et Origin.
Future<_Response> _raw(
  Uri url, {
  String method = 'GET',
  String? host,
  Map<String, String> headers = const {},
  String body = '',
}) async {
  final http = HttpClient();
  try {
    final request = await http.openUrl(method, url)
      ..followRedirects = false;
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close();
    final text = utf8.decode([
      for (final chunk in await response.toList()) ...chunk,
    ], allowMalformed: true);
    return (
      status: response.statusCode,
      headers: {
        for (final name in [
          'content-type',
          'content-security-policy',
          'cache-control',
          'location',
          'x-frame-options',
          'x-content-type-options',
          'referrer-policy',
        ])
          name: ?response.headers.value(name),
      },
      body: text,
    );
  } finally {
    http.close();
  }
}

Map<String, String> _form(Uri url) => {
  'Content-Type': 'application/x-www-form-urlencoded',
  'Origin': 'http://127.0.0.1:${url.port}',
};

void main() {
  late MemorySelectionStore store;
  late LocalPickPage page;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 10, 19, 12);
    store = MemorySelectionStore(clock: () => now);
    page = LocalPickPage(
      store: store,
      describe: (ref, _) async => (
        title: ref.name == 'button' ? 'Bouton <principal>' : 'Interrupteur',
        description: 'Déclenche <b>une</b> action.',
        hasPreview: ref.name == 'button',
      ),
      preview: (ref, variant) async =>
          ref.name == 'button' && variant.id == 'android.dark.2.0.rtl'
          ? _png
          : null,
    );
    addTearDown(page.close);
  });

  Future<(Selection, Uri)> open({String question = 'Lequel ?'}) async {
    final selection = await store.open(
      candidates: [_button, _switch],
      question: question,
      variant: const GoldenVariant(
        platform: VariantPlatform.android,
        brightness: VariantBrightness.dark,
        scale: VariantScale.large,
        dir: VariantDirection.rtl,
      ),
    );
    return (selection, await page.pickUrl(selection.handle));
  }

  test('devrait montrer la question échappée, un libellé par candidat et l\'image de la variante quand on ouvre la page', () async {
    final (selection, url) = await open(
      question: 'Lequel <script>x</script> ?',
    );
    final response = await _raw(url);
    expect(response.status, 200);
    expect(
      response.headers['content-security-policy'],
      contains("default-src 'none'"),
    );
    expect(
      response.headers['content-security-policy'],
      contains("form-action 'self'"),
    );
    expect(response.headers['cache-control'], 'no-store');
    expect(response.headers['x-frame-options'], 'DENY');
    expect(
      response.headers['content-security-policy'],
      contains("frame-ancestors 'none'"),
    );
    expect(response.headers['x-content-type-options'], 'nosniff');
    expect(
      response.headers['referrer-policy'],
      'same-origin',
      reason: 'no-referrer fait envoyer Origin: null au POST du navigateur',
    );
    final html = response.body;
    expect(html, contains('<html lang="en">'));
    expect(
      html,
      contains('<h1>Lequel &lt;script&gt;x&lt;&#47;script&gt; ?</h1>'),
    );
    expect(html, isNot(contains('<script')));
    expect(html, isNot(matches(RegExp(r'''(src|href)="https?://'''))));
    expect(html, contains('<label for="c0">'));
    expect(html, contains('<label for="c1">'));
    expect(html, contains('Bouton &lt;principal&gt;'));
    expect(html, contains('Déclenche &lt;b&gt;une&lt;&#47;b&gt; action.'));
    expect(html, isNot(contains('<b>')));
    expect(
      html,
      contains(
        'alt="Preview of Bouton &lt;principal&gt;, Android, dark, '
        'text 2.0×, right to left"',
      ),
    );
    expect(html, contains('Android, dark, text 2.0×, right to left'));
    expect(
      html,
      contains('src="/preview/button/0.1.0/android.dark.2.0.rtl.png"'),
    );
    expect(html, contains('No reference image is published'));
    expect(html, contains('value="${selection.formToken}"'));

    final image = await _raw(
      url.replace(path: '/preview/button/0.1.0/android.dark.2.0.rtl.png'),
    );
    expect(image.status, 200);
    expect(image.headers['content-type'], 'image/png');
    expect(
      (await _raw(
        url.replace(path: '/preview/switch/0.1.0/android.dark.2.0.rtl.png'),
      )).status,
      404,
    );
    expect(
      (await _raw(url.replace(path: '/preview/button/0.1.0/x.png'))).status,
      404,
    );
  });

  test('devrait enregistrer le choix et rediriger vers l\'issue quand le POST porte le jeton de la page', () async {
    final (selection, url) = await open();
    final chosen = await _raw(
      url,
      method: 'POST',
      headers: _form(url),
      body: 'token=${selection.formToken}&action=choose&item=button',
    );
    expect(chosen.status, 303);
    expect(chosen.headers['location'], url.path);
    expect(
      ((await store.find(selection.handle))!.status as Chosen).item,
      ItemRef('button'),
    );
    expect((await _raw(url)).body, contains('Choice saved: Bouton'));

    final again = await _raw(
      url,
      method: 'POST',
      headers: _form(url),
      body: 'token=${selection.formToken}&action=decline',
    );
    expect(again.status, 303);
    expect(
      (await store.find(selection.handle))!.status,
      isA<Chosen>(),
      reason: 'le premier choix tient',
    );
  });

  test('devrait refuser un POST sans le jeton, d\'une autre origine ou hors des candidats', () async {
    final (selection, url) = await open();
    for (final (headers, body, status) in [
      (_form(url), 'action=choose&item=button', 403),
      (_form(url), 'token=faux&action=choose&item=button', 403),
      (
        {..._form(url), 'Origin': 'null'},
        'token=${selection.formToken}&action=choose&item=button',
        403,
      ),
      (
        {..._form(url), 'Origin': 'https://evil.example'},
        'token=${selection.formToken}&action=choose&item=button',
        403,
      ),
      (
        {..._form(url), 'Content-Type': 'text/plain'},
        'token=${selection.formToken}&action=choose&item=button',
        415,
      ),
      (_form(url), 'token=${selection.formToken}&action=choose&item=menu', 400),
    ]) {
      final response = await _raw(
        url,
        method: 'POST',
        headers: headers,
        body: body,
      );
      expect(response.status, status, reason: '$headers $body');
    }
    expect((await store.find(selection.handle))!.status, isA<Pending>());
  });

  test(
    'devrait refuser un Host qui n\'est pas la boucle locale du serveur',
    () async {
      final (_, url) = await open();
      expect((await _raw(url, host: 'evil.example')).status, 403);
      expect((await _raw(url, host: '127.0.0.1:1')).status, 403);
      expect((await _raw(url, host: 'localhost:${url.port}')).status, 200);
    },
  );

  test(
    'devrait rendre 404 quand la sélection a expiré au bout de trente minutes',
    () async {
      final (selection, url) = await open();
      now = now.add(const Duration(minutes: 30));
      expect((await _raw(url)).status, 404);
      final post = await _raw(
        url,
        method: 'POST',
        headers: _form(url),
        body: 'token=${selection.formToken}&action=decline',
      );
      expect(post.status, 404);
    },
  );

  test('devrait rendre une page d\'erreur HTML en français sous la même CSP quand la requête est refusée', () async {
    final (_, url) = await open();
    final refused = await _raw(url, host: 'evil.example');
    expect(refused.status, 403);
    expect(refused.headers['content-type'], startsWith('text/html'));
    expect(
      refused.headers['content-security-policy'],
      contains("default-src 'none'"),
    );
    expect(refused.body, contains('<html lang="en">'));
    expect(refused.body, contains('<h1>Host refused</h1>'));
  });

  test('devrait répondre 400 et rester en vie quand le chemin est mal encodé ou le POST coupé', () async {
    final (selection, url) = await open();
    Future<String> send(String text, {bool cut = false}) async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        url.port,
      );
      socket.write(text);
      if (cut) {
        await socket.flush();
        socket.destroy();
        return '';
      }
      final reply = utf8.decode([
        for (final chunk in await socket.toList()) ...chunk,
      ], allowMalformed: true);
      socket.destroy();
      return reply;
    }

    final host = 'Host: 127.0.0.1:${url.port}';
    expect(
      await send(
        'GET /pick/%E0%A4%A HTTP/1.1\r\n$host\r\nConnection: close\r\n\r\n',
      ),
      allOf(startsWith('HTTP/1.1 400'), contains('Bad request')),
    );
    final form = 'token=%E0%A4%A';
    expect(
      await send(
        'POST ${url.path} HTTP/1.1\r\n$host\r\n'
        'Content-Type: application/x-www-form-urlencoded\r\n'
        'Content-Length: ${form.length}\r\nConnection: close\r\n\r\n$form',
      ),
      allOf(startsWith('HTTP/1.1 400'), contains('Bad request')),
    );
    await send(
      'POST ${url.path} HTTP/1.1\r\n$host\r\n'
      'Content-Type: application/x-www-form-urlencoded\r\n'
      'Content-Length: 500\r\n\r\ntoken=${selection.formToken}',
      cut: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await _raw(url)).status, 200, reason: 'le serveur répond encore');
  });

  test('devrait enregistrer le choix quand le navigateur envoie l\'origine du serveur', () async {
    final (selection, url) = await open();
    final response = await _raw(
      url,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'http://localhost:${url.port}',
      },
      body: 'token=${selection.formToken}&action=choose&item=switch',
    );
    expect(response.status, 303);
    expect(
      ((await store.find(selection.handle))!.status as Chosen).item,
      ItemRef('switch'),
    );
  });

  test('devrait répondre 500 et non 400 quand l\'erreur vient du serveur et pas de la requête', () async {
    final broken = LocalPickPage(
      store: store,
      describe: (_, _) async =>
          throw const FormatException('manifeste illisible'),
      preview: (_, _) async => null,
    );
    addTearDown(broken.close);
    final selection = await store.open(
      candidates: [_button, _switch],
      question: 'Lequel ?',
      variant: const GoldenVariant(),
    );
    final response = await _raw(await broken.pickUrl(selection.handle));
    expect(response.status, 500);
    expect(response.body, contains('Internal error'));
    expect(response.body, isNot(contains('Bad request')));
  });
}
