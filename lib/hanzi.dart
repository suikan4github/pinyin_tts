import 'package:pinyin_tts/types.dart';

/// Basic Hanzi class to represent Chinese characters with their properties.
class Hanzi {
  /// Frequency of the character in a corpus.
  ///
  /// 1 is the most frequent character.
  final int frequency;

  /// Simplified form of the character.
  final String simplified;

  /// Traditional form of the character.
  final String traditional;

  /// Pinyin representation with tone.
  final String pinyinWithTone;

  /// Pinyin representation without tone.
  final String pinyinWithoutTone;

  /// Tone of the character (1-5). The 5 represents the neutral tone.
  final int tone;

  /// Onset of the character's pronunciation.
  final String onset;

  /// Rime of the character's pronunciation.
  final String rime;

  /// Constructor for Hanzi class
  Hanzi({
    required this.frequency,
    required this.simplified,
    required this.traditional,
    required this.pinyinWithTone,
    required this.pinyinWithoutTone,
    required this.tone,
    required this.onset,
    required this.rime,
  });

  /// Factory constructor to create a Hanzi object from a TSV row.
  ///
  /// # Description:
  /// The row should contain at least 4 elements.
  ///
  /// The [tsvRow] parameter is expected to be a string sprit by tabs.
  /// It must contains the following fields in order:
  /// - Frequency (int)
  /// - Simplified character (String)
  /// - Traditional character (String)
  /// - Pinyin with tone (String)
  ///
  /// The fields after the first four are ignored.
  ///
  /// ## Throws:
  /// Throws an [ArgumentError] if the row length is less than 4.
  /// Throws a [FormatException] if the frequency cannot be parsed as integers.
  /// Throws a [RangeError] if the frequency is negative.
  ///
  /// ## Example usage:
  /// The following code creates a Hanzi object from a TSV row string:
  /// ```Dart
  /// final hanzi = Hanzi.fromTsvRow('1\t你\t你\tnǐ');
  /// ```
  factory Hanzi.fromTsvRow(String tsvRow) {
    final List<String> row = tsvRow.split('\t');

    if (row.length < 4) {
      throw ArgumentError('Invalid TSV row length: ${row.length}');
    }
    // Parse the row and create a Hanzi object
    var parsedFrequency = int.parse(row[0]);
    if (parsedFrequency < 0) {
      throw RangeError(
        'Frequency must be non-negative, but got $parsedFrequency',
      );
    }

    final String generatedPinyinWithoutTone = _stripTone(row[3]);

    final int parsedTone = _parseTone(row[3]);

    final String extractedOnset = _extractOnset(row[3]);

    final String extractedRime = _extractRime(
      generatedPinyinWithoutTone,
      extractedOnset,
    );

    return Hanzi(
      frequency: parsedFrequency,
      simplified: row[1],
      traditional: row[2],
      pinyinWithTone: row[3],
      pinyinWithoutTone: generatedPinyinWithoutTone,
      tone: parsedTone,
      onset: extractedOnset,
      rime: extractedRime,
    );
  }

  /// Converts the Hanzi object to a TSV row.
  ///
  /// This is just for debugging purposes.
  @override
  String toString() {
    return '$frequency\t$simplified\t$traditional\t$pinyinWithTone\t$pinyinWithoutTone\t$tone\t$onset\t$rime';
  }
}

/// Strip the tone symbols from the pinyin string.
///
/// The characters with tone symbols will be replaced
/// with their base form.
String _stripTone(String pinyin) {
  return pinyin
      .replaceAll(RegExp(r'[āáǎà]'), 'a')
      .replaceAll(RegExp(r'[īíǐì]'), 'i')
      .replaceAll(RegExp(r'[ūúǔù]'), 'u')
      .replaceAll(RegExp(r'[ēéěè]'), 'e')
      .replaceAll(RegExp(r'[ōóǒò]'), 'o')
      .replaceAll(RegExp(r'[ǖǘǚǜ]'), 'ü');
}

/// parse the tone number from the pinyin string.
///
/// The number 1 to 4 represents the tones,
/// and 5 represents the neutral tone.
int _parseTone(String pinyin) {
  return switch (true) {
    true when pinyin.contains(RegExp(r'[āīūēōǖ]')) => 1,
    true when pinyin.contains(RegExp(r'[áíúéóǘ]')) => 2,
    true when pinyin.contains(RegExp(r'[ǎǐǔěǒǚ]')) => 3,
    true when pinyin.contains(RegExp(r'[àìùèòǜ]')) => 4,
    _ => 5,
  };
}

/// Extracts the onset from the pinyin string.
///
/// Try to search for the onset which matches
/// the beginning of the pinyin string.
/// The onset string is given from the HanziOnset.values.name().
///
/// If no match is found, it defaults to ''.
String _extractOnset(String pinyin) {
  for (var onset in HanziOnset.values) {
    if (pinyin.startsWith(onset.name)) {
      return onset.name;
    }
  }
  return '';
}

/// Extract the rime from the pinyin string.
///
/// Remove the given onset from the pinyin string.
/// If the onset is not found or empty,
///
String _extractRime(String pinyin, String onset) {
  if (onset.isEmpty) {
    return pinyin;
  }
  // Remove the onset from the pinyin string
  return pinyin.replaceFirst(onset, '');
}
