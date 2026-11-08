import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'dart:convert';

import 'package:fliin_schema/fliin_schema.dart';

import '../install/registry_port.dart';

enum ParameterKind {
  requiredPositional,
  optionalPositional,
  requiredNamed,
  optionalNamed,
}

typedef ApiParameter = ({String name, ParameterKind kind, String type});

/// Une déclaration publique telle qu'un appelant la voit. [shape] porte ce
/// qui n'est pas une liste de paramètres (sorte, modificateurs, type de
/// retour) ; [parameters] est nul pour ce qui ne s'appelle pas.
typedef ApiDeclaration = ({String shape, List<ApiParameter>? parameters});

/// L'API publique de [sources], par symbole : `FlButton`, `FlButton.new`,
/// `FlButton.label`, `FlButton.label=`, `FlButtonVariant.primary`. Un champ
/// et un accesseur du même nom sont le même symbole, pour qu'un passage de
/// l'un à l'autre ne compte pas. L'analyse est syntaxique : un type se
/// compare par son texte.
Map<String, ApiDeclaration> publicApi(Iterable<String> sources) {
  final api = <String, ApiDeclaration>{};
  final supertypes = <String, Set<String>>{};
  for (final source in sources) {
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
    for (final declaration in unit.declarations) {
      _declaration(declaration, api, supertypes);
    }
  }
  for (final MapEntry(key: name, value: declaration) in api.entries.toList()) {
    if (declaration.shape.split(' ').contains('sealed')) {
      final subtypes = [
        for (final MapEntry(:key, :value) in supertypes.entries)
          if (value.contains(name)) key,
      ]..sort();
      api[name] = (
        shape: '${declaration.shape} permits {${subtypes.join(', ')}}',
        parameters: null,
      );
    }
  }
  return api;
}

/// Les signatures publiques des fichiers Dart bruts de [manifest], une par
/// ligne (`FlButton.new: const new({…})`), dans l'ordre des déclarations.
/// Lève une [RegistryFailure] si un blob manque ou est altéré.
Future<List<String>> publishedApi(
  Registry registry,
  ItemManifest manifest,
) async {
  final sources = await Future.wait([
    for (final file in manifest.files)
      if (file.path.endsWith('.dart'))
        registry
            .fetchBlob(file.sha256)
            .then((bytes) => utf8.decode(bytes, allowMalformed: true)),
  ]);
  return apiLines(sources);
}

/// Les signatures publiques de [sources], une par ligne, au format de
/// [publishedApi].
List<String> apiLines(List<String> sources) => [
  for (final MapEntry(key: symbol, value: declaration) in publicApi(
    sources,
  ).entries)
    '$symbol: ${renderDeclaration(declaration)}',
];

/// DESIGN.md §5.3 : 40 lignes de signatures au plus par résultat de
/// recherche.
const maxApiSummaryLines = 40;

/// [api] tel quel s'il tient en [maxApiSummaryLines] lignes ; sinon le
/// début, et une dernière ligne qui dit combien manquent et où les lire
/// ([rest] : l'outil MCP ou les fichiers installés).
String summarizeApi(List<String> api, {required String rest}) =>
    api.length <= maxApiSummaryLines
    ? api.join('\n')
    : [
        ...api.take(maxApiSummaryLines - 1),
        '… ${api.length - maxApiSummaryLines + 1} more: $rest',
      ].join('\n');

/// Les fichiers Dart de [before] absents de [after] : un import vers eux
/// cesse de compiler, même si leurs déclarations ont migré ailleurs.
List<BreakingChange> fileBreaks(
  Iterable<String> before,
  Iterable<String> after,
) => [
  for (final target
      in before.toSet().difference(after.toSet()).toList()..sort())
    if (target.endsWith('.dart')) RemovedDeclaration(target),
];

