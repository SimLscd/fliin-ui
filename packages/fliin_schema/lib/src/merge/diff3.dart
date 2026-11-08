/// La fusion à trois voies de `fliin update` (DESIGN.md §4.4), en Dart pur :
/// le résultat de `git merge-file -p --diff3 -L local -L base -L <label>`,
/// sans dépendre de git.
library;

import 'dart:math';
import 'dart:typed_data';

/// Le texte fusionné et le nombre de régions en conflit.
final class MergeResult {
  const MergeResult(this.text, this.conflicts);

  final String text;
  final int conflicts;

  bool get clean => conflicts == 0;
}

const localLabel = 'local';
const baseLabel = 'base';

/// Fusionne par lignes les changements de [base] vers [local] et de [base]
/// vers [upstream], fins de ligne ramenées à LF. Deux changements qui se
/// chevauchent, ou qui se touchent sans ligne commune entre eux, sont en
/// conflit, sauf s'ils sont identiques : c'est la règle de git (niveau
/// `EAGER`, celui de `--diff3`). Un conflit s'écrit
/// `<<<<<<< local`, `||||||| base`, `=======`, `>>>>>>> [upstreamLabel]`.
MergeResult diff3({
  required String local,
  required String base,
  required String upstream,
  required String upstreamLabel,
}) {
  final o = _lines(local);
  final b = _lines(base);
  final t = _lines(upstream);
  final ids = <String, int>{};
  List<int> intern(List<String> lines) => [
    for (final line in lines) ids.putIfAbsent(line, () => ids.length),
  ];
  final bi = intern(b);
  final oi = intern(o);
  final ti = intern(t);
  final ours = _diff(bi, oi);
  final theirs = _diff(bi, ti);
  if (ours.isEmpty) return MergeResult(t.join(), 0);
  if (theirs.isEmpty) return MergeResult(o.join(), 0);

  final regions = _regions(ours, theirs, oi, ti, b.length, o.length, t.length);
  final out = StringBuffer();
  var conflicts = 0;
  var i = 0;
  void copy(List<String> lines, int start, int count, {bool newline = false}) {
    if (count < 1) return;
    for (var k = start; k < start + count; k++) {
      out.write(lines[k]);
    }
    if (newline && !lines[start + count - 1].endsWith('\n')) out.write('\n');
  }

  for (final r in regions) {
    copy(o, i, r.i1 - i);
    switch (r.mode) {
      case _Mode.conflict:
        conflicts++;
        out.write('<<<<<<< $localLabel\n');
        copy(o, r.i1, r.chg1, newline: true);
        out.write('||||||| $baseLabel\n');
        copy(b, r.i0, r.chg0, newline: true);
        out.write('=======\n');
        copy(t, r.i2, r.chg2, newline: true);
        out.write('>>>>>>> $upstreamLabel\n');
      case _Mode.local:
        copy(o, r.i1, r.chg1);
      case _Mode.upstream:
        copy(t, r.i2, r.chg2);
    }
    i = r.i1 + r.chg1;
  }
  copy(o, i, o.length - i);
  return MergeResult('$out', conflicts);
}

