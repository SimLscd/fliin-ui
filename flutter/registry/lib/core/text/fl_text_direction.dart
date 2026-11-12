import 'package:flutter/widgets.dart';

final RegExp _rtl = RegExp(r'[\p{Script=Arabic}\p{Script=Hebrew}\p{Script=Syriac}\p{Script=Thaana}\p{Script=Nko}]', unicode: true);
final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// The direction of [text]'s first strong character: right-to-left for
/// Arabic, Hebrew and the other right-to-left scripts, left-to-right for
/// any other letter, null when it has none (digits, punctuation, emoji).
///
/// A name the user wrote (a song, a person) keeps its own direction inside
/// a screen of the other: given to a `Text` cut by an ellipsis, it puts the
/// ellipsis at the name's end, not at its start ("Lift Your Skinny…", not
/// "…Lift Your Skinny" in Arabic).
TextDirection? flTextDirectionOf(String text) {
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_rtl.hasMatch(char)) return TextDirection.rtl;
    if (_letter.hasMatch(char)) return TextDirection.ltr;
  }
  return null;
}

/// The alignment that keeps [text], written in its own direction
/// ([flTextDirectionOf]), on the [ambient] start side: a Latin title on two
/// lines in an Arabic screen lines up on the right, with the rows around it.
TextAlign flTextAlignOf(String text, TextDirection ambient) {
  final own = flTextDirectionOf(text);
  return own == null || own == ambient ? TextAlign.start : TextAlign.end;
}