/// Les cassures de [before] à [after] : déclarations retirées, paramètres
/// requis ajoutés (ou devenus requis), et tout autre changement de
/// signature visible d'un appelant. Triées par symbole.
List<BreakingChange> apiBreaks(
  Map<String, ApiDeclaration> before,
  Map<String, ApiDeclaration> after,
) {
  final breaks = <BreakingChange>[];
  for (final symbol in after.keys.toList()..sort()) {
    final added = after[symbol]!;
    final dot = symbol.lastIndexOf('.');
    if (before.containsKey(symbol) ||
        !added.shape.startsWith('abstract ') ||
        dot < 0) {
      continue;
    }
    final owner = after[symbol.substring(0, dot)]?.shape.split(' ');
    if (before.containsKey(symbol.substring(0, dot)) &&
        owner != null &&
        !owner.contains('final') &&
        !owner.contains('sealed')) {
      breaks.add(
        ChangedSignature(
          symbol,
          before: 'absent',
          after: renderDeclaration(added),
        ),
      );
    }
  }
  for (final symbol in before.keys.toList()..sort()) {
    final old = before[symbol]!;
    final now = after[symbol];
    if (now == null) {
      breaks.add(RemovedDeclaration(symbol));
      continue;
    }
    final required = <String>[];
    var changed = old.shape != now.shape;
    switch ((old.parameters, now.parameters)) {
      case (final List<ApiParameter> was, final List<ApiParameter> is_):
        changed |= _parametersChanged(was, is_, required);
      case (null, null):
        break;
      case _:
        changed = true;
    }
    if (changed) {
      breaks.add(
        ChangedSignature(
          symbol,
          before: renderDeclaration(old),
          after: renderDeclaration(now),
        ),
      );
    }
    for (final parameter in required) {
      breaks.add(RequiredParameterAdded(symbol, parameter: parameter));
    }
  }
  return breaks..sort(
    (a, b) => '${a.toJson()['symbol']}'.compareTo('${b.toJson()['symbol']}'),
  );
}

/// Vrai si un paramètre a disparu ou changé de type ; [required] reçoit les
/// paramètres qu'un appel existant ne passe pas et qui sont désormais exigés.
bool _parametersChanged(
  List<ApiParameter> was,
  List<ApiParameter> now,
  List<String> required,
) {
  bool positional(ApiParameter p) =>
      p.kind == ParameterKind.requiredPositional ||
      p.kind == ParameterKind.optionalPositional;
  var changed = false;
  final oldPositional = was.where(positional).toList();
  final newPositional = now.where(positional).toList();
  if (newPositional.length < oldPositional.length) changed = true;
  for (final (i, p) in newPositional.indexed) {
    if (i >= oldPositional.length) {
      if (p.kind == ParameterKind.requiredPositional) required.add(p.name);
      continue;
    }
    final old = oldPositional[i];
    if (old.type != p.type) changed = true;
    if (old.kind == ParameterKind.optionalPositional &&
        p.kind == ParameterKind.requiredPositional) {
      required.add(p.name);
    }
  }
  final oldNamed = {
    for (final p in was)
      if (!positional(p)) p.name: p,
  };
  for (final p in now.where((p) => !positional(p))) {
    final old = oldNamed.remove(p.name);
    if (old == null) {
      if (p.kind == ParameterKind.requiredNamed) required.add(p.name);
      continue;
    }
    if (old.type != p.type) changed = true;
    if (old.kind == ParameterKind.optionalNamed &&
        p.kind == ParameterKind.requiredNamed) {
      required.add(p.name);
    }
  }
  return changed || oldNamed.isNotEmpty;
}

/// Une déclaration telle qu'un appelant l'écrit :
/// `const new({super.key, required String label})`.
String renderDeclaration(ApiDeclaration d) => switch (d.parameters) {
  null => d.shape,
  final parameters => '${d.shape}(${_renderParameters(parameters)})',
};

String _renderParameters(List<ApiParameter> parameters) {
  String text(ApiParameter p) =>
      p.type == 'super.${p.name}' ? p.type : '${p.type} ${p.name}';
  final positional = [
    for (final p in parameters)
      if (p.kind == ParameterKind.requiredPositional) text(p),
  ];
  final optional = [
    for (final p in parameters)
      if (p.kind == ParameterKind.optionalPositional) text(p),
  ];
  final named = [
    for (final p in parameters)
      if (p.kind == ParameterKind.requiredNamed)
        'required ${text(p)}'
      else if (p.kind == ParameterKind.optionalNamed)
        text(p),
  ];
  return [
    ...positional,
    if (optional.isNotEmpty) '[${optional.join(', ')}]',
    if (named.isNotEmpty) '{${named.join(', ')}}',
  ].join(', ');
}

bool _public(String name) => !name.startsWith('_');

/// Les noms de types que [clauses] nomment : la superclasse, les mixins et
/// les interfaces, pour retrouver les sous-types d'une classe sealed.
Set<String> _named(List<AstNode?> clauses) => {
  for (final clause in clauses.nonNulls)
    for (final match in RegExp(
      r'[A-Za-z_][A-Za-z0-9_]*',
    ).allMatches(clause.toSource()))
      match[0]!,
};