/// Le diff unifié de [before] vers [after], au format de `git diff
/// --no-indent-heuristic` à trois lignes de contexte, sans l'en-tête de
/// fonction après `@@` : vide quand les deux textes sont égaux. [before]
/// nul est un fichier ajouté, [after] nul un fichier retiré ; vide, il n'a
/// que ses deux en-têtes. CRLF vaut LF, comme pour la fusion : un fichier
/// qui ne change que de fins de ligne n'a pas de diff.
String unifiedDiff(String? before, String? after, {required String path}) {
  final a = _lines(before ?? '');
  final b = _lines(after ?? '');
  final ids = <String, int>{};
  List<int> intern(List<String> lines) => [
    for (final line in lines) ids.putIfAbsent(line, () => ids.length),
  ];
  final hunks = _diff(intern(a), intern(b));
  if (hunks.isEmpty && (before == null) == (after == null)) return '';
  final out = StringBuffer()
    ..write(before == null ? '--- /dev/null\n' : '--- a/$path\n')
    ..write(after == null ? '+++ /dev/null\n' : '+++ b/$path\n');
  void line(String mark, String text) {
    out
      ..write(mark)
      ..write(text);
    if (!text.endsWith('\n')) out.write('\n\\ No newline at end of file\n');
  }

  String range(int start, int count) =>
      '${count == 0 ? start : start + 1}${count == 1 ? '' : ',$count'}';

  const context = 3;
  var first = 0;
  while (first < hunks.length) {
    var last = first;
    while (last + 1 < hunks.length &&
        hunks[last + 1].baseStart -
                (hunks[last].baseStart + hunks[last].baseLength) <=
            2 * context) {
      last++;
    }
    final start = max(hunks[first].baseStart - context, 0);
    final end = min(
      hunks[last].baseStart + hunks[last].baseLength + context,
      a.length,
    );
    final sideStart = hunks[first].sideStart - (hunks[first].baseStart - start);
    final sideEnd =
        hunks[last].sideStart +
        hunks[last].sideLength +
        (end - hunks[last].baseStart - hunks[last].baseLength);
    out.write(
      '@@ -${range(start, end - start)} '
      '+${range(sideStart, sideEnd - sideStart)} @@\n',
    );
    var i = start;
    for (final hunk in hunks.sublist(first, last + 1)) {
      for (; i < hunk.baseStart; i++) {
        line(' ', a[i]);
      }
      for (var k = 0; k < hunk.baseLength; k++) {
        line('-', a[hunk.baseStart + k]);
      }
      for (var k = 0; k < hunk.sideLength; k++) {
        line('+', b[hunk.sideStart + k]);
      }
      i = hunk.baseStart + hunk.baseLength;
    }
    for (; i < end; i++) {
      line(' ', a[i]);
    }
    first = last + 1;
  }
  return '$out';
}

