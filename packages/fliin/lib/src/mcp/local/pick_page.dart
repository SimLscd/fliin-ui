import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';

import '../ports.dart';

/// Ce que la page montre d'un candidat.
typedef CandidateView = ({String title, String description, bool hasPreview});

/// La page de choix de `request_selection` et les images de `previewUrl`,
/// servies par `fliin mcp` sur 127.0.0.1, port éphémère, démarrées au
/// premier besoin (ADR 0001 §4.4 point 6 : pas de page hébergée en V1).
///
/// Ce qui la protège : l'hôte doit être celui du serveur (une page qui
/// rebinde son nom de domaine sur 127.0.0.1 est refusée), un POST doit venir
/// de cette origine et porter le jeton que seule la page connaît, et la
/// poignée de 128 bits dans l'URL ne se devine pas.
final class LocalPickPage {
  LocalPickPage({
    required this.store,
    required this.describe,
    required this.preview,
  });

  final SelectionStore store;

  /// [ref] porte sa version ; `hasPreview` vaut pour [variant]. Nul quand le
  /// registre ne sert pas son manifeste.
  final Future<CandidateView?> Function(ItemRef ref, GoldenVariant variant)
  describe;

  /// Le golden de référence vérifié par empreinte ; nul sans golden ou
  /// quand le registre ne le sert pas.
  final Future<Uint8List?> Function(ItemRef ref, GoldenVariant variant) preview;

  Future<HttpServer>? _server;

  Future<Uri> pickUrl(SelectionHandle handle) async =>
      (await _origin()).replace(path: '/pick/${handle.value}');

  Future<Uri> previewUrl(ItemRef ref, GoldenVariant variant) async =>
      (await _origin()).replace(pathSegments: _previewSegments(ref, variant));

  Future<void> close() async {
    final server = _server;
    _server = null;
    if (server != null) await (await server).close(force: true);
  }

  Future<Uri> _origin() async =>
      Uri.http('127.0.0.1:${(await (_server ??= _bind())).port}');