String _clauses(List<AstNode?> clauses) =>
    [for (final clause in clauses.nonNulls) ' ${clause.toSource()}'].join();

void _declaration(
  CompilationUnitMember node,
  Map<String, ApiDeclaration> api,
  Map<String, Set<String>> supertypes,
) {
  switch (node) {
    case ClassDeclaration(:final namePart, :final body):
      final name = namePart.typeName.lexeme;
      if (!_public(name)) return;
      final modifiers = [
        node.sealedKeyword,
        node.abstractKeyword,
        node.baseKeyword,
        node.interfaceKeyword,
        node.finalKeyword,
        node.mixinKeyword,
      ].nonNulls.map((t) => t.lexeme);
      final clauses = [
        node.extendsClause,
        node.withClause,
        node.implementsClause,
      ];
      supertypes[name] = _named(clauses);
      api[name] = (
        shape:
            '${[...modifiers, 'class${_typeParameters(namePart.typeParameters)}'].join(' ')}'
            '${_clauses(clauses)}',
        parameters: null,
      );
      _primary(name, namePart, api, declaresAll: false);
      if (namePart is! PrimaryConstructorDeclaration &&
          !body.members.any((m) => m is ConstructorDeclaration)) {
        api['$name.new'] = (shape: 'new', parameters: const []);
      }
      _members(name, body.members, api);
    case MixinDeclaration(:final name, :final body):
      if (!_public(name.lexeme)) return;
      api[name.lexeme] = (
        shape: [
          if (node.baseKeyword != null) 'base',
          'mixin${_typeParameters(node.typeParameters)}',
          if (node.onClause case final on?) on.toSource(),
          if (node.implementsClause case final implements?)
            implements.toSource(),
        ].join(' '),
        parameters: null,
      );
      supertypes[name.lexeme] = _named([node.onClause, node.implementsClause]);
      _members(name.lexeme, body.members, api);
    case EnumDeclaration(:final namePart, :final body):
      final name = namePart.typeName.lexeme;
      if (!_public(name)) return;
      api[name] = (
        shape:
            'enum${_typeParameters(namePart.typeParameters)}'
            '${_clauses([node.withClause, node.implementsClause])} '
            '{${[for (final c in body.constants) c.name.lexeme].join(', ')}}',
        parameters: null,
      );
      supertypes[name] = _named([node.withClause, node.implementsClause]);
      for (final constant in body.constants) {
        api['$name.${constant.name.lexeme}'] = (
          shape: 'static final $name',
          parameters: null,
        );
      }
      _primary(name, namePart, api, declaresAll: false);
      _members(name, body.members, api);
    case ExtensionTypeDeclaration(:final namePart, :final body):
      final name = namePart.typeName.lexeme;
      if (!_public(name)) return;
      api[name] = (
        shape:
            'extension type${_typeParameters(namePart.typeParameters)}'
            '${_clauses([node.implementsClause])}',
        parameters: null,
      );
      supertypes[name] = _named([node.implementsClause]);
      _primary(name, namePart, api, declaresAll: true);
      _members(name, body.members, api);
    case ExtensionDeclaration(:final body):
      final named = node.name?.lexeme;
      final name =
          named ?? 'extension ${node.onClause?.extendedType.toSource()}';
      if (!_public(name)) return;
      if (named != null) {
        api[name] = (
          shape:
              'extension${_typeParameters(node.typeParameters)} '
              '${node.onClause?.toSource() ?? ''}',
          parameters: null,
        );
      }
      _members(name, body.members, api);
    case FunctionDeclaration(:final name, :final functionExpression):
      if (!_public(name.lexeme)) return;
      final returnType = node.returnType?.toSource() ?? 'dynamic';
      if (node.isGetter) {
        api[name.lexeme] = (shape: 'get $returnType', parameters: null);
      } else if (node.isSetter) {
        api['${name.lexeme}='] = (
          shape: 'set ${_firstType(functionExpression.parameters)}',
          parameters: null,
        );
      } else {
        api[name.lexeme] = (
          shape:
              '$returnType${_typeParameters(functionExpression.typeParameters)}',
          parameters: _parameters(functionExpression.parameters, const {}),
        );
      }
    case TopLevelVariableDeclaration(:final variables):
      _variables(null, variables, isStatic: false, api);
    case GenericTypeAlias(:final name):
      if (!_public(name.lexeme)) return;
      api[name.lexeme] = (
        shape:
            'typedef${_typeParameters(node.typeParameters)} = '
            '${node.type.toSource()}',
        parameters: null,
      );
    case TypeAlias(:final name):
      if (!_public(name.lexeme)) return;
      api[name.lexeme] = (
        shape: 'typedef ${node.toSource()}',
        parameters: null,
      );
    case _:
      break;
  }
}