/// Chaque ligne garde son `\n` ; la dernière peut ne pas en avoir.
List<String> _lines(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < normalized.length; i++) {
    if (normalized.codeUnitAt(i) == 0x0A) {
      lines.add(normalized.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < normalized.length) lines.add(normalized.substring(start));
  return lines;
}

/// Un bloc de changement de la base vers un côté : [baseLength] lignes de la
/// base à partir de [baseStart] remplacées par [sideLength] lignes du côté à
/// partir de [sideStart].
typedef _Hunk = ({
  int baseStart,
  int baseLength,
  int sideStart,
  int sideLength,
});

enum _Mode { conflict, local, upstream }

/// Une région du résultat, en coordonnées de la base (`i0`), du local (`i1`)
/// et de l'amont (`i2`).
final class _Region {
  _Region(
    this.mode,
    this.i0,
    this.chg0,
    this.i1,
    this.chg1,
    this.i2,
    this.chg2,
  );

  _Mode mode;
  final int i0;
  int chg0;
  final int i1;
  int chg1;
  final int i2;
  int chg2;
}

/// Le parcours de `xdl_do_merge` (git, `xdiff/xmerge.c`) : les blocs des
/// deux côtés sont lus dans l'ordre de la base ; deux blocs dont les plages
/// de base se touchent forment un conflit, sauf s'ils sont identiques ; une
/// région qui touche la précédente s'y fond.
List<_Region> _regions(
  List<_Hunk> ours,
  List<_Hunk> theirs,
  List<int> o,
  List<int> t,
  int baseLength,
  int localLength,
  int upstreamLength,
) {
  final regions = <_Region>[];
  void append(
    _Mode mode,
    int i0,
    int chg0,
    int i1,
    int chg1,
    int i2,
    int chg2,
  ) {
    final last = regions.lastOrNull;
    // `<=` comme git ; l'égalité n'arrive pas, deux blocs d'un même diff
    // étant séparés d'au moins une ligne commune.
    if (last != null &&
        (i1 <= last.i1 + last.chg1 || i2 <= last.i2 + last.chg2)) {
      if (mode != last.mode) last.mode = _Mode.conflict;
      last
        ..chg0 = i0 + chg0 - last.i0
        ..chg1 = i1 + chg1 - last.i1
        ..chg2 = i2 + chg2 - last.i2;
    } else {
      regions.add(_Region(mode, i0, chg0, i1, chg1, i2, chg2));
    }
  }

  var a = 0;
  var c = 0;
  while (a < ours.length && c < theirs.length) {
    final x = ours[a];
    final y = theirs[c];
    if (x.baseStart + x.baseLength < y.baseStart) {
      append(
        _Mode.local,
        x.baseStart,
        x.baseLength,
        x.sideStart,
        x.sideLength,
        y.sideStart - y.baseStart + x.baseStart,
        x.baseLength,
      );
      a++;
      continue;
    }
    if (y.baseStart + y.baseLength < x.baseStart) {
      append(
        _Mode.upstream,
        y.baseStart,
        y.baseLength,
        x.sideStart - x.baseStart + y.baseStart,
        y.baseLength,
        y.sideStart,
        y.sideLength,
      );
      c++;
      continue;
    }
    final identical =
        x.baseStart == y.baseStart &&
        x.baseLength == y.baseLength &&
        x.sideLength == y.sideLength &&
        _same(o, x.sideStart, t, y.sideStart, x.sideLength);
    if (!identical) {
      final off = x.baseStart - y.baseStart;
      final ffo = off + x.baseLength - y.baseLength;
      var i0 = x.baseStart;
      var i1 = x.sideStart;
      var i2 = y.sideStart;
      if (off > 0) {
        i0 -= off;
        i1 -= off;
      } else {
        i2 += off;
      }
      var chg0 = x.baseStart + x.baseLength - i0;
      var chg1 = x.sideStart + x.sideLength - i1;
      var chg2 = y.sideStart + y.sideLength - i2;
      if (ffo < 0) {
        chg0 -= ffo;
        chg1 -= ffo;
      } else {
        chg2 += ffo;
      }
      append(_Mode.conflict, i0, chg0, i1, chg1, i2, chg2);
    }
    final endOurs = x.baseStart + x.baseLength;
    final endTheirs = y.baseStart + y.baseLength;
    if (endOurs >= endTheirs) c++;
    if (endTheirs >= endOurs) a++;
  }
  for (; a < ours.length; a++) {
    final x = ours[a];
    append(
      _Mode.local,
      x.baseStart,
      x.baseLength,
      x.sideStart,
      x.sideLength,
      x.baseStart + upstreamLength - baseLength,
      x.baseLength,
    );
  }
  for (; c < theirs.length; c++) {
    final y = theirs[c];
    append(
      _Mode.upstream,
      y.baseStart,
      y.baseLength,
      y.baseStart + localLength - baseLength,
      y.baseLength,
      y.sideStart,
      y.sideLength,
    );
  }
  return regions;
}

bool _same(List<int> a, int i, List<int> b, int j, int count) {
  for (var k = 0; k < count; k++) {
    if (a[i + k] != b[j + k]) return false;
  }
  return true;
}

/// Les blocs de changement de [a] vers [b] : préfixe et suffixe communs
/// retirés, plus court script d'édition de Myers sur le reste, puis chaque
/// bloc glissé comme le fait git (`xdl_change_compact`) quand des lignes
/// répétées laissent le choix de sa position.
List<_Hunk> _diff(List<int> a, List<int> b) {
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < a.length - prefix &&
      suffix < b.length - prefix &&
      a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
    suffix++;
  }
  final removed = _Changes(a.length);
  final added = _Changes(b.length);
  _myers(a, b, prefix, a.length - suffix, b.length - suffix, removed, added);
  _compact(a, removed, added);
  _compact(b, added, removed);

  final hunks = <_Hunk>[];
  var x = 0;
  var y = 0;
  while (x < a.length || y < b.length) {
    if (!removed[x] && !added[y]) {
      x++;
      y++;
      continue;
    }
    final startX = x;
    final startY = y;
    while (removed[x]) {
      x++;
    }
    while (added[y]) {
      y++;
    }
    hunks.add((
      baseStart: startX,
      baseLength: x - startX,
      sideStart: startY,
      sideLength: y - startY,
    ));
  }
  return hunks;
}

/// Les lignes changées d'un fichier, lues à `-1` et à `length` comme non
/// changées, à la manière des sentinelles de xdiff.
final class _Changes {
  _Changes(this.length) : _flags = List.filled(length + 2, false);

  final int length;
  final List<bool> _flags;

  bool operator [](int i) => _flags[i + 1];

  void operator []=(int i, bool value) => _flags[i + 1] = value;
}

/// Un groupe de lignes changées `[start, end)`, vide entre deux lignes
/// communes ; les groupes des deux fichiers se correspondent un à un.
final class _Group {
  _Group(this.changes) {
    while (changes[end]) {
      end++;
    }
  }

  final _Changes changes;
  int start = 0;
  int end = 0;

  bool get isEmpty => start == end;

  bool next() {
    if (end == changes.length) return false;
    start = end + 1;
    end = start;
    while (changes[end]) {
      end++;
    }
    return true;
  }

  bool previous() {
    if (start == 0) return false;
    end = start - 1;
    start = end;
    while (changes[start - 1]) {
      start--;
    }
    return true;
  }
}