  Future<HttpServer> _bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      (request) => _handle(request, server.port),
      onError: (Object error) => stderr.writeln('fliin mcp, page: $error'),
    );
    return server;
  }

  /// Aucune requête, même mal formée ou coupée, ne fait tomber `fliin mcp` :
  /// une page web quelconque peut viser ce port par une balise `<img>`.
  Future<void> _handle(HttpRequest request, int port) async {
    final response = request.response
      ..headers.set('X-Content-Type-Options', 'nosniff')
      // `no-referrer` ferait envoyer `Origin: null` au POST du formulaire.
      ..headers.set('Referrer-Policy', 'same-origin')
      ..headers.set('X-Frame-Options', 'DENY');
    try {
      await _route(request, response, port);
    } on Object catch (error) {
      stderr.writeln('fliin mcp, page: ${request.method}: $error');
      try {
        if (error is _BadRequest) {
          _error(response, HttpStatus.badRequest, 'Bad request');
        } else {
          _error(response, HttpStatus.internalServerError, 'Internal error');
        }
      } on Object {
        // Les en-têtes sont déjà partis, ou la connexion est fermée.
      }
    }
    await response.close().then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> _route(
    HttpRequest request,
    HttpResponse response,
    int port,
  ) async {
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (host != '127.0.0.1:$port' && host != 'localhost:$port') {
      return _error(response, HttpStatus.forbidden, 'Host refused');
    }
    final List<String> path;
    try {
      path = request.uri.pathSegments;
    } on Object catch (e) {
      throw _BadRequest(e);
    }
    switch ((request.method, path)) {
      case ('GET', ['pick', final handle]):
        await _show(response, SelectionHandle(handle));
      case ('POST', ['pick', final handle]):
        final origin = request.headers.value('origin');
        if (origin != null &&
            origin != 'http://127.0.0.1:$port' &&
            origin != 'http://localhost:$port') {
          return _error(response, HttpStatus.forbidden, 'Origin refused');
        }
        await _decide(request, response, SelectionHandle(handle));
      case ('GET', ['preview', final ref, final version, final file]):
        await _image(response, ref, version, file);
      case _:
        _error(response, HttpStatus.notFound, 'Not found');
    }
  }

  Future<void> _show(HttpResponse response, SelectionHandle handle) async {
    final selection = await store.find(handle);
    if (selection == null) {
      return _html(response, HttpStatus.notFound, _expiredPage);
    }
    final views = [
      for (final ref in selection.candidates)
        (ref, await describe(ref, selection.variant)),
    ];
    _html(response, HttpStatus.ok, pickPage(selection, views));
  }

  Future<void> _decide(
    HttpRequest request,
    HttpResponse response,
    SelectionHandle handle,
  ) async {
    final selection = await store.find(handle);
    if (selection == null) {
      return _html(response, HttpStatus.notFound, _expiredPage);
    }
    if (request.headers.contentType?.mimeType !=
        'application/x-www-form-urlencoded') {
      return _error(response, HttpStatus.unsupportedMediaType, 'Form expected');
    }
    final body = BytesBuilder(copy: false);
    final Map<String, String> fields;
    try {
      await for (final chunk in request) {
        body.add(chunk);
        if (body.length > _maxForm) {
          return _error(
            response,
            HttpStatus.requestEntityTooLarge,
            'Form too long',
          );
        }
      }
      fields = Uri.splitQueryString(
        utf8.decode(body.takeBytes(), allowMalformed: true),
      );
    } on Object catch (e) {
      throw _BadRequest(e);
    }
    if (!secretsMatch(fields['token'] ?? '', selection.formToken)) {
      return _error(response, HttpStatus.forbidden, 'Page token missing');
    }
    final SelectionOutcome outcome;
    switch ((fields['action'], fields['item'])) {
      case ('decline', _):
        outcome = const Declined();
      case ('choose', final String id)
          when selection.candidates.any((ref) => _bare(ref).toString() == id):
        outcome = Chosen(ItemRef.parse(id));
      case _:
        return _error(response, HttpStatus.badRequest, 'Unknown choice');
    }
    await store.settle(handle, outcome);
    response
      ..statusCode = HttpStatus.seeOther
      ..headers.set(HttpHeaders.locationHeader, '/pick/${handle.value}');
  }

  Future<void> _image(
    HttpResponse response,
    String ref,
    String version,
    String file,
  ) async {
    final variant = GoldenVariant.all
        .where((variant) => file == '${variant.id}.png')
        .firstOrNull;
    final ItemRef item;
    try {
      item = ItemRef.parseUnversioned(ref).at(Version.parse(version));
    } on FormatException {
      return _error(response, HttpStatus.notFound, 'Not found');
    }
    final png = variant == null ? null : await preview(item, variant);
    if (png == null) {
      return _error(response, HttpStatus.notFound, 'No reference golden');
    }
    response
      ..headers.contentType = ContentType('image', 'png')
      ..headers.set(HttpHeaders.cacheControlHeader, 'private, max-age=3600')
      ..add(png);
  }

  static void _error(HttpResponse response, int status, String message) =>
      _html(
        response,
        status,
        _document(message, '<h1>${_escape.convert(message)}</h1>'),
      );

  static void _html(HttpResponse response, int status, String html) => response
    ..statusCode = status
    ..headers.contentType = ContentType.html
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..headers.set('Content-Security-Policy', _csp)
    ..write(html);

  static const _maxForm = 4096;
}

/// Une requête que la page ne sait pas lire : URI, corps ou formulaire mal
/// encodés, ou corps coupé. Toute autre erreur est interne.
final class _BadRequest implements Exception {
  const _BadRequest(this.cause);

  final Object cause;

  @override
  String toString() => 'bad request: $cause';
}