/// Un constructeur primaire (`class P(final int x)`, `extension type E(int
/// x)`) : le constructeur, et un accesseur par paramètre qui déclare un
/// champ, tous pour une extension de type ([declaresAll]).
void _primary(
  String owner,
  ClassNamePart namePart,
  Map<String, ApiDeclaration> api, {
  required bool declaresAll,
}) {
  if (namePart is! PrimaryConstructorDeclaration) return;
  final constructor = namePart.constructorName?.name.lexeme ?? 'new';
  if (_public(constructor)) {
    api['$owner.$constructor'] = (
      shape: namePart.constKeyword == null ? 'new' : 'const new',
      parameters: _parameters(namePart.formalParameters, const {}),
    );
  }
  for (final p in namePart.formalParameters.parameters) {
    if (p.name case final name?
        when _public(name.lexeme) &&
            (declaresAll || p.constFinalOrVarKeyword != null)) {
      api['$owner.${name.lexeme}'] = (
        shape: 'get ${p.type?.toSource() ?? 'dynamic'}',
        parameters: null,
      );
      if (p.varKeyword != null) {
        api['$owner.${name.lexeme}='] = (
          shape: 'set ${p.type?.toSource() ?? 'dynamic'}',
          parameters: null,
        );
      }
    }
  }
}

void _members(
  String owner,
  List<ClassMember> members,
  Map<String, ApiDeclaration> api,
) {
  final fields = <String, String>{
    for (final member in members)
      if (member case FieldDeclaration(:final fields))
        for (final variable in fields.variables)
          variable.name.lexeme: fields.type?.toSource() ?? 'dynamic',
  };
  for (final member in members) {
    switch (member) {
      case ConstructorDeclaration(:final name, :final parameters):
        final constructor = name?.lexeme ?? 'new';
        if (!_public(constructor)) continue;
        api['$owner.$constructor'] = (
          shape: [
            if (member.constKeyword != null) 'const',
            if (member.factoryKeyword != null) 'factory',
            'new',
          ].join(' '),
          parameters: _parameters(parameters, fields),
        );
      case MethodDeclaration(:final name) when member.isOperator:
        api['$owner.operator ${name.lexeme}'] = (
          shape: member.returnType?.toSource() ?? 'dynamic',
          parameters: _parameters(member.parameters, fields),
        );
      case MethodDeclaration(:final name):
        if (!_public(name.lexeme)) continue;
        final static =
            '${member.body is EmptyFunctionBody && member.externalKeyword == null ? 'abstract ' : ''}'
            '${member.isStatic ? 'static ' : ''}';
        final returnType = member.returnType?.toSource() ?? 'dynamic';
        if (member.isGetter) {
          api['$owner.${name.lexeme}'] = (
            shape: '${static}get $returnType',
            parameters: null,
          );
        } else if (member.isSetter) {
          api['$owner.${name.lexeme}='] = (
            shape: '${static}set ${_firstType(member.parameters)}',
            parameters: null,
          );
        } else {
          api['$owner.${name.lexeme}'] = (
            shape:
                '$static$returnType${_typeParameters(member.typeParameters)}',
            parameters: _parameters(member.parameters, fields),
          );
        }
      case FieldDeclaration(:final fields):
        _variables(owner, fields, isStatic: member.isStatic, api);
      case _:
        break;
    }
  }
}

void _variables(
  String? owner,
  VariableDeclarationList list,
  Map<String, ApiDeclaration> api, {
  required bool isStatic,
}) {
  final type = list.type?.toSource() ?? 'dynamic';
  final static = isStatic ? 'static ' : '';
  for (final variable in list.variables) {
    final name = variable.name.lexeme;
    if (!_public(name)) continue;
    final symbol = owner == null ? name : '$owner.$name';
    api[symbol] = (
      shape: '$static${list.isConst ? 'const' : 'get'} $type',
      parameters: null,
    );
    final lateUnset =
        list.isLate && list.isFinal && variable.initializer == null;
    if (!list.isFinal && !list.isConst || lateUnset) {
      api['$symbol='] = (shape: '${static}set $type', parameters: null);
    }
  }
}

