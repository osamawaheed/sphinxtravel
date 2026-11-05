import 'package:flutter/services.dart';

import './az_case.dart';

/// Upper-cases ONLY the first character of a field when it is a lowercase
/// letter in a script that has letter casing (Latin, Cyrillic, ...).
///
/// Scripts without casing (Arabic, Georgian Mkhedruli, digits, symbols) are
/// never modified because `toUpperCase()` returns them unchanged.
///
/// Text is returned untouched in every other case, so Backspace, cursor
/// movement, selection, copy/paste and IME composition stay native.
class FirstLetterCapitalizeFormatter extends TextInputFormatter {
  const FirstLetterCapitalizeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Find the first non-whitespace character.
    int index = 0;
    while (index < text.length && text[index].trim().isEmpty) {
      index++;
    }
    if (index >= text.length) return newValue;

    final first = String.fromCharCode(text.substring(index).runes.first);
    final upper = AzCase.upper(first);
    if (upper == first || upper.length != first.length) return newValue;

    // Same length replacement: selection and composing range stay valid.
    final formatted = text.replaceRange(index, index + first.length, upper);
    return newValue.copyWith(text: formatted);
  }
}