/// Compare deux secrets en temps constant pour une longueur donnée.
bool secretsMatch(String presented, String expected) {
  if (presented.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= presented.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return diff == 0;
}

ItemRef _bare(ItemRef ref) => ItemRef(ref.name, namespace: ref.namespace);

List<String> _previewSegments(ItemRef ref, GoldenVariant variant) => [
  'preview',
  '${_bare(ref)}',
  '${ref.version}',
  '${variant.id}.png',
];

const _escape = HtmlEscape();

/// La page d'une sélection : le formulaire tant qu'elle attend, l'issue
/// ensuite. Sans script, sans ressource externe.
String pickPage(
  Selection selection,
  List<(ItemRef, CandidateView?)> candidates,
) {
  final question = _escape.convert(selection.question);
  final body = switch (selection.status) {
    Pending() => _form(selection, candidates),
    Chosen(:final item) =>
      '<p role="status">Choice saved: '
          '${_escape.convert(_title(candidates, item))}. You can close this '
          'tab. The agent will read your answer.</p>',
    Declined() =>
      '<p role="status">Saved: none of the candidates fits. '
          'You can close this tab. The agent will read your answer.</p>',
  };
  return _document(question, '<h1>$question</h1>\n$body');
}

String _title(List<(ItemRef, CandidateView?)> candidates, ItemRef chosen) {
  for (final (ref, view) in candidates) {
    if (_bare(ref) == chosen && view != null) return '${view.title} ($chosen)';
  }
  return '$chosen';
}

String _form(Selection selection, List<(ItemRef, CandidateView?)> candidates) {
  final expires = selection.expires.toLocal();
  final time =
      '${expires.hour.toString().padLeft(2, '0')}:'
      '${expires.minute.toString().padLeft(2, '0')}';
  final items = [
    for (final (i, (ref, view)) in candidates.indexed)
      _candidate(i, ref, view, selection.variant),
  ].join('\n');
  return '''
<p class="note">Previews: ${selection.variant.label}. An agent is waiting for your answer. This page expires at $time.</p>
<form method="post" action="/pick/${_escape.convert(selection.handle.value)}">
<input type="hidden" name="token" value="${_escape.convert(selection.formToken)}">
<fieldset>
<legend>Candidates</legend>
<ul>
$items
</ul>
</fieldset>
<div class="actions">
<button type="submit" name="action" value="choose">Choose this item</button>
<button type="submit" name="action" value="decline" formnovalidate class="secondary">None of them fits</button>
</div>
</form>''';
}

String _candidate(
  int index,
  ItemRef ref,
  CandidateView? view,
  GoldenVariant variant,
) {
  final id = _escape.convert('${_bare(ref)}');
  final title = _escape.convert(view?.title ?? '${_bare(ref)}');
  final description = _escape.convert(
    view?.description ?? 'This version is no longer in the registry.',
  );
  final image = view != null && view.hasPreview
      ? '<img src="/${_previewSegments(ref, variant).map(Uri.encodeComponent).join('/')}" '
            'alt="Preview of $title, ${variant.label}">'
      : '<span class="missing">No reference image is published for this '
            'version. Choose from the description.</span>';
  return '<li><input type="radio" name="item" id="c$index" value="$id" '
      'required>\n<label for="c$index"><span class="title">$title</span>'
      '<span class="id">$id</span><span class="desc">$description</span>'
      '$image</label></li>';
}

final _expiredPage = _document(
  'Selection not found',
  '<h1>Selection not found or expired</h1>\n<p>A selection expires '
      'thirty minutes after it opens. Ask the agent to open a new one.</p>',
);

String _document(String title, String main) =>
    '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>$_css</style>
</head>
<body>
<main>
$main
</main>
</body>
</html>
''';

const _css =
    ':root{color-scheme:light}'
    'body{margin:0;background:#fff;color:#111827;'
    'font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}'
    'main{max-width:64rem;margin:0 auto;padding:2rem 1.25rem}'
    'h1{font-size:1.5rem;line-height:1.3;margin:0 0 .5rem}'
    '.note{color:#4b5563;margin:0 0 1.5rem}'
    'fieldset{border:0;margin:0;padding:0}'
    'legend{font-weight:600;margin-bottom:.75rem}'
    'ul{list-style:none;margin:0;padding:0;display:grid;gap:1rem;'
    'grid-template-columns:repeat(auto-fill,minmax(16rem,1fr))}'
    'li{border:1px solid #d1d5db;border-radius:8px;padding:1rem}'
    'li:has(input:checked){border-color:#1d4ed8;box-shadow:0 0 0 1px #1d4ed8}'
    'input[type=radio]{width:1.25rem;height:1.25rem;margin:0 .5rem 0 0;'
    'vertical-align:middle;accent-color:#1d4ed8}'
    'input:focus-visible,button:focus-visible{outline:3px solid #1d4ed8;'
    'outline-offset:2px}'
    'label{cursor:pointer}'
    '.title{font-weight:600}'
    '.id,.desc,.missing{display:block;color:#4b5563}'
    '.missing{margin-top:.75rem}'
    'img{display:block;max-width:100%;height:auto;margin-top:.75rem;'
    'border:1px solid #e5e7eb;border-radius:4px}'
    '.actions{display:flex;flex-wrap:wrap;gap:.75rem;margin-top:1.5rem}'
    'button{font:inherit;font-weight:600;padding:.625rem 1.25rem;'
    'border-radius:6px;border:1px solid #1d4ed8;background:#1d4ed8;'
    'color:#fff;cursor:pointer}'
    'button.secondary{background:#fff;color:#1d4ed8}';

/// Aucun script, aucune ressource d'une autre origine, la feuille de style
/// autorisée par son empreinte, et pas de cadre.
final _csp =
    "default-src 'none'; img-src 'self'; "
    "style-src 'sha256-${base64.encode(sha256.convert(utf8.encode(_css)).bytes)}'; "
    "form-action 'self'; frame-ancestors 'none'; base-uri 'none'";