/// `this.label` prend le type du champ, `super.key` garde sa forme : la
/// comparaison n'a pas besoin du type de la superclasse, seulement qu'il
/// soit écrit pareil des deux côtés.
List<ApiParameter> _parameters(
  FormalParameterList? list,
  Map<String, String> fields,
) => [
  for (final p in list?.parameters ?? const <FormalParameter>[])
    if (p.name case final name? when !(p.isNamed && !_public(name.lexeme)))
      (
        name: name.lexeme,
        kind: p.isRequiredPositional
            ? ParameterKind.requiredPositional
            : p.isOptionalPositional
            ? ParameterKind.optionalPositional
            : p.isRequiredNamed
            ? ParameterKind.requiredNamed
            : ParameterKind.optionalNamed,
        type: switch (p) {
          FieldFormalParameter() when p.type == null =>
            fields[name.lexeme] ?? 'dynamic',
          SuperFormalParameter() when p.type == null => 'super.${name.lexeme}',
          _ when p.functionTypedSuffix != null => p.toSource(),
          _ => p.type?.toSource() ?? 'dynamic',
        },
      ),
];

String _firstType(FormalParameterList? list) =>
    list?.parameters.firstOrNull?.type?.toSource() ?? 'dynamic';

String _typeParameters(TypeParameterList? list) => list?.toSource() ?? '';

/// Les symboles publics de [source] sans commentaire `///`, comme la règle
/// `public_member_api_docs` les voit : déclarations de premier niveau,
/// valeurs d'enum, constructeurs, méthodes, accesseurs et champs des types
/// publics. Une redéfinition (`@override`), le mutateur d'un accesseur
/// déclaré et le constructeur d'un enum ou d'une classe abstraite ou
/// sealed sont
/// exemptés. Syntaxique, comme [publicApi] : sur le registre d'avant la
/// phase 9, 365 symboles pour la règle, 364 ici (ADR 0011).
List<String> undocumentedSymbols(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final missing = <String>[];
  void check(AnnotatedNode node, String name) {
    if (_public(name.split('.').last) && node.documentationComment == null) {
      missing.add(name);
    }
  }

  void members(
    String owner,
    List<ClassMember> members, {
    bool instantiable = true,
  }) {
    final getters = {
      for (final m in members)
        if (m is MethodDeclaration && m.isGetter) m.name.lexeme,
    };
    for (final member in members) {
      if (member.metadata.any((a) => a.name.name == 'override')) continue;
      switch (member) {
        case ConstructorDeclaration(:final name) when instantiable:
          check(member, name == null ? '$owner.new' : '$owner.${name.lexeme}');
        case MethodDeclaration(:final name)
            when !(member.isSetter && getters.contains(name.lexeme)):
          check(member, '$owner.${name.lexeme}');
        case FieldDeclaration(:final fields):
          for (final variable in fields.variables) {
            if (_public(variable.name.lexeme)) {
              check(member, '$owner.${variable.name.lexeme}');
            }
          }
        case _:
          break;
      }
    }
  }

  for (final node in unit.declarations) {
    switch (node) {
      case ClassDeclaration(:final namePart, :final body)
          when _public(namePart.typeName.lexeme):
        check(node, namePart.typeName.lexeme);
        members(
          namePart.typeName.lexeme,
          body.members,
          instantiable:
              node.abstractKeyword == null && node.sealedKeyword == null,
        );
      case MixinDeclaration(:final name, :final body) when _public(name.lexeme):
        check(node, name.lexeme);
        members(name.lexeme, body.members);
      case EnumDeclaration(:final namePart, :final body)
          when _public(namePart.typeName.lexeme):
        final name = namePart.typeName.lexeme;
        check(node, name);
        for (final constant in body.constants) {
          check(constant, '$name.${constant.name.lexeme}');
        }
        members(name, body.members, instantiable: false);
      case ExtensionTypeDeclaration(:final namePart, :final body)
          when _public(namePart.typeName.lexeme):
        check(node, namePart.typeName.lexeme);
        members(namePart.typeName.lexeme, body.members);
      case ExtensionDeclaration(:final name?, :final body)
          when _public(name.lexeme):
        check(node, name.lexeme);
        members(name.lexeme, body.members);
      case FunctionDeclaration(:final name) when _public(name.lexeme):
        check(node, name.lexeme);
      case TopLevelVariableDeclaration(:final variables):
        for (final variable in variables.variables) {
          if (_public(variable.name.lexeme)) check(node, variable.name.lexeme);
        }
      case TypeAlias(:final name) when _public(name.lexeme):
        check(node, name.lexeme);
      case _:
        break;
    }
  }
  return missing;
}