/// `xdl_change_compact` sans l'heuristique d'indentation : chaque groupe de
/// [changes] remonte au plus haut puis descend au plus bas, et se cale sur
/// le dernier groupe non vide de l'autre fichier qu'il a croisé.
void _compact(List<int> lines, _Changes changes, _Changes other) {
  bool slideDown(_Group g) {
    if (g.end < lines.length && lines[g.start] == lines[g.end]) {
      changes[g.start++] = false;
      changes[g.end++] = true;
      while (changes[g.end]) {
        g.end++;
      }
      return true;
    }
    return false;
  }

  bool slideUp(_Group g) {
    if (g.start > 0 && lines[g.start - 1] == lines[g.end - 1]) {
      changes[--g.start] = true;
      changes[--g.end] = false;
      while (changes[g.start - 1]) {
        g.start--;
      }
      return true;
    }
    return false;
  }

  final g = _Group(changes);
  final go = _Group(other);
  while (true) {
    if (!g.isEmpty) {
      int size;
      int earliestEnd;
      int? endMatchingOther;
      do {
        size = g.end - g.start;
        endMatchingOther = null;
        while (slideUp(g)) {
          go.previous();
        }
        earliestEnd = g.end;
        if (!go.isEmpty) endMatchingOther = g.end;
        while (slideDown(g)) {
          go.next();
          if (!go.isEmpty) endMatchingOther = g.end;
        }
      } while (size != g.end - g.start);
      if (g.end != earliestEnd && endMatchingOther != null) {
        while (go.isEmpty) {
          slideUp(g);
          go.previous();
        }
      }
    }
    if (!g.next()) break;
    go.next();
  }
}

/// Marque les lignes retirées de [a] et ajoutées à [b] comme xdiff
/// (`xprepare.c`, `xdiffi.c`) : une ligne sans correspondant de l'autre
/// côté est changée d'emblée, une ligne trop fréquente entourée de telles
/// lignes aussi ; le reste passe par Myers en espace linéaire, coupé en son
/// milieu puis chaque moitié à son tour. [a] et [b] sont les fichiers
/// entiers ; seule la plage `[start, aEnd)` × `[start, bEnd)` est comparée.
void _myers(
  List<int> a,
  List<int> b,
  int start,
  int aEnd,
  int bEnd,
  _Changes removed,
  _Changes added,
) {
  final inA = <int, int>{};
  final inB = <int, int>{};
  for (final line in a) {
    inA[line] = (inA[line] ?? 0) + 1;
  }
  for (final line in b) {
    inB[line] = (inB[line] ?? 0) + 1;
  }
  List<int> kept(
    List<int> lines,
    int end,
    Map<int, int> other,
    _Changes changes,
  ) {
    final limit = min(_bogoSqrt(lines.length), 1024);
    final discard = [
      for (var i = start; i < end; i++)
        switch (other[lines[i]] ?? 0) {
          0 => 0,
          final n when n >= limit => 2,
          _ => 1,
        },
    ];
    final kept = <int>[];
    for (var i = start; i < end; i++) {
      final d = discard[i - start];
      if (d == 1 ||
          d == 2 && !_cleanMultimatch(discard, i - start, 0, end - start - 1)) {
        kept.add(i);
      } else {
        changes[i] = true;
      }
    }
    return kept;
  }

  final keptA = kept(a, aEnd, inB, removed);
  final keptB = kept(b, bEnd, inA, added);
  final ha = [for (final i in keptA) a[i]];
  final hb = [for (final j in keptB) b[j]];
  final diagonals = Int32List(ha.length + hb.length + 3);
  final forward = _Diagonals(diagonals, hb.length + 1);
  final backward = _Diagonals(Int32List(diagonals.length), hb.length + 1);
  _compare(
    ha,
    0,
    ha.length,
    hb,
    0,
    hb.length,
    forward,
    backward,
    (i) {
      removed[keptA[i]] = true;
    },
    (j) {
      added[keptB[j]] = true;
    },
  );
}

int _bogoSqrt(int n) {
  var i = 1;
  for (; n > 0; n >>= 2) {
    i <<= 1;
  }
  return i;
}

/// `xdl_clean_mmatch` : une ligne trop fréquente n'est écartée qu'au milieu
/// d'une suite de lignes sans correspondant.
bool _cleanMultimatch(List<int> discard, int i, int s, int e) {
  if (i - s > 100) s = i - 100;
  if (e - i > 100) e = i + 100;
  var none0 = 0;
  var multi0 = 1;
  for (var r = 1; i - r >= s; r++) {
    if (discard[i - r] == 0) {
      none0++;
    } else if (discard[i - r] == 2) {
      multi0++;
    } else {
      break;
    }
  }
  if (none0 == 0) return false;
  var none1 = 0;
  var multi1 = 1;
  for (var r = 1; i + r <= e; r++) {
    if (discard[i + r] == 0) {
      none1++;
    } else if (discard[i + r] == 2) {
      multi1++;
    } else {
      break;
    }
  }
  if (none1 == 0) return false;
  none1 += none0;
  multi1 += multi0;
  return multi1 * 4 < multi1 + none1;
}

/// Un tableau indexé par diagonale (`i1 - i2`), négatives comprises.
extension type _Diagonals._((Int32List, int) _) {
  _Diagonals(Int32List values, int offset) : this._((values, offset));

  int operator [](int d) => _.$1[_.$2 + d];

  void operator []=(int d, int value) => _.$1[_.$2 + d] = value;
}

/// `xdl_recs_cmp`.
void _compare(
  List<int> a,
  int off1,
  int lim1,
  List<int> b,
  int off2,
  int lim2,
  _Diagonals forward,
  _Diagonals backward,
  void Function(int i) removed,
  void Function(int j) added,
) {
  while (off1 < lim1 && off2 < lim2 && a[off1] == b[off2]) {
    off1++;
    off2++;
  }
  while (off1 < lim1 && off2 < lim2 && a[lim1 - 1] == b[lim2 - 1]) {
    lim1--;
    lim2--;
  }
  if (off1 == lim1) {
    for (; off2 < lim2; off2++) {
      added(off2);
    }
  } else if (off2 == lim2) {
    for (; off1 < lim1; off1++) {
      removed(off1);
    }
  } else {
    final (i1, i2) = _split(a, off1, lim1, b, off2, lim2, forward, backward);
    _compare(a, off1, i1, b, off2, i2, forward, backward, removed, added);
    _compare(a, i1, lim1, b, i2, lim2, forward, backward, removed, added);
  }
}

/// `xdl_split`, sans les heuristiques que xdiff n'atteint qu'au-delà de 256
/// diagonales parcourues : le point où les chemins avant et arrière se
/// rejoignent.
(int, int) _split(
  List<int> a,
  int off1,
  int lim1,
  List<int> b,
  int off2,
  int lim2,
  _Diagonals kvdf,
  _Diagonals kvdb,
) {
  const lineMax = 0x7fffffff;
  final dmin = off1 - lim2;
  final dmax = lim1 - off2;
  final fmid = off1 - off2;
  final bmid = lim1 - lim2;
  final odd = (fmid - bmid).isOdd;
  var fmin = fmid;
  var fmax = fmid;
  var bmin = bmid;
  var bmax = bmid;
  kvdf[fmid] = off1;
  kvdb[bmid] = lim1;
  while (true) {
    if (fmin > dmin) {
      kvdf[--fmin - 1] = -1;
    } else {
      ++fmin;
    }
    if (fmax < dmax) {
      kvdf[++fmax + 1] = -1;
    } else {
      --fmax;
    }
    for (var d = fmax; d >= fmin; d -= 2) {
      var i1 = kvdf[d - 1] >= kvdf[d + 1] ? kvdf[d - 1] + 1 : kvdf[d + 1];
      var i2 = i1 - d;
      while (i1 < lim1 && i2 < lim2 && a[i1] == b[i2]) {
        i1++;
        i2++;
      }
      kvdf[d] = i1;
      if (odd && bmin <= d && d <= bmax && kvdb[d] <= i1) return (i1, i2);
    }
    if (bmin > dmin) {
      kvdb[--bmin - 1] = lineMax;
    } else {
      ++bmin;
    }
    if (bmax < dmax) {
      kvdb[++bmax + 1] = lineMax;
    } else {
      --bmax;
    }
    for (var d = bmax; d >= bmin; d -= 2) {
      var i1 = kvdb[d - 1] < kvdb[d + 1] ? kvdb[d - 1] : kvdb[d + 1] - 1;
      var i2 = i1 - d;
      while (i1 > off1 && i2 > off2 && a[i1 - 1] == b[i2 - 1]) {
        i1--;
        i2--;
      }
      kvdb[d] = i1;
      if (!odd && fmin <= d && d <= fmax && i1 <= kvdf[d]) return (i1, i2);
    }
  }
}
